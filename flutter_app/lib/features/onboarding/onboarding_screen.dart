import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meetmind/config/theme.dart';
import 'package:meetmind/l10n/generated/app_localizations.dart';
import 'package:meetmind/services/permission_service.dart';
import 'package:meetmind/services/user_preferences.dart';

/// Onboarding flow — first-launch language + permissions setup.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  AppLocale _selectedLocale = AppLocale.en;

  @override
  void initState() {
    super.initState();
    _selectedLocale = UserPreferences.instance.locale;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await UserPreferences.instance.setOnboardingComplete(true);
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _requestMicPermission() async {
    await const PermissionService().requestMicPermission();
    _nextPage();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    l10n.onboardingSkip,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _WelcomePage(l10n: l10n),
                  _LanguagePage(
                    l10n: l10n,
                    selectedLocale: _selectedLocale,
                    onLocaleChanged: (locale) async {
                      setState(() => _selectedLocale = locale);
                      await UserPreferences.instance.setLocale(locale);
                    },
                  ),
                  _MicPermissionPage(
                    l10n: l10n,
                    onAllow: _requestMicPermission,
                  ),
                  _ReadyPage(l10n: l10n),
                ],
              ),
            ),

            // Page indicators + action button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Dots
                  Row(
                    children: List.generate(4, (index) {
                      return Container(
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? MeetMindTheme.primary
                              : MeetMindTheme.darkBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const Spacer(),

                  // Action button
                  ElevatedButton(
                    onPressed: _currentPage == 2
                        ? _requestMicPermission
                        : _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      _currentPage == 3
                          ? l10n.onboardingGetStarted
                          : l10n.onboardingNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 1: Welcome.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MeetMindTheme.primary.withValues(alpha: 0.3),
                  MeetMindTheme.accent.withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 80,
                height: 80,
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 40),
          Text(
            l10n.onboardingWelcome,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingWelcomeDesc,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

/// Page 2: Language selection.
class _LanguagePage extends StatelessWidget {
  const _LanguagePage({
    required this.l10n,
    required this.selectedLocale,
    required this.onLocaleChanged,
  });

  final AppLocalizations l10n;
  final AppLocale selectedLocale;
  final ValueChanged<AppLocale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.language,
            size: 56,
            color: MeetMindTheme.accent,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 32),
          Text(
            l10n.onboardingLanguage,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingLanguageDesc,
            style: const TextStyle(color: Colors.white54, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...AppLocale.values.map((locale) {
            final isSelected = locale == selectedLocale;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onLocaleChanged(locale),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MeetMindTheme.primary.withValues(alpha: 0.15)
                        : MeetMindTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? MeetMindTheme.primary
                          : MeetMindTheme.darkBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(locale.flag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 16),
                      Text(
                        locale.displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: MeetMindTheme.primary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Page 3: Microphone permission.
class _MicPermissionPage extends StatelessWidget {
  const _MicPermissionPage({required this.l10n, required this.onAllow});

  final AppLocalizations l10n;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MeetMindTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              size: 56,
              color: MeetMindTheme.success,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 32),
          Text(
            l10n.onboardingMic,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingMicDesc,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAllow,
            icon: const Icon(Icons.mic),
            label: Text(l10n.onboardingMicAllow),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              backgroundColor: MeetMindTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 4: All set.
class _ReadyPage extends StatelessWidget {
  const _ReadyPage({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: MeetMindTheme.success,
              )
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 1000.ms, color: MeetMindTheme.primary),
          const SizedBox(height: 32),
          Text(
            l10n.onboardingReady,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingReadyDesc,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}
