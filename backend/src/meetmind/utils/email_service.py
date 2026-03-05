"""Amazon SES email service for Aura Meet.

Sends transactional emails (meeting summary, password reset, etc.)
using boto3. Credentials are resolved automatically:
  - locally: via aws_profile in settings / env
  - production: via App Runner instance IAM role (no access keys needed)
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path
from typing import Any

import boto3
import structlog
from botocore.exceptions import BotoCoreError, ClientError

from meetmind.config.settings import settings

logger = structlog.get_logger(__name__)

# Load HTML template once at module level
_TEMPLATE_PATH = Path(__file__).parent.parent / "templates" / "meeting_summary.html"
_TEMPLATE: str | None = None


def _get_template() -> str:
    global _TEMPLATE
    if _TEMPLATE is None:
        _TEMPLATE = _TEMPLATE_PATH.read_text(encoding="utf-8")
    return _TEMPLATE


def _format_duration(seconds: int | None) -> str:
    """Convert seconds to human-readable duration."""
    if not seconds:
        return "—"
    minutes = seconds // 60
    if minutes < 60:
        return f"{minutes} min"
    hours = minutes // 60
    remaining = minutes % 60
    return f"{hours}h {remaining}min" if remaining else f"{hours}h"


def _format_date(dt: datetime | str | None) -> str:
    """Format datetime for email display."""
    if not dt:
        return ""
    if isinstance(dt, str):
        try:
            dt = datetime.fromisoformat(dt.replace("Z", "+00:00"))
        except ValueError:
            return str(dt)
    return dt.strftime("%A, %d %b %Y · %H:%M")


def _render_action_items_html(items: list[Any]) -> str:
    """Render action items as styled HTML rows."""
    if not items:
        return '<p style="color:#9ca3af;font-style:italic;">No action items detected.</p>'
    rows = []
    for item in items:
        if isinstance(item, dict):
            task = item.get("task", str(item))
            assignee = item.get("assignee", "")
            deadline = item.get("deadline", "")
            priority = item.get("priority", "medium")
            priority_color = {"high": "#ef4444", "medium": "#f59e0b", "low": "#22c55e"}.get(
                priority, "#f59e0b"
            )
            assignee_tag = (
                f'<span style="color:#a78bfa;font-size:12px;margin-left:8px;">→ {assignee}</span>'
                if assignee
                else ""
            )
            deadline_tag = (
                f'<span style="color:#6b7280;font-size:11px;margin-left:8px;">📅 {deadline}</span>'
                if deadline
                else ""
            )
            rows.append(
                f"""
                <tr>
                  <td style="padding:10px 0;border-bottom:1px solid #1f2937;">
                    <span style="color:{priority_color};margin-right:8px;">●</span>
                    <span style="color:#e5e7eb;">{task}</span>
                    {assignee_tag}{deadline_tag}
                  </td>
                </tr>"""
            )
        else:
            rows.append(
                f"""
                <tr>
                  <td style="padding:10px 0;border-bottom:1px solid #1f2937;">
                    <span style="color:#f59e0b;margin-right:8px;">●</span>
                    <span style="color:#e5e7eb;">{item}</span>
                  </td>
                </tr>"""
            )
    return f'<table width="100%" cellpadding="0" cellspacing="0">{"".join(rows)}</table>'


def _render_list_html(items: list[Any], icon: str = "▸") -> str:
    """Render a simple list as HTML."""
    if not items:
        return '<p style="color:#9ca3af;font-style:italic;">None detected.</p>'
    rows = []
    for item in items:
        text = item.get("text", str(item)) if isinstance(item, dict) else str(item)
        rows.append(
            f'<p style="margin:6px 0;color:#d1d5db;">'
            f'<span style="color:#8b5cf6;margin-right:8px;">{icon}</span>{text}</p>'
        )
    return "".join(rows)


def _build_plain_text(
    meeting_title: str,
    meeting_date: str,
    duration: str,
    overview: str,
    action_items: list[Any],
    decisions: list[Any],
    key_points: list[Any],
) -> str:
    """Build plain-text fallback for email clients that don't render HTML."""
    lines = [
        f"AURA MEET — MEETING SUMMARY",
        f"{'=' * 40}",
        f"",
        f"📋 {meeting_title}",
        f"🗓  {meeting_date}  ·  ⏱ {duration}",
        f"",
        f"EXECUTIVE SUMMARY",
        f"-" * 20,
        overview or "No summary available.",
        f"",
    ]
    if action_items:
        lines += ["ACTION ITEMS", "-" * 20]
        for item in action_items:
            task = item.get("task", str(item)) if isinstance(item, dict) else str(item)
            assignee = item.get("assignee", "") if isinstance(item, dict) else ""
            suffix = f" (→ {assignee})" if assignee else ""
            lines.append(f"  ☐ {task}{suffix}")
        lines.append("")
    if decisions:
        lines += ["KEY DECISIONS", "-" * 20]
        for d in decisions:
            text = d.get("text", str(d)) if isinstance(d, dict) else str(d)
            lines.append(f"  • {text}")
        lines.append("")
    lines += [
        "─" * 40,
        "Powered by Aura Meet · aurameet.live",
        "To stop receiving meeting summaries, open Settings in the app.",
    ]
    return "\n".join(lines)


