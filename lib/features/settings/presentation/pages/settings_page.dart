import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/settings/domain/entities/app_settings.dart';
import 'package:food_delivery/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:food_delivery/features/settings/presentation/widgets/language_selector.dart';
import 'package:material_ui/material_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().loadInfo();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
      listener: (context, state) => context.showSnack(state.failure!.message(l10n)),
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        final info = state.info;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.settingsTitle)),
          body: ListView(
            children: [
              SectionTitle(l10n.language),
              const LanguageSelector(),
              SectionTitle(l10n.theme),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SegmentedButton<AppThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: AppThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(l10n.themeLight),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(l10n.themeDark),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.system,
                      icon: const Icon(Icons.settings_suggest_outlined),
                      label: Text(l10n.themeSystem),
                    ),
                  ],
                  selected: {state.settings.themeMode},
                  onSelectionChanged: (s) => cubit.setThemeMode(s.first),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(l10n.notifications),
                value: state.settings.notificationsEnabled,
                onChanged: state.isUpdatingPush ? null : (v) => cubit.setPushEnabled(enabled: v),
              ),
              const Divider(),
              if (info != null) ...[
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l10n.appVersion('${info.version}+${info.buildNumber}')),
                  subtitle: info.showFlavor ? Text(l10n.flavorLabel(info.flavor)) : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
