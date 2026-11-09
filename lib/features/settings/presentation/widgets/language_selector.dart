import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';

extension AppLanguageUi on AppLanguage {
  String title(BuildContext context) => switch (this) {
    AppLanguage.uz => context.l10n.languageUz,
    AppLanguage.ru => context.l10n.languageRu,
    AppLanguage.en => context.l10n.languageEn,
  };
}

/// Radio list of the three supported languages.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final current =
        context.select<SettingsCubit, AppLanguage?>((c) => c.state.settings.language) ??
        AppLanguage.fromCode(Localizations.localeOf(context).languageCode);
    return RadioGroup<AppLanguage>(
      groupValue: current,
      onChanged: (l) => context.read<SettingsCubit>().setLanguage(l!),
      child: Column(
        children: [
          for (final l in AppLanguage.values)
            RadioListTile<AppLanguage>(value: l, title: Text(l.title(context))),
        ],
      ),
    );
  }
}
