import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:material_ui/material_ui.dart';

extension AddressLabelUi on AddressLabel {
  String title(BuildContext context) => switch (this) {
    AddressLabel.home => context.l10n.addressHome,
    AddressLabel.work => context.l10n.addressWork,
    AddressLabel.other => context.l10n.addressOther,
  };

  IconData get icon => switch (this) {
    AddressLabel.home => Icons.home_rounded,
    AddressLabel.work => Icons.work_rounded,
    AddressLabel.other => Icons.place_rounded,
  };
}
