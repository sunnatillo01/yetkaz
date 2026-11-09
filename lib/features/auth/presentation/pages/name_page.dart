import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/utils/validators.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/auth/presentation/bloc/name_cubit.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';
import 'package:material_ui/material_ui.dart';

class NamePage extends StatelessWidget {
  const NamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => getIt<NameCubit>(), child: const NameView());
  }
}

class NameView extends StatefulWidget {
  const NameView({super.key});

  @override
  State<NameView> createState() => _NameViewState();
}

class _NameViewState extends State<NameView> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<NameCubit>().submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: BlocConsumer<NameCubit, NameState>(
        listener: (context, state) {
          switch (state) {
            case NameSuccess():
              context.read<SessionCubit>().refresh();
            case NameFailure(:final failure):
              context.showSnack(failure.message(l10n));
            default:
          }
        },
        builder: (context, state) => SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text(l10n.nameTitle, style: context.text.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.nameSubtitle, style: context.text.bodyMedium),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  key: const Key('name_field'),
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: InputDecoration(labelText: l10n.nameLabel),
                  validator: (v) => Validators.isValidName(v ?? '') ? null : l10n.nameInvalid,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.xl),
                LoadingButton(
                  label: l10n.continueAction,
                  isLoading: state is NameLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
