import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/utils/phone_formatter.dart';
import 'package:food_delivery/core/utils/validators.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/auth/presentation/bloc/phone_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class PhonePage extends StatelessWidget {
  const PhonePage({this.from, super.key});

  /// Location to return to after a successful login.
  final String? from;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PhoneCubit>(),
      child: PhoneView(from: from),
    );
  }
}

class PhoneView extends StatefulWidget {
  const PhoneView({this.from, super.key});

  final String? from;

  @override
  State<PhoneView> createState() => _PhoneViewState();
}

class _PhoneViewState extends State<PhoneView> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<PhoneCubit>().submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: BlocConsumer<PhoneCubit, PhoneState>(
        listener: (context, state) {
          switch (state) {
            case PhoneSuccess(:final args):
              context.read<PhoneCubit>().reset();
              context.push(
                Uri(path: Routes.otp, queryParameters: {'from': ?widget.from}).toString(),
                extra: args,
              );
            case PhoneFailure(:final failure):
              context.showSnack(failure.message(l10n));
            default:
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(l10n.phoneTitle, style: context.text.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.phoneSubtitle, style: context.text.bodyMedium),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    key: const Key('phone_field'),
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      const UzPhoneInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.phoneLabel,
                      prefixText: '${PhoneUtils.countryCode} ',
                      hintText: '90 123 45 67',
                    ),
                    validator: (value) =>
                        Validators.isValidPhone(value ?? '') ? null : l10n.phoneInvalid,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LoadingButton(
                    key: const Key('phone_submit'),
                    label: l10n.sendCode,
                    isLoading: state is PhoneLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
