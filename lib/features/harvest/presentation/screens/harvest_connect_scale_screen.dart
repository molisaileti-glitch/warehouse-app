import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/scale/presentation/providers/weight_scale_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class HarvestConnectScaleScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  final bool ownerFlow;

  const HarvestConnectScaleScreen({
    super.key,
    required this.warehouseId,
    required this.ownerFlow,
  });

  @override
  ConsumerState<HarvestConnectScaleScreen> createState() =>
      _HarvestConnectScaleScreenState();
}

class _HarvestConnectScaleScreenState
    extends ConsumerState<HarvestConnectScaleScreen> {
  bool _scanning = false;
  bool _requirementDialogVisible = false;
  bool _hasShownRequirementDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBluetoothLocationDialogIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaleState = ref.watch(weightScaleControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.connectScale)),
      floatingActionButton: scaleState.isConnected
          ? FloatingActionButton.extended(
              heroTag: 'connect_scale_next_${widget.warehouseId}',
              backgroundColor: AppColors.ownerColor,
              foregroundColor: Colors.white,
              onPressed: () => context.push(
                widget.ownerFlow
                    ? AppRoutes.ownerFarmerDetailsFor(widget.warehouseId)
                    : AppRoutes.workerFarmerDetailsFor(widget.warehouseId),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.next),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.ownerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.monitor_weight_outlined,
                      color: AppColors.ownerColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.connectTheScale,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.connectScaleDescription,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  Icon(
                    scaleState.isConnected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_disabled_rounded,
                    color: scaleState.isConnected
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scaleState.isConnected
                              ? l10n.connected
                              : l10n.notConnected,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scaleState.isConnected
                              ? scaleState.deviceName
                              : l10n.scanNearbyScale,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (scaleState.lastError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _localizedScaleError(l10n, scaleState.lastError),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _scanning ? null : _openDevicesSheet,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded),
              label: Text(_scanning ? l10n.scanning : l10n.scanDevices),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDevicesSheet() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _scanning = true);
    final controller = ref.read(weightScaleControllerProvider.notifier);
    var devices = await controller.scanForScales();
    if (!mounted) return;
    setState(() => _scanning = false);

    if (devices.isEmpty) {
      await _showBluetoothLocationDialogIfNeeded(force: true);
      if (!mounted) return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        var sheetDevices = devices;
        var refreshing = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refresh() async {
              setSheetState(() => refreshing = true);
              final nextDevices = await controller.scanForScales();
              if (!context.mounted) return;
              setSheetState(() {
                sheetDevices = nextDevices;
                refreshing = false;
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.availableDevices,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.refreshDevices,
                          onPressed: refreshing ? null : refresh,
                          icon: refreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (sheetDevices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: Icons.bluetooth_disabled_rounded,
                          title: l10n.noDevicesFound,
                          subtitle: l10n.deviceScanHelp,
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sheetDevices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final result = sheetDevices[index];
                            return _DeviceCard(
                              result: result,
                              onConnect: () async {
                                await controller.connectToDevice(result.device);
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _showBluetoothLocationDialogIfNeeded(
      {bool force = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_requirementDialogVisible || (!force && _hasShownRequirementDialog)) {
      return false;
    }
    final needsReminder = await _needsBluetoothLocationReminder();
    if (!mounted || !needsReminder) return false;

    _requirementDialogVisible = true;
    _hasShownRequirementDialog = true;
    await showAppFeedbackDialog<void>(
      context,
      title: l10n.bluetoothLocationRequired,
      description: l10n.bluetoothLocationMessage,
      type: AppFeedbackType.info,
      actions: [
        AppFeedbackAction<void>(label: l10n.ok, isPrimary: true),
      ],
    );
    _requirementDialogVisible = false;
    return true;
  }

  Future<bool> _needsBluetoothLocationReminder() async {
    final adapterState = await FlutterBluePlus.adapterState.first;
    final locationStatus = await Permission.locationWhenInUse.status;
    final locationService = await Permission.locationWhenInUse.serviceStatus;
    final bluetoothScanStatus = await Permission.bluetoothScan.status;
    final bluetoothConnectStatus = await Permission.bluetoothConnect.status;

    return adapterState != BluetoothAdapterState.on ||
        !locationStatus.isGranted ||
        !locationService.isEnabled ||
        !bluetoothScanStatus.isGranted ||
        !bluetoothConnectStatus.isGranted;
  }
}

String _localizedScaleError(AppLocalizations l10n, String error) {
  if (error.startsWith('Bluetooth permissions are required')) {
    return l10n.scaleBluetoothPermissionError;
  }
  if (error.startsWith('Turn on Bluetooth')) {
    return l10n.turnOnBluetoothToScan;
  }
  if (error.startsWith('Failed to scan for scales')) {
    return l10n.scaleScanError;
  }
  if (error.startsWith('Connection failed')) {
    return l10n.scaleConnectionError;
  }
  if (error.startsWith('No scale connected')) {
    return l10n.noScaleConnected;
  }
  if (error.startsWith('Failed to start scale stream')) {
    return l10n.scaleStreamError;
  }
  if (error.startsWith('Failed to request scale data')) {
    return l10n.scaleReadError;
  }
  return l10n.errorWithDetails(error);
}

class _DeviceCard extends StatelessWidget {
  final ScanResult result;
  final Future<void> Function() onConnect;

  const _DeviceCard({
    required this.result,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final device = result.device;
    final name = _deviceName(device, l10n.unknownScale);
    final likelyScale = _looksLikeScale(result);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.ownerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              color: AppColors.ownerColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  likelyScale
                      ? l10n.likelyScale(result.rssi)
                      : '${device.remoteId} - ${result.rssi} dBm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onConnect,
            child: Text(l10n.connect),
          ),
        ],
      ),
    );
  }

  String _deviceName(BluetoothDevice device, [String unknownName = '']) {
    final advertisedName = device.advName.trim();
    final platformName = device.platformName.trim();
    if (advertisedName.isNotEmpty) return advertisedName;
    if (platformName.isNotEmpty) return platformName;
    return unknownName;
  }

  bool _looksLikeScale(ScanResult result) {
    final name = _deviceName(result.device).toLowerCase();
    final hasScaleName = [
      'scale',
      'weigh',
      'balance',
      'als',
      'szl',
      'gs-s',
      'gs_s',
    ].any(name.contains);
    final hasScaleService = result.advertisementData.serviceUuids.any(
      (uuid) => uuid.toString().toUpperCase().contains('FFE0'),
    );
    return hasScaleName || hasScaleService;
  }
}
