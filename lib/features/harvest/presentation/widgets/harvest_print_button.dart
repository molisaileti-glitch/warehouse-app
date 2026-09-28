import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/services/receipt_printer_service.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class HarvestPrintButton extends ConsumerStatefulWidget {
  final FarmerHarvest harvest;
  final String? label;
  final bool filled;
  final bool compact;

  const HarvestPrintButton({
    super.key,
    required this.harvest,
    this.label,
    this.filled = false,
    this.compact = false,
  });

  @override
  ConsumerState<HarvestPrintButton> createState() => _HarvestPrintButtonState();
}

class _HarvestPrintButtonState extends ConsumerState<HarvestPrintButton> {
  final _printerService = ReceiptPrinterService();
  Locale _receiptLocale = const Locale('en');
  bool _includeBagDetails = false;
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = widget.label ?? l10n.printReceipt;
    final icon = _printing
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.print_outlined);

    if (widget.filled) {
      return ElevatedButton.icon(
        onPressed: _printing ? null : _printReceipt,
        icon: icon,
        label: Text(label),
      );
    }

    if (widget.compact) {
      return IconButton.filledTonal(
        tooltip: label,
        onPressed: _printing ? null : _printReceipt,
        icon: icon,
      );
    }

    return OutlinedButton.icon(
      onPressed: _printing ? null : _printReceipt,
      icon: icon,
      label: Text(label),
    );
  }

  Future<void> _printReceipt() async {
    if (_printing) return;
    final appL10n = AppLocalizations.of(context)!;
    final options = await _showPrintOptionsSheet(appL10n);
    if (options == null || !mounted) return;

    setState(() {
      _printing = true;
      _receiptLocale = options.locale;
      _includeBagDetails = options.includeBagDetails;
    });
    var loadingShown = false;

    try {
      await _printerService.ensureBluetoothPermission(
        appL10n.bluetoothPermissionRequired,
      );
      if (!mounted) return;

      final printer = await _printerService.pickPrinter();
      if (!mounted) return;

      showCenteredLoadingDialog(
        context,
        title: appL10n.printingReceipt,
        description: appL10n.printingReceiptDescription,
      );
      loadingShown = true;

      final bags = await ref.read(harvestDaoProvider).getBagsForHarvest(
            widget.harvest.uuid,
          );
      final receiptL10n = lookupAppLocalizations(options.locale);
      await _printerService.printHarvestReceipt(
        printer: printer,
        harvest: widget.harvest,
        bags: bags,
        l10n: receiptL10n,
        includeBagDetails: options.includeBagDetails,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loadingShown = false;
      await showCreationSuccessDialog(
        context,
        title: appL10n.receiptPrinted,
        description: appL10n.receiptPrintedDescription,
      );
    } catch (error) {
      if (!mounted) return;
      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (error is ReceiptPrinterException &&
          error.message == 'No printer was selected.') {
        return;
      }
      await showAppFeedbackDialog<void>(
        context,
        title: appL10n.printerError,
        description: error is ReceiptPrinterException
            ? error.message
            : appL10n.printerLoadError,
        type: AppFeedbackType.error,
        actions: [
          AppFeedbackAction<void>(label: appL10n.ok, isPrimary: true),
        ],
        barrierDismissible: false,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<_PrintOptions?> _showPrintOptionsSheet(AppLocalizations l10n) {
    var selectedLocale = _receiptLocale;
    var includeBagDetails = _includeBagDetails;

    return showModalBottomSheet<_PrintOptions>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.printOptions,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RadioGroup<Locale>(
                        groupValue: selectedLocale,
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => selectedLocale = value);
                        },
                        child: Column(
                          children: [
                            RadioListTile<Locale>(
                              value: const Locale('en'),
                              title: Text(l10n.receiptEnglish),
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.ownerColor,
                              dense: true,
                            ),
                            RadioListTile<Locale>(
                              value: const Locale('sw'),
                              title: Text(l10n.receiptSwahili),
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.ownerColor,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 14),
                      RadioGroup<bool>(
                        groupValue: includeBagDetails,
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => includeBagDetails = value);
                        },
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              value: false,
                              title: Text(l10n.printWithoutBagDetails),
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.ownerColor,
                              dense: true,
                            ),
                            RadioListTile<bool>(
                              value: true,
                              title: Text(l10n.printWithBagDetails),
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.ownerColor,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(
                          _PrintOptions(
                            locale: selectedLocale,
                            includeBagDetails: includeBagDetails,
                          ),
                        ),
                        icon: const Icon(Icons.print_outlined),
                        label: Text(l10n.printReceipt),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PrintOptions {
  final Locale locale;
  final bool includeBagDetails;

  const _PrintOptions({
    required this.locale,
    required this.includeBagDetails,
  });
}
