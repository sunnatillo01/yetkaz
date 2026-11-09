import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/utils/phone_formatter.dart';
import 'package:food_delivery/core/utils/validators.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/auth/presentation/bloc/otp_cubit.dart';
import 'package:food_delivery/features/auth/presentation/bloc/phone_cubit.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';
import 'package:material_ui/material_ui.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({required this.args, super.key});

  final OtpArgs args;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<OtpCubit>()..init(args)),
        BlocProvider(create: (_) => getIt<ResendTimerCubit>()..start()),
      ],
      child: const OtpView(),
    );
  }
}

class OtpView extends StatefulWidget {
  const OtpView({super.key});

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    final code = _controller.text;
    if (Validators.isValidOtp(code)) context.read<OtpCubit>().verify(code);
  }

  void _resend() {
    context.read<OtpCubit>().resend();
    context.read<ResendTimerCubit>().start();
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phone = PhoneUtils.formatE164(context.read<OtpCubit>().args.phone);
    return Scaffold(
      appBar: AppBar(),
      body: BlocConsumer<OtpCubit, OtpState>(
        listener: (context, state) {
          switch (state) {
            case OtpSuccess():
              // Router redirects to home / name screen once session updates.
              context.read<SessionCubit>().refresh();
            case OtpFailure(:final failure):
              _controller.clear();
              context.showSnack(failure.message(l10n));
            default:
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(l10n.otpTitle, style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.otpSubtitle(phone), style: context.text.bodyMedium),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  key: const Key('otp_field'),
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  style: context.text.headlineMedium?.copyWith(letterSpacing: 12),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                  onChanged: (value) {
                    if (value.length == 6) _verify();
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                BlocBuilder<ResendTimerCubit, int>(
                  builder: (context, seconds) => Center(
                    child: seconds > 0
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(l10n.resendIn(seconds), style: context.text.bodyMedium),
                          )
                        : TextButton(onPressed: _resend, child: Text(l10n.resendCode)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LoadingButton(
                  label: l10n.verify,
                  isLoading: state is OtpLoading,
                  onPressed: _verify,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
