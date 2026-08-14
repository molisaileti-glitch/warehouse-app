import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/harvest/presentation/providers/harvest_receiving_controller.dart';
import 'package:warehouse_app/features/harvest/services/receipt_printer_service.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class HarvestReceiptScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final bool ownerFlow;

  const HarvestReceiptScreen({
    super.key,
    required this.warehouseId,
    required this.ownerFlow,
  });

  @override
  ConsumerState<HarvestReceiptScreen> createState() =>
      _HarvestReceiptScreenState();
}

class _HarvestReceiptScreenState extends ConsumerState<HarvestReceiptScreen> {
  final _printerService = ReceiptPrinterService();
  Locale _receiptLocale = const Locale('en');
  bool _includeBagDetails = false;
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(
      harvestReceivingControllerProvider(widget.warehouseId),
    );
    final harvest = session.savedHarvest;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(l10n.receiptTitle),
        automaticallyImplyLeading: false,
      ),
      body: harvest == null
          ? _missingReceipt(context, l10n)
          : _receipt(context, l10n, harvest, session.savedBagCount),
    );
  }

  Widget _missingReceipt(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.noReceiptYet,
        subtitle: l10n.completeReceivingBeforeReceipt,
        actionLabel: l10n.startReceiving,
        onAction: () => context.go(
          widget.ownerFlow
              ? AppRoutes.ownerConnectScaleFor(widget.warehouseId)
              : AppRoutes.workerConnectScaleFor(widget.warehouseId),
        ),
      ),
    );
  }

  Widget _receipt(
    BuildContext context,
    AppLocalizations l10n,
    FarmerHarvest harvest,
    int bagCount,
  ) {
    final date = DateFormat('MMM d, yyyy HH:mm', l10n.localeName)
        .format(harvest.receivedAt);
    final uom = harvest.uomName ?? 'kg';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepHeader(),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.warehouseReceipt,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            harvest.receiptNumber,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _receiptRow(l10n.receiptFarmer, harvest.farmerName),
                _receiptRow(l10n.receiptCrop, harvest.cropName),
                _receiptRow(
                    l10n.receiptWarehouse, harvest.collectionCenterName),
                _receiptRow(l10n.receiptBags, '$bagCount'),
                _receiptRow(
                  l10n.receiptGross,
                  '${_formatWeight(harvest.grossWeight)} $uom',
                ),
                _receiptRow(
                  l10n.receiptTare,
                  '${_formatWeight(harvest.packagingWeight)} $uom',
                ),
                _receiptRow(
                  l10n.receiptNet,
                  '${_formatWeight(harvest.netWeight)} $uom',
                  bold: true,
                ),
                _receiptRow(l10n.receiptDate, date),
                if (harvest.receivedByName != null)
                  _receiptRow(l10n.receiptReceivedBy, harvest.receivedByName!),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(harvestReceivingControllerProvider(
                    widget.warehouseId,
                  ).notifier)
                  .reset();
              context.go(
                widget.ownerFlow
                    ? AppRoutes.ownerConnectScaleFor(widget.warehouseId)
                    : AppRoutes.workerConnectScaleFor(widget.warehouseId),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ownerColor,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.newReceiving),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _printing ? null : () => _printReceipt(harvest, l10n),
            icon: _printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            label: Text(l10n.printReceipt),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(
    FarmerHarvest harvest,
    AppLocalizations appL10n,
  ) async {
    if (_printing) return;

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
            harvest.uuid,
          );
      final receiptL10n = lookupAppLocalizations(options.locale);
      await _printerService.printHarvestReceipt(
        printer: printer,
        harvest: harvest,
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
        description: error is ReceiptPrinterException &&
                error.message == appL10n.bluetoothPermissionRequired
            ? error.message
            : appL10n.printerLoadError,
        type: AppFeedbackType.error,
        actions: [
          AppFeedbackAction<void>(label: appL10n.ok, isPrimary: true),
        ],
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

  Widget _stepHeader() {
    return AppCard(
      child: Row(
        children: [
          _stepBubble('1'),
          _stepLine(),
          _stepBubble('2'),
          _stepLine(),
          _stepBubble('3'),
        ],
      ),
    );
  }

  Widget _stepBubble(String label) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.ownerColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _stepLine() {
    return const Expanded(
      child: Divider(
        thickness: 2,
        color: AppColors.ownerColor,
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
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
