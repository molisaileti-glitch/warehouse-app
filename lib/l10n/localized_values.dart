import 'package:warehouse_app/l10n/app_localizations.dart';

String localizedReferenceValue(AppLocalizations l10n, String value) {
  return switch (value.trim().toUpperCase()) {
    'ACTIVE' => l10n.active,
    'INACTIVE' => l10n.inactive,
    'MALE' => l10n.male,
    'FEMALE' => l10n.female,
    'FATHER' => l10n.father,
    'MOTHER' => l10n.mother,
    'SPOUSE' => l10n.spouse,
    'CHILD' => l10n.child,
    'BROTHER' => l10n.brother,
    'SISTER' => l10n.sister,
    'OTHER' => l10n.other,
    'MEMBER' => l10n.member,
    'NON_MEMBER' => l10n.nonMember,
    'SINGLE' => l10n.single,
    'MARRIED' => l10n.married,
    'PRIMARY' => l10n.primaryEducation,
    'OWNER' || 'MCU_ADMIN' || 'SUPER_ADMIN' => l10n.owner,
    'WORKER' || 'AMCOS_USER' => l10n.worker,
    _ => value,
  };
}
