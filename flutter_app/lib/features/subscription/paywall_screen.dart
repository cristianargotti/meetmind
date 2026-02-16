import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:meetmind/config/theme.dart';
import 'package:meetmind/providers/subscription_provider.dart';
import 'package:meetmind/services/subscription_service.dart';

/// Premium paywall — glassmorphism design with plan comparison.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isYearly = false;
  bool _isLoading = false;
  bool _isRestoring = false;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final packages = await SubscriptionService.instance.getOfferings();
    if (mounted) {
      setState(() => _packages = packages);
    }
  }

  Future<void> _purchase() async {
    if (_packages.isEmpty) return;

    setState(() => _isLoading = true);

    // Find the right package (monthly or yearly)
    final targetId = _isYearly
        ? SubscriptionService.proYearlyId
        : SubscriptionService.proMonthlyId;
    final package = _packages.firstWhere(
      (p) => p.storeProduct.identifier == targetId,
      orElse: () => _packages.first,
    );

    final success = await ref.read(subscriptionProvider.notifier).purchase(package);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Welcome to Aura Pro!')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    final success = await ref.read(subscriptionProvider.notifier).restore();
    if (mounted) {
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✅ Purchases restored!'
              : 'No previous purchases found'),
        ),
      );
      if (success) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeetMindTheme.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: MeetMindTheme.textSecondary),
                ),
              ),

              // Hero section
              _buildHero(),

              const SizedBox(height: 28),

              // Plan toggle
              _buildPlanToggle(),

              const SizedBox(height: 24),

              // Feature comparison
              _buildFeatureComparison(),

              const SizedBox(height: 28),

              // CTA button
              _buildCTA(),

              const SizedBox(height: 14),

              // Restore
              TextButton(
                onPressed: _isRestoring ? null : _restore,
                child: Text(
                  _isRestoring ? 'Restoring...' : 'Restore Purchases',
                  style: const TextStyle(
                    color: MeetMindTheme.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Legal
              const Text(
                'Cancel anytime. Recurring billing.',
                style: TextStyle(
                  color: MeetMindTheme.textTertiary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        // Gradient icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [MeetMindTheme.primary, MeetMindTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: MeetMindTheme.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
        ).animate().scale(
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: 20),
        const Text(
          'Unlock Aura Pro',
          style: TextStyle(
            color: MeetMindTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 8),
        const Text(
          'Your AI meeting copilot, unleashed',
          style: TextStyle(
            color: MeetMindTheme.textSecondary,
            fontSize: 15,
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildPlanToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MeetMindTheme.darkCard,
        borderRadius: BorderRadius.circular(MeetMindTheme.radiusSm),
        border: Border.all(color: MeetMindTheme.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleButton('Monthly', '\$9.99/mo', !_isYearly)),
          Expanded(child: _toggleButton('Yearly', '\$6.66/mo', _isYearly, badge: 'Save 33%')),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _toggleButton(String label, String price, bool selected, {String? badge}) {
    return GestureDetector(
      onTap: () => setState(() => _isYearly = label == 'Yearly'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? MeetMindTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: MeetMindTheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MeetMindTheme.accent,
                  borderRadius: BorderRadius.circular(MeetMindTheme.radiusPill),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: selected ? MeetMindTheme.textPrimary : MeetMindTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: TextStyle(
                color: selected ? MeetMindTheme.primary : MeetMindTheme.textTertiary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureComparison() {
    final features = [
      _FeatureRow('Meetings per week', '3', 'Unlimited', Icons.mic),
      _FeatureRow('Meeting history', '7 days', 'Forever', Icons.history),
      _FeatureRow('Insights per meeting', '1', 'All', Icons.lightbulb_outline),
      _FeatureRow('Ask Aura (AI chat)', '—', '✓', Icons.chat_bubble_outline),
      _FeatureRow('Weekly Digest', '—', '✓', Icons.summarize),
      _FeatureRow('Export & share', '—', '✓', Icons.share),
      _FeatureRow('Pre-Meeting Briefing', '—', '✓', Icons.event_note),
    ];

    return Column(
      children: features.asMap().entries.map((e) {
        return _buildFeatureRow(e.value, e.key);
      }).toList(),
    );
  }

  Widget _buildFeatureRow(_FeatureRow feature, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MeetMindTheme.darkCard,
        borderRadius: BorderRadius.circular(MeetMindTheme.radiusSm),
        border: Border.all(color: MeetMindTheme.darkBorder),
      ),
      child: Row(
        children: [
          Icon(feature.icon, color: MeetMindTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature.name,
              style: const TextStyle(
                color: MeetMindTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              feature.free,
              style: const TextStyle(
                color: MeetMindTheme.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              feature.pro,
              style: const TextStyle(
                color: MeetMindTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (200 + index * 60).ms, duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildCTA() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _purchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: MeetMindTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MeetMindTheme.radiusMd),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isYearly ? 'Start Pro — \$79.99/year' : 'Start Pro — \$9.99/month',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
        );
  }
}

class _FeatureRow {
  final String name;
  final String free;
  final String pro;
  final IconData icon;

  const _FeatureRow(this.name, this.free, this.pro, this.icon);
}
