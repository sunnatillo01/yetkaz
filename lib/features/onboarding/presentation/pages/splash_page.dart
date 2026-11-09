import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/features/onboarding/presentation/bloc/splash_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({this.from, super.key});

  /// Original deep link location to continue to.
  final String? from;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SplashCubit>()..start(),
      child: BlocListener<SplashCubit, SplashState>(
        listener: (context, state) {
          if (state is! SplashSuccess) return;
          context.go(switch (state.destination) {
            SplashDestination.onboarding => Routes.onboarding,
            SplashDestination.login => Routes.phone,
            SplashDestination.profile => Routes.name,
            SplashDestination.home => from ?? Routes.home,
          });
        },
        child: const SplashView(),
      ),
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: 96,
              height: 96,
              semanticsLabel: context.l10n.appName,
              colorFilter: ColorFilter.mode(context.colors.onPrimary, BlendMode.srcIn),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.appName,
              style: context.text.headlineMedium?.copyWith(
                color: context.colors.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
