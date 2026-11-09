import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/gen/app_localizations.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a localized, themed MaterialApp (Uzbek).
  Future<void> pumpApp(Widget widget, {Locale locale = const Locale('uz')}) {
    return pumpWidget(
      MaterialApp(
        locale: locale,
        theme: AppTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: widget,
      ),
    );
  }
}

/// Uzbek strings for assertions.
AppLocalizations get uzL10n => lookupAppLocalizations(const Locale('uz'));
