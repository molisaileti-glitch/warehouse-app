import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:warehouse_app/core/router/app_router.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/scale/presentation/providers/weight_scale_controller.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final scaleState = ref.watch(weightScaleControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Connect Scale')),
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
              label: const Text('Next'),
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
                  const Text(
                    'Connect the scale',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect a Bluetooth scale before measuring crops. Once connected, the live reading will be used on the weighing screen.',
                    style: TextStyle(
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
                              ? 'Connected'
                              : 'Not connected',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scaleState.isConnected
                              ? scaleState.deviceName
                              : 'Scan nearby devices to find your scale.',
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
                scaleState.lastError,
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
              label: Text(_scanning ? 'Scanning...' : 'Scan Devices'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDevicesSheet() async {
    setState(() => _scanning = true);
    final controller = ref.read(weightScaleControllerProvider.notifier);
    var devices = await controller.scanForScales();
    if (!mounted) return;
    setState(() => _scanning = false);

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
                        const Expanded(
                          child: Text(
                            'Available Devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh devices',
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: Icons.bluetooth_disabled_rounded,
                          title: 'No devices found',
                          subtitle: 'Turn on the scale and refresh.',
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
    final device = result.device;
    final name = _deviceName(device);
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
                      ? 'Likely scale - ${result.rssi} dBm'
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
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  String _deviceName(BluetoothDevice device) {
    final advertisedName = device.advName.trim();
    final platformName = device.platformName.trim();
    if (advertisedName.isNotEmpty) return advertisedName;
    if (platformName.isNotEmpty) return platformName;
    return 'Unknown Scale';
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
