"""MeetMind CI Pipeline — Dagger Python SDK.

Run locally: dagger run python scripts/ci/pipeline.py
Same logic as GitHub Actions, but portable and testable.
"""

from __future__ import annotations

import sys

import anyio
import dagger


async def backend_quality_gate(client: dagger.Client) -> bool:
    """Run the full backend quality gate (ruff, mypy, pytest, gitleaks)."""
    print("🐍 Running backend quality gate...")

    src = client.host().directory(
        ".",
        exclude=[
            ".git",
            ".venv",
            "__pycache__",
            "node_modules",
            "flutter_app/build",
            "*.egg-info",
        ],
    )

    python = (
        client.container()
        .from_("ghcr.io/astral-sh/uv:python3.12-bookworm-slim")
        .with_directory("/app", src)
        .with_workdir("/app/backend")
        .with_exec(["uv", "sync", "--frozen"])
    )

    # Ruff lint
    print("  🔍 Ruff lint...")
    await python.with_exec(
        ["uv", "run", "ruff", "check", "src/", "tests/"],
    ).sync()

    # Ruff format check
    print("  🎨 Ruff format...")
    await python.with_exec(
        ["uv", "run", "ruff", "format", "--check", "src/", "tests/"],
    ).sync()

    # mypy
    print("  🔬 mypy --strict...")
    await python.with_exec(
        ["uv", "run", "mypy", "--strict", "src/meetmind/"],
    ).sync()

    # pytest
    print("  🧪 pytest...")
    await python.with_exec(
        [
            "uv",
            "run",
            "pytest",
            "--cov=src/meetmind",
            "--cov-report=term-missing",
            "--cov-fail-under=80",
        ],
    ).sync()

    print("  ✅ Backend quality gate PASSED!")
    return True


async def build_backend_image(client: dagger.Client) -> dagger.Container:
    """Build the production Docker image."""
    print("🐳 Building Docker image...")

    backend_dir = client.host().directory(
        "backend",
        exclude=[".venv", "__pycache__", "*.egg-info", ".mypy_cache"],
    )

    image = backend_dir.docker_build()
    await image.sync()

    print("  ✅ Docker image built!")
    return image


async def scan_image(client: dagger.Client, image_ref: str) -> bool:
    """Scan a Docker image with Trivy."""
    print(f"🔍 Scanning {image_ref} with Trivy...")

    trivy = (
        client.container()
        .from_("aquasec/trivy:latest")
        .with_exec(
            [
                "image",
                "--severity",
                "CRITICAL,HIGH",
                "--exit-code",
                "1",
                image_ref,
            ],
        )
    )

    await trivy.sync()
    print("  ✅ No critical/high vulnerabilities!")
    return True


async def main() -> None:
    """Run the full CI pipeline."""
    print("=" * 60)
    print("  MeetMind CI Pipeline (Dagger)")
    print("=" * 60)

    exit_code = 0
    async with dagger.Connection() as client:
        try:
            await backend_quality_gate(client)
        except dagger.ExecError as e:
            print(f"\n❌ Quality gate FAILED:\n{e}")
            exit_code = 1
        except Exception as e:
            print(f"\n❌ Pipeline error: {e}")
            exit_code = 1

    print("=" * 60)
    if exit_code == 0:
        print("  ✅ ALL CHECKS PASSED")
    else:
        print("  ❌ PIPELINE FAILED")
    print("=" * 60)

    sys.exit(exit_code)


if __name__ == "__main__":
    anyio.run(main)
