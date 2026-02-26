// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Subscription tiers matching VISION_2026.md pricing.
enum SubscriptionTier {
  free,
  pro,
  team,
  business;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.pro:
        return 'Pro';
      case SubscriptionTier.team:
        return 'Team';
      case SubscriptionTier.business:
        return 'Business';
    }
  }

  String get price {
    switch (this) {
      case SubscriptionTier.free:
        return '\$0';
      case SubscriptionTier.pro:
        return '\$14.99/mo';
      case SubscriptionTier.team:
        return '\$19.99/user/mo';
      case SubscriptionTier.business:
        return '\$39.99/user/mo';
    }
  }
}

/// Free tier limits.
class FreeTierLimits {
  static const int meetingsPerWeek = 3;
  static const int insightsPerMeeting = 1;
  static const int historyDays = 7;
  static const bool canExport = false;
  static const bool canAskAura = false;
  static const bool canWeeklyDigest = false;
}

/// Result of a purchase attempt.
enum PurchaseResult {
  /// Purchase completed successfully.
  success,

  /// User cancelled the purchase dialog.
  cancelled,

  /// An error occurred during purchase.
  error,
}

/// Subscription state.
class SubscriptionState {
  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.isActive = false,
    this.expirationDate,
    this.meetingsThisWeek = 0,
    this.managementUrl,
  });

  final SubscriptionTier tier;
  final bool isActive;
  final DateTime? expirationDate;
  final int meetingsThisWeek;
  final String? managementUrl;

  bool get isPro => tier != SubscriptionTier.free && isActive;

  bool get canStartMeeting =>
      isPro || meetingsThisWeek < FreeTierLimits.meetingsPerWeek;

  int get meetingsRemaining =>
      isPro ? -1 : FreeTierLimits.meetingsPerWeek - meetingsThisWeek;

  bool get canExport => isPro;
  bool get canAskAura => isPro;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    bool? isActive,
    DateTime? expirationDate,
    int? meetingsThisWeek,
    String? managementUrl,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      expirationDate: expirationDate ?? this.expirationDate,
      meetingsThisWeek: meetingsThisWeek ?? this.meetingsThisWeek,
      managementUrl: managementUrl ?? this.managementUrl,
    );
  }
}