class SESEmailService:
    """Amazon SES email sender.

    Uses the instance IAM role in production (App Runner) —
    no access keys required.
    """

    def __init__(self) -> None:
        self._client = None

    def _get_client(self) -> Any:
        """Lazily initialize the SES client."""
        if self._client is None:
            kwargs: dict[str, Any] = {"region_name": settings.ses_region or "us-east-1"}
            # In dev, use a named profile if configured
            if settings.aws_profile:
                session = boto3.Session(profile_name=settings.aws_profile)
                self._client = session.client("ses", **kwargs)
            else:
                self._client = boto3.client("ses", **kwargs)
        return self._client

    async def send_meeting_summary(
        self,
        *,
        user_email: str,
        user_name: str,
        meeting_id: str,
        meeting_title: str,
        meeting_date: str | datetime | None,
        duration_secs: int | None,
        summary: dict[str, Any],
        language: str = "es",
    ) -> bool:
        """Send a meeting summary email via Amazon SES.

        Runs the blocking boto3 call in a thread pool to avoid blocking
        the async event loop.

        Returns:
            True if sent successfully, False on any error.
        """
        if not settings.ses_sender:
            logger.warning("ses_sender_not_configured", skip_email=True)
            return False

        try:
            html, plain = self._render_email(
                user_name=user_name,
                meeting_id=meeting_id,
                meeting_title=meeting_title,
                meeting_date=meeting_date,
                duration_secs=duration_secs,
                summary=summary,
            )

            subject = self._build_subject(meeting_title, language)

            # Run blocking boto3 in thread executor
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(
                None,
                lambda: self._send_raw_email(
                    to_email=user_email,
                    subject=subject,
                    html_body=html,
                    plain_body=plain,
                ),
            )

            logger.info(
                "meeting_summary_email_sent",
                meeting_id=meeting_id,
                email=user_email[:3] + "***",  # partial for privacy
            )
            return True

        except (BotoCoreError, ClientError) as e:
            logger.error("ses_send_failed", meeting_id=meeting_id, error=str(e))
            return False
        except Exception as e:
            logger.error("email_unexpected_error", meeting_id=meeting_id, error=str(e))
            return False

    def _build_subject(self, meeting_title: str, language: str) -> str:
        subjects = {
            "es": f"📋 Resumen de reunión: {meeting_title}",
            "pt": f"📋 Resumo da reunião: {meeting_title}",
            "en": f"📋 Meeting summary: {meeting_title}",
        }
        return subjects.get(language, subjects["en"])

    def _render_email(
        self,
        *,
        user_name: str,
        meeting_id: str,
        meeting_title: str,
        meeting_date: str | datetime | None,
        duration_secs: int | None,
        summary: dict[str, Any],
    ) -> tuple[str, str]:
        """Render HTML and plain-text email bodies."""
        overview = summary.get("overview", "")
        action_items = summary.get("action_items", [])
        decisions = summary.get("decisions", [])
        key_points = summary.get("key_points", [])
        sentiment = summary.get("sentiment", "")

        date_str = _format_date(meeting_date)
        duration_str = _format_duration(duration_secs)

        sentiment_emoji = {"positive": "😊", "negative": "😔", "neutral": "😐"}.get(
            sentiment or "", ""
        )

        # Build HTML from template
        html = (
            _get_template()
            .replace("{{MEETING_TITLE}}", meeting_title)
            .replace("{{MEETING_DATE}}", date_str)
            .replace("{{DURATION}}", duration_str)
            .replace("{{USER_NAME}}", user_name or "there")
            .replace("{{OVERVIEW}}", overview or "No summary available.")
            .replace("{{ACTION_ITEMS_HTML}}", _render_action_items_html(action_items))
            .replace("{{DECISIONS_HTML}}", _render_list_html(decisions, "🔑"))
            .replace("{{KEY_POINTS_HTML}}", _render_list_html(key_points, "💡"))
            .replace("{{SENTIMENT_EMOJI}}", sentiment_emoji)
            .replace("{{MEETING_ID}}", meeting_id)
            .replace("{{APP_STORE_URL}}", "https://apps.apple.com/us/app/aura-meet/id6759219835")
            .replace("{{SITE_URL}}", "https://aurameet.live")
        )

        plain = _build_plain_text(
            meeting_title=meeting_title,
            meeting_date=date_str,
            duration=duration_str,
            overview=overview,
            action_items=action_items,
            decisions=decisions,
            key_points=key_points,
        )

        return html, plain

    def _send_raw_email(
        self,
        *,
        to_email: str,
        subject: str,
        html_body: str,
        plain_body: str,
    ) -> None:
        """Blocking SES send — call via run_in_executor."""
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{settings.ses_sender_name} <{settings.ses_sender}>"
        msg["To"] = to_email

        msg.attach(MIMEText(plain_body, "plain", "utf-8"))
        msg.attach(MIMEText(html_body, "html", "utf-8"))

        self._get_client().send_raw_email(
            Source=f"{settings.ses_sender_name} <{settings.ses_sender}>",
            Destinations=[to_email],
            RawMessage={"Data": msg.as_string()},
        )


# Singleton instance
email_service = SESEmailService()
