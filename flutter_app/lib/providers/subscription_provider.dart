import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:meetmind/services/subscription_service.dart';

/// Notifier that bridges SubscriptionService stream → Riverpod state.
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState()) {
    _subscription = SubscriptionService.instance.stateStream.listen((newState) {
      state = newState;
    });
    // Sync with current service state
    state = SubscriptionService.instance.state;
  }

  late final StreamSubscription<SubscriptionState> _subscription;

  /// Refresh entitlements from RevenueCat.
  Future<void> refresh() async {
    await SubscriptionService.instance.refreshEntitlements();
  }

  /// Purchase a package.
  Future<bool> purchase(Package package) async {
    return SubscriptionService.instance.purchasePackage(package);
  }

  /// Restore purchases.
  Future<bool> restore() async {
    return SubscriptionService.instance.restorePurchases();
  }

  /// Record a meeting for free-tier tracking.
  Future<void> recordMeeting() async {
    await SubscriptionService.instance.recordMeetingUsage();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Main subscription state provider.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);

/// Whether the user has an active Pro (or higher) subscription.
final isProProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).isPro,
);

/// Whether the user can start a new meeting (Pro or under free limit).
final canStartMeetingProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).canStartMeeting,
);

/// Number of meetings remaining this week (free tier). -1 = unlimited (Pro).
final meetingsRemainingProvider = Provider<int>(
  (ref) => ref.watch(subscriptionProvider).meetingsRemaining,
);

/// Current subscription tier.
final subscriptionTierProvider = Provider<SubscriptionTier>(
  (ref) => ref.watch(subscriptionProvider).tier,
);
