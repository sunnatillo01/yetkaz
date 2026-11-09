import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:food_delivery/features/settings/presentation/widgets/language_selector.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// First launch: language selection, then 3 slides. Shown only once
/// (`onboarding_seen` flag in Hive).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _illustrations = [
    'assets/images/onboarding_1.svg',
    'assets/images/onboarding_2.svg',
    'assets/images/onboarding_3.svg',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == 3;

  Future<void> _next() async {
    if (_page == 0) {
      // Persist the language shown on screen even if the user didn't tap.
      final cubit = context.read<SettingsCubit>();
      if (cubit.state.settings.language == null) {
        await cubit.setLanguage(
          AppLanguage.fromCode(Localizations.localeOf(context).languageCode) ?? AppLanguage.uz,
        );
      }
    }
    if (_isLast) return _finish();
    await _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    await context.read<SettingsCubit>().completeOnboarding();
    if (mounted) context.go(Routes.phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = [
      (l10n.onboardingTitle1, l10n.onboardingBody1),
      (l10n.onboardingTitle2, l10n.onboardingBody2),
      (l10n.onboardingTitle3, l10n.onboardingBody3),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _page > 0 && !_isLast
                  ? TextButton(onPressed: _finish, child: Text(l10n.skip))
                  : const SizedBox(height: AppSpacing.minTouch),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                // Language must be confirmed with the button.
                physics: _page == 0
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      SvgPicture.asset(
                        'assets/images/logo.svg',
                        height: 96,
                        colorFilter: ColorFilter.mode(context.colors.primary, BlendMode.srcIn),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l10n.chooseLanguage,
                        textAlign: TextAlign.center,
                        style: context.text.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const LanguageSelector(),
                    ],
                  ),
                  for (var i = 0; i < slides.length; i++)
                    _Slide(asset: _illustrations[i], title: slides[i].$1, body: slides[i].$2),
                ],
              ),
            ),
            if (_page > 0)
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        width: i == _page ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? context.colors.primary
                              : context.colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding_next'),
                  onPressed: _next,
                  child: Text(_isLast ? l10n.getStarted : l10n.next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.asset, required this.title, required this.body});

  final String asset;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          SvgPicture.asset(asset, height: 220, excludeFromSemantics: true),
          const SizedBox(height: AppSpacing.xxl),
          Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(body, textAlign: TextAlign.center, style: context.text.bodyLarge),
        ],
      ),
    );
  }
}