/// RevenueCat subscription service.
///
/// Handles all interaction with RevenueCat SDK:
/// - Initialize SDK with API keys
/// - Check/refresh entitlements
/// - Purchase packages
/// - Restore purchases
/// - Track free-tier usage
class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  // RevenueCat SDK API keys — injected via --dart-define at build time.
  // In CI: --dart-define=REVENUECAT_IOS_KEY=${{ secrets.REVENUECAT_IOS_KEY }}
  // Locally: app runs in free mode if keys are empty.
  static const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );

  // RevenueCat entitlement ID (configured in dashboard)
  static const _proEntitlement = 'pro';

  // Product identifiers (configured in App Store Connect + Google Play Console)
  static const proMonthlyId = 'aura_pro_monthly';
  static const proYearlyId = 'aura_pro_yearly';

  // Local storage keys for free-tier tracking
  static const _weekStartKey = 'meeting_week_start';
  static const _weekCountKey = 'meeting_week_count';

  /// Emails that automatically receive Pro access (Apple App Review, QA, etc.).
  static const _overrideProEmails = {
    'review@aurameet.live',
  };

  bool _initialized = false;
  bool _configured = false;
  SubscriptionState _state = const SubscriptionState();
  final _stateController = StreamController<SubscriptionState>.broadcast();

  /// Stream of subscription state changes.
  Stream<SubscriptionState> get stateStream => _stateController.stream;

  /// Current subscription state.
  SubscriptionState get state => _state;

  /// Initialize RevenueCat SDK.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;

      if (apiKey.isEmpty) {
        debugPrint('⚠️ RevenueCat key not set — running in free mode');
        _updateState(_state.copyWith(tier: SubscriptionTier.free));
        await _loadWeeklyUsage();
        _initialized = true;
        _configured = false;
        return;
      }

      debugPrint('🔑 RevenueCat configuring with key: ${apiKey.substring(0, 8)}...');
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = null,
      );

      // SDK is configured — mark it immediately so getOfferings works
      _configured = true;
      _initialized = true;

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);

      // Load initial state (non-fatal if these fail)
      try {
        await refreshEntitlements();
      } catch (e) {
        debugPrint('⚠️ Initial entitlement check failed (non-fatal): $e');
      }
      await _loadWeeklyUsage();

      debugPrint('✅ RevenueCat initialized — configured=$_configured, tier=${_state.tier}, isPro=${_state.isPro}');
    } catch (e) {
      debugPrint('⚠️ RevenueCat init failed: $e');
      _initialized = true;
      _configured = false;
      // App works in free mode if RevenueCat fails
      _updateState(_state.copyWith(tier: SubscriptionTier.free, isActive: false));
    }
  }

  /// Grant Pro access for override accounts (Apple Review, QA).
  ///
  /// Call after authentication with the user's email.
  /// Returns `true` if the email matched an override account.
  bool grantProOverride(String? email) {
    if (email == null) return false;
    if (_overrideProEmails.contains(email.toLowerCase())) {
      debugPrint('🔓 Pro override granted for $email');
      _updateState(_state.copyWith(
        tier: SubscriptionTier.pro,
        isActive: true,
      ));
      return true;
    }
    return false;
  }

  /// Refresh entitlements from RevenueCat.
  Future<void> refreshEntitlements() async {
    if (!_configured) return;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _processCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('⚠️ Failed to refresh entitlements: $e');
    }
  }

  /// Get available packages for purchase.
  Future<List<Package>> getOfferings() async {
    if (!_configured) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('⚠️ Failed to get offerings: $e');
      return [];
    }
  }

  /// Purchase a package.
  ///
  /// Returns [PurchaseResult] to differentiate between success, cancellation,
  /// and actual errors. This prevents showing error messages when the user
  /// simply cancels the purchase dialog.
  Future<PurchaseResult> purchasePackage(Package package) async {
    if (!_configured) return PurchaseResult.error;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _processCustomerInfo(customerInfo);
      return _state.isPro ? PurchaseResult.success : PurchaseResult.error;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase cancelled by user');
        return PurchaseResult.cancelled;
      }
      debugPrint('❌ Purchase error: $errorCode — ${e.message}');
      return PurchaseResult.error;
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      return PurchaseResult.error;
    }
  }

  /// Restore previous purchases.
  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      _processCustomerInfo(customerInfo);
      return _state.isPro;
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      return false;
    }
  }

  /// Record a meeting for free-tier tracking.
  Future<void> recordMeetingUsage() async {
    if (_state.isPro) return; // Pro users have no limit

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final storedWeekStart = prefs.getString(_weekStartKey);

    if (storedWeekStart != weekStart.toIso8601String()) {
      // New week — reset counter
      await prefs.setString(_weekStartKey, weekStart.toIso8601String());
      await prefs.setInt(_weekCountKey, 1);
      _updateState(_state.copyWith(meetingsThisWeek: 1));
    } else {
      final count = (prefs.getInt(_weekCountKey) ?? 0) + 1;
      await prefs.setInt(_weekCountKey, count);
      _updateState(_state.copyWith(meetingsThisWeek: count));
    }
  }

  /// Identify user (call after authentication).
  Future<void> logIn(String userId) async {
    if (!_configured) return;
    try {
      final customerInfo = await Purchases.logIn(userId);
      _processCustomerInfo(customerInfo.customerInfo);
    } catch (e) {
      debugPrint('⚠️ Failed to identify user: $e');
    }
  }

  /// Reset user identity (call on logout).
  ///
  /// Always resets local state to free tier, then additionally
  /// resets RevenueCat identity if configured.
  Future<void> logOut() async {
    // ALWAYS reset local state to free tier — critical to avoid
    // Pro override persisting across different user logins.
    _updateState(const SubscriptionState());
    debugPrint('🔒 Subscription reset to free on logout');

    // Clear persisted meeting usage so next user starts fresh
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_weekStartKey);
    await prefs.remove(_weekCountKey);

    if (!_configured) return;
    try {
      final customerInfo = await Purchases.logOut();
      _processCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('⚠️ Failed to logout RevenueCat user: $e');
    }
  }

  // ─── Private ─────────────────────────────────────────────────

  void _onCustomerInfoUpdate(CustomerInfo info) {
    _processCustomerInfo(info);
  }

  void _processCustomerInfo(CustomerInfo info) {
    final proEntitlement = info.entitlements.all[_proEntitlement];
    final isActive = proEntitlement?.isActive ?? false;

    SubscriptionTier tier = SubscriptionTier.free;
    if (isActive) {
      // Determine tier from product identifier
      final productId = proEntitlement?.productIdentifier ?? '';
      if (productId.contains('business')) {
        tier = SubscriptionTier.business;
      } else if (productId.contains('team')) {
        tier = SubscriptionTier.team;
      } else {
        tier = SubscriptionTier.pro;
      }
    }

    _updateState(
      _state.copyWith(
        tier: tier,
        isActive: isActive,
        expirationDate: proEntitlement?.expirationDate != null
            ? DateTime.tryParse(proEntitlement!.expirationDate!)
            : null,
        managementUrl: info.managementURL,
      ),
    );
  }

  Future<void> _loadWeeklyUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final storedWeekStart = prefs.getString(_weekStartKey);

    if (storedWeekStart == weekStart.toIso8601String()) {
      final count = prefs.getInt(_weekCountKey) ?? 0;
      _updateState(_state.copyWith(meetingsThisWeek: count));
    } else {
      // New week — reset
      await prefs.setString(_weekStartKey, weekStart.toIso8601String());
      await prefs.setInt(_weekCountKey, 0);
      _updateState(_state.copyWith(meetingsThisWeek: 0));
    }
  }

  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  void _updateState(SubscriptionState newState) {
    _state = newState;
    _stateController.add(newState);
    debugPrint('📊 Subscription state: tier=${newState.tier}, '
        'isActive=${newState.isActive}, isPro=${newState.isPro}, '
        'meetings=${newState.meetingsThisWeek}');
  }

  /// Dispose resources.
  void dispose() {
    _stateController.close();
  }
}
