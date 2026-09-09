import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warehouse_app/core/components/app_feedback.dart';
import 'package:warehouse_app/core/components/input_field.dart';
import 'package:warehouse_app/core/theme/app_theme.dart';
import 'package:warehouse_app/features/moisture/data/services/landtek_moisture_meter_service.dart';
import 'package:warehouse_app/features/moisture/domain/models/moisture_reading.dart';
import 'package:warehouse_app/features/shared/widgets/common_widgets.dart';

Future<double?> askAndMeasureMoisture({
  required BuildContext context,
  required String cropName,
  double? maxMoistureContent,
}) async {
  final max = _positiveMax(maxMoistureContent);
  final shouldMeasure = await showAppFeedbackDialog<bool>(
    context,
    title: 'Measure moisture?',
    description: max == null
        ? 'Do you want to measure moisture for this bag?'
        : 'Do you want to measure moisture for this bag? Maximum allowed is ${_format(max)}%.',
    type: AppFeedbackType.confirmation,
    actions: const [
      AppFeedbackAction<bool>(label: 'Skip', result: false),
      AppFeedbackAction<bool>(
        label: 'Measure',
        result: true,
        isPrimary: true,
      ),
    ],
  );

  if (!context.mounted) return null;
  if (shouldMeasure != true) return 0;

  return Navigator.of(context).push<double>(
    MaterialPageRoute(
      builder: (_) => MoistureReadingScreen(
        cropName: cropName,
        maxMoistureContent: max,
      ),
    ),
  );
}

class MoistureReadingScreen extends StatefulWidget {
  final String cropName;
  final double? maxMoistureContent;

  const MoistureReadingScreen({
    super.key,
    required this.cropName,
    this.maxMoistureContent,
  });

  @override
  State<MoistureReadingScreen> createState() => _MoistureReadingScreenState();
}

class _MoistureReadingScreenState extends State<MoistureReadingScreen> {
  static const _baudRates = [2400, 4800, 9600, 19200, 38400, 57600, 115200];

  final _service = LandtekMoistureMeterService();
  final _manual = TextEditingController();
  final _values = <MoistureZone, double?>{
    MoistureZone.top: null,
    MoistureZone.lowerTop: null,
    MoistureZone.highBottom: null,
    MoistureZone.bottom: null,
  };

  List<MoistureUsbDevice> _devices = const [];
  MoistureUsbDevice? _selectedDevice;
  MoistureZone _activeZone = MoistureZone.top;
  int _ignoredDeviceCount = 0;
  int _baudRate = 2400;
  bool _scanning = false;
  bool _connecting = false;
  bool _reading = false;
  String? _error;

  GrainMaterial? get _expectedMaterial {
    return GrainMaterial.forCropName(widget.cropName);
  }

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  @override
  void dispose() {
    _manual.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _changeBaudRate(int? value) async {
    if (value == null || value == _baudRate) return;
    await _service.disconnect();
    if (!mounted) return;
    setState(() {
      _baudRate = value;
      _error = 'Baud rate changed. Connect the moisture meter again.';
    });
  }

  Future<void> _scanDevices() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await _service.scanDevices();
      if (!mounted) return;
      setState(() {
        _devices = result.devices;
        _ignoredDeviceCount = result.ignoredDeviceCount;
        _selectedDevice = result.devices.isEmpty ? null : result.devices.first;
        if (result.devices.isEmpty) {
          _error = result.ignoredDeviceCount > 0
              ? 'No serial moisture meter found. ${result.ignoredDeviceCount} non-serial USB device(s) were ignored.'
              : 'No moisture meter found. Connect the meter with USB OTG, then scan again.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect() async {
    final device = _selectedDevice;
    if (device == null) {
      setState(() => _error = 'Connect the USB moisture meter.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _service.connect(device, baudRate: _baudRate);
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _readActiveZone() async {
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final reading = await _service.readMeasurement();
      if (!mounted) return;
      final expectedMaterial = _expectedMaterial;
      if (expectedMaterial != null &&
          !expectedMaterial.matchesCode(reading.materialCode)) {
        setState(() {
          _error =
              'Meter grain code ${_meterCodeLabel(reading.materialCode)} does not match ${widget.cropName}. Set the meter to ${expectedMaterial.name} (${expectedMaterial.codeLabel}) and read again.';
        });
        return;
      }
      _setZoneValue(_activeZone, reading.value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _saveManualValue() {
    final value = double.tryParse(_manual.text.trim());
    if (value == null || value < 0 || value > 100) {
      setState(() => _error = 'Enter moisture from 0 to 100.');
      return;
    }
    _manual.clear();
    _setZoneValue(_activeZone, value);
  }

  void _setZoneValue(MoistureZone zone, double value) {
    setState(() {
      _values[zone] = value;
      _error = null;
      _activeZone = _nextEmptyZone() ?? zone;
    });
  }

  void _clearZoneValue(MoistureZone zone) {
    setState(() {
      _values[zone] = null;
      _activeZone = zone;
      _error = null;
    });
  }

  void _resetReadings() {
    setState(() {
      for (final zone in MoistureZone.values) {
        _values[zone] = null;
      }
      _activeZone = MoistureZone.top;
      _error = null;
    });
  }

  MoistureZone? _nextEmptyZone() {
    for (final zone in MoistureZone.values) {
      final value = _values[zone];
      if (value == null || value <= 0) return zone;
    }
    return null;
  }

  bool get _complete => MoistureZone.values.every((zone) {
        final value = _values[zone];
        return value != null && value > 0;
      });

  double get _average {
    if (!_complete) return 0;
    final total = MoistureZone.values.fold<double>(
      0,
      (sum, zone) => sum + (_values[zone] ?? 0),
    );
    return total / MoistureZone.values.length;
  }

  bool get _withinMax {
    final max = widget.maxMoistureContent;
    return max == null || _average <= max;
  }

  Future<void> _proceed() async {
    if (!_complete) return;
    if (!_withinMax) {
      await showAppFeedbackDialog<void>(
        context,
        title: 'Moisture too high',
        description:
            'Average moisture is ${_format(_average)}%, above the allowed ${_format(widget.maxMoistureContent)}%. This bag cannot be saved.',
        type: AppFeedbackType.error,
        actions: [
          const AppFeedbackAction<void>(label: 'OK'),
        ],
      );
      return;
    }
    if (!mounted) return;
    await showSuccessDialog(
      context,
      title: 'Moisture recorded',
      description:
          'Average moisture is ${_format(_average)}%. This bag is suitable.',
    );
    if (!mounted) return;
    Navigator.of(context).pop(_average);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.maxMoistureContent;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('${widget.cropName} moisture')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _SummaryCard(
              average: _average,
              complete: _complete,
              maxMoistureContent: max,
              withinMax: _withinMax,
            ),
            const SizedBox(height: 16),
            _MeterCard(
              devices: _devices,
              selectedDevice: _selectedDevice,
              connected: _service.isConnected,
              expectedMaterial: _expectedMaterial,
              cropName: widget.cropName,
              ignoredDeviceCount: _ignoredDeviceCount,
              baudRate: _baudRate,
              baudRates: _baudRates,
              scanning: _scanning,
              connecting: _connecting,
              reading: _reading,
              onDeviceChanged: (device) => setState(() {
                _selectedDevice = device;
                _error = null;
              }),
              onBaudRateChanged: _changeBaudRate,
              onScan: _scanDevices,
              onConnect: _connect,
              onRead: _readActiveZone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            _ZonesCard(
              values: _values,
              activeZone: _activeZone,
              onZoneSelected: (zone) => setState(() => _activeZone = zone),
              onZoneCleared: _clearZoneValue,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _values.values
                        .any((value) => value != null && value > 0)
                    ? _resetReadings
                    : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset readings'),
              ),
            ),
            const SizedBox(height: 16),
            AppLabeledField(
              labelText: 'Manual reading for ${_zoneLabel(_activeZone)}',
              child: TextFormField(
                controller: _manual,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.water_drop_outlined),
                  suffixText: '%',
                  suffixIcon: IconButton(
                    onPressed: _saveManualValue,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _complete ? _proceed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.workerColor,
              ),
              child: const Text('Use moisture reading'),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('timeout') || text.contains('TimeoutException')) {
      return 'No reading received. Press the meter read/send button and try again, or enter the value manually.';
    }
    if (text.contains('permission')) {
      return 'USB permission was not granted. Allow USB access and try again.';
    }
    if (text.contains('UsbSerialPortAdapter') ||
        text.contains('Not an serial device') ||
        text.contains('not a serial device')) {
      return 'That USB device is not a serial moisture meter. Connect the moisture meter using USB OTG, then scan again.';
    }
    return text;
  }
}

class _SummaryCard extends StatelessWidget {
  final double average;
  final bool complete;
  final double? maxMoistureContent;
  final bool withinMax;

  const _SummaryCard({
    required this.average,
    required this.complete,
    required this.maxMoistureContent,
    required this.withinMax,
  });

  @override
  Widget build(BuildContext context) {
    final color = !complete
        ? AppColors.textMuted
        : withinMax
            ? AppColors.success
            : AppColors.error;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(Icons.water_drop_outlined, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete ? '${_format(average)}%' : '--',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  maxMoistureContent == null
                      ? 'Average moisture'
                      : 'Max allowed ${_format(maxMoistureContent)}%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (complete)
            Icon(
              withinMax
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: color,
            ),
        ],
      ),
    );
  }
}

class _MeterCard extends StatelessWidget {
  final List<MoistureUsbDevice> devices;
  final MoistureUsbDevice? selectedDevice;
  final bool connected;
  final GrainMaterial? expectedMaterial;
  final String cropName;
  final int ignoredDeviceCount;
  final int baudRate;
  final List<int> baudRates;
  final bool scanning;
  final bool connecting;
  final bool reading;
  final ValueChanged<MoistureUsbDevice?> onDeviceChanged;
  final ValueChanged<int?> onBaudRateChanged;
  final VoidCallback onScan;
  final VoidCallback onConnect;
  final VoidCallback onRead;

  const _MeterCard({
    required this.devices,
    required this.selectedDevice,
    required this.connected,
    required this.expectedMaterial,
    required this.cropName,
    required this.ignoredDeviceCount,
    required this.baudRate,
    required this.baudRates,
    required this.scanning,
    required this.connecting,
    required this.reading,
    required this.onDeviceChanged,
    required this.onBaudRateChanged,
    required this.onScan,
    required this.onConnect,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Moisture meter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Scan moisture meter',
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            devices.isEmpty
                ? 'Connect the Landtek moisture meter with USB OTG, then scan.'
                : '${devices.length} moisture meter candidate(s) found.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          _MaterialVerificationHint(
            cropName: cropName,
            expectedMaterial: expectedMaterial,
          ),
          const SizedBox(height: 12),
          AppLabeledField(
            labelText: 'Baud rate',
            child: DropdownButtonFormField<int>(
              value: baudRate,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.speed_rounded),
              ),
              items: baudRates
                  .map(
                    (rate) => DropdownMenuItem<int>(
                      value: rate,
                      child: Text('$rate baud'),
                    ),
                  )
                  .toList(),
              onChanged: connecting || reading ? null : onBaudRateChanged,
            ),
          ),
          if (ignoredDeviceCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$ignoredDeviceCount non-serial USB device(s) ignored.',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: scanning ? null : onScan,
              icon: scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_search_rounded),
              label: Text(scanning ? 'Scanning...' : 'Scan moisture meter'),
            ),
          ),
          if (devices.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...devices.map(
              (device) => _MoistureDeviceTile(
                device: device,
                selected: device == selectedDevice,
                connected: connected && device == selectedDevice,
                onTap: () => onDeviceChanged(device),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      selectedDevice == null || connecting ? null : onConnect,
                  icon: connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          connected
                              ? Icons.check_circle_outline_rounded
                              : Icons.usb_rounded,
                        ),
                  label: Text(connected ? 'Connected' : 'Connect'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: connected && !reading ? onRead : null,
                  icon: reading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sensors_rounded),
                  label: Text(reading ? 'Reading' : 'Read phase'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoistureDeviceTile extends StatelessWidget {
  final MoistureUsbDevice device;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  const _MoistureDeviceTile({
    required this.device,
    required this.selected,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = connected || selected ? AppColors.workerColor : AppColors.divider;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
            color: selected
                ? AppColors.workerColor.withValues(alpha: 0.06)
                : Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                connected
                    ? Icons.check_circle_outline_rounded
                    : Icons.usb_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.description,
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
      ),
    );
  }
}

class _MaterialVerificationHint extends StatelessWidget {
  final String cropName;
  final GrainMaterial? expectedMaterial;

  const _MaterialVerificationHint({
    required this.cropName,
    required this.expectedMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final material = expectedMaterial;
    final text = material == null
        ? 'Grain code verification is not configured for $cropName.'
        : 'Meter must be set to ${material.name} (${material.codeLabel}).';
    final color = material == null ? AppColors.warning : AppColors.success;

    return Row(
      children: [
        Icon(
          material == null
              ? Icons.info_outline_rounded
              : Icons.verified_outlined,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ZonesCard extends StatelessWidget {
  final Map<MoistureZone, double?> values;
  final MoistureZone activeZone;
  final ValueChanged<MoistureZone> onZoneSelected;
  final ValueChanged<MoistureZone> onZoneCleared;

  const _ZonesCard({
    required this.values,
    required this.activeZone,
    required this.onZoneSelected,
    required this.onZoneCleared,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: MoistureZone.values.map((zone) {
          final selected = zone == activeZone;
          final value = values[zone];
          final hasValue = value != null && value > 0;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => onZoneSelected(zone),
            leading: CircleAvatar(
              backgroundColor: selected
                  ? AppColors.workerColor.withValues(alpha: 0.12)
                  : AppColors.divider,
              child: Icon(
                hasValue
                    ? Icons.check_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.workerColor : AppColors.textMuted,
              ),
            ),
            title: Text(
              _zoneLabel(zone),
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasValue ? '${_format(value)}%' : '--',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (hasValue) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Re-read phase',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onZoneCleared(zone),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String _zoneLabel(MoistureZone zone) {
  return switch (zone) {
    MoistureZone.top => 'Top',
    MoistureZone.lowerTop => 'Lower top',
    MoistureZone.highBottom => 'High bottom',
    MoistureZone.bottom => 'Bottom',
  };
}

String _format(double? value) {
  if (value == null) return '--';
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

double? _positiveMax(double? value) {
  if (value == null || value <= 0) return null;
  return value;
}

String _meterCodeLabel(int? value) {
  if (value == null) return 'unknown';
  return 'Cd${value.toRadixString(16).padLeft(2, '0')}';
}
