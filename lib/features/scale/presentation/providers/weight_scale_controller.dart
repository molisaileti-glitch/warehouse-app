import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class WeightScaleState {
  const WeightScaleState({
    this.device,
    this.deviceName = '',
    this.weight = 0,
    this.uom = 'kg',
    this.isScanning = false,
    this.isConnecting = false,
    this.isStreaming = false,
    this.isStable = false,
    this.statusMessage = '',
    this.lastError = '',
  });

  final BluetoothDevice? device;
  final String deviceName;
  final double weight;
  final String uom;
  final bool isScanning;
  final bool isConnecting;
  final bool isStreaming;
  final bool isStable;
  final String statusMessage;
  final String lastError;

  bool get isConnected => device != null;

  WeightScaleState copyWith({
    BluetoothDevice? device,
    bool clearDevice = false,
    String? deviceName,
    double? weight,
    String? uom,
    bool? isScanning,
    bool? isConnecting,
    bool? isStreaming,
    bool? isStable,
    String? statusMessage,
    String? lastError,
  }) {
    return WeightScaleState(
      device: clearDevice ? null : device ?? this.device,
      deviceName: deviceName ?? this.deviceName,
      weight: weight ?? this.weight,
      uom: uom ?? this.uom,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      isStreaming: isStreaming ?? this.isStreaming,
      isStable: isStable ?? this.isStable,
      statusMessage: statusMessage ?? this.statusMessage,
      lastError: lastError ?? this.lastError,
    );
  }
}

final weightScaleControllerProvider =
    StateNotifierProvider<WeightScaleController, WeightScaleState>((ref) {
  final controller = WeightScaleController();
  ref.onDispose(controller.dispose);
  return controller;
});

class WeightScaleController extends StateNotifier<WeightScaleState> {
  WeightScaleController() : super(const WeightScaleState());

  static const _requestCommand = 'L';
  static const _serviceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const _characteristicUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';
  static const _commandInterval = Duration(milliseconds: 900);
  static const _scanDuration = Duration(seconds: 12);
  static const _scanGracePeriod = Duration(milliseconds: 1200);
  static const _scaleNamePatterns = [
    'als-3',
    'als3',
    'scale',
    'weigh',
    'balance',
    'logistics',
    'tamper',
    'detection',
    'szl-e',
    'szl',
    'gs-s',
    'gs_s',
  ];

  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _weightSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _communicationTimer;
  String _incomingBuffer = '';
  bool _isSettingUp = false;

  Future<List<ScanResult>> scanForScales() async {
    final hasPermissions = await _ensurePermissions();
    if (!hasPermissions) {
      state = state.copyWith(
        lastError: 'Bluetooth permissions are required to connect the scale.',
        statusMessage: 'Bluetooth permissions required',
      );
      return const [];
    }

    final bluetoothReady = await _ensureBluetoothEnabled();
    if (!bluetoothReady) {
      state = state.copyWith(
        lastError: 'Turn on Bluetooth to scan for scales.',
        statusMessage: 'Bluetooth is off',
      );
      return const [];
    }

    await _stopScan();
    final devicesById = <String, ScanResult>{};
    state = state.copyWith(
      isScanning: true,
      statusMessage: 'Scanning for scales',
      lastError: '',
    );

    try {
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in _discoverableDevices(results)) {
          devicesById[result.device.remoteId.toString()] = result;
        }
      });

      await FlutterBluePlus.startScan(
        timeout: _scanDuration,
        androidUsesFineLocation: true,
      );
      await Future.delayed(_scanDuration + _scanGracePeriod);
    } catch (error) {
      state = state.copyWith(
        lastError: 'Failed to scan for scales: $error',
        statusMessage: 'Scale scan failed',
      );
    } finally {
      await _stopScan();
    }

    final devices = devicesById.values.toList()
      ..sort((a, b) {
        final aLikelyScale = _looksLikeScale(a) ? 1 : 0;
        final bLikelyScale = _looksLikeScale(b) ? 1 : 0;
        final scaleCompare = bLikelyScale.compareTo(aLikelyScale);
        if (scaleCompare != 0) return scaleCompare;
        return b.rssi.compareTo(a.rssi);
      });
    return devices;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await _stopScan();
      if (state.device != null &&
          state.device!.remoteId.toString() != device.remoteId.toString()) {
        await disconnect();
      }

      state = state.copyWith(
        isConnecting: true,
        statusMessage: 'Connecting to ${_deviceName(device)}',
        lastError: '',
      );

      await _connectionSubscription?.cancel();
      _connectionSubscription =
          device.connectionState.listen((connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected &&
            state.device?.remoteId.toString() == device.remoteId.toString()) {
          _reset(clearDevice: true);
        }
      });

      final connectionState = await device.connectionState.first;
      if (connectionState != BluetoothConnectionState.connected) {
        try {
          await device.connect(timeout: const Duration(seconds: 12));
        } catch (error) {
          if (!error.toString().toLowerCase().contains('already')) {
            rethrow;
          }
        }
      }

      state = state.copyWith(
        device: device,
        deviceName: _deviceName(device),
        statusMessage: 'Connected to ${_deviceName(device)}',
      );
      await _setupCommunication(device);
    } catch (error) {
      state = state.copyWith(
        lastError: 'Connection failed: $error',
        statusMessage: 'Scale connection failed',
      );
      _reset(clearDevice: true);
    } finally {
      state = state.copyWith(isConnecting: false);
    }
  }

  Future<void> disconnect() async {
    final device = state.device;
    _stopPeriodicCommunication();
    await _weightSubscription?.cancel();
    _weightSubscription = null;
    await _setNotifications(enabled: false);
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _characteristic = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _reset(clearDevice: true);
  }

  Future<void> requestCurrentWeight() async {
    final device = state.device;
    if (device == null) {
      state = state.copyWith(
        lastError: 'No scale connected',
        statusMessage: 'No scale connected',
      );
      return;
    }

    final connectionState = await device.connectionState.first;
    if (connectionState != BluetoothConnectionState.connected) {
      await connectToDevice(device);
      return;
    }

    if (_characteristic == null || !state.isStreaming) {
      await _setupCommunication(device);
    }
    await _sendCommand(_requestCommand);
  }

  Future<void> _setupCommunication(BluetoothDevice device) async {
    if (_isSettingUp) return;
    _isSettingUp = true;

    try {
      final characteristic = await _findScaleCharacteristic(device);
      if (characteristic == null) {
        throw Exception('Scale characteristic not found');
      }

      _characteristic = characteristic;
      await _setNotifications(enabled: true);
      await _weightSubscription?.cancel();
      _weightSubscription =
          characteristic.onValueReceived.listen(_handleScaleData);
      _startPeriodicCommunication();
      state = state.copyWith(isStreaming: true);
      await _sendCommand(_requestCommand);
    } catch (error) {
      state = state.copyWith(
        isStreaming: false,
        lastError: 'Failed to start scale stream: $error',
        statusMessage: 'Scale stream failed',
      );
    } finally {
      _isSettingUp = false;
    }
  }

  Future<BluetoothCharacteristic?> _findScaleCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();

    BluetoothService? selectedService;
    for (final service in services) {
      final uuid = service.uuid.toString().toUpperCase();
      if (uuid == _serviceUuid || uuid.contains('FFE0')) {
        selectedService = service;
        break;
      }
    }
    selectedService ??= services.isNotEmpty ? services.first : null;
    if (selectedService == null) return null;

    for (final characteristic in selectedService.characteristics) {
      final uuid = characteristic.uuid.toString().toUpperCase();
      if (uuid == _characteristicUuid || uuid.contains('FFE1')) {
        return characteristic;
      }
    }

    for (final characteristic in selectedService.characteristics) {
      if (characteristic.properties.write ||
          characteristic.properties.writeWithoutResponse ||
          characteristic.properties.notify ||
          characteristic.properties.indicate) {
        return characteristic;
      }
    }

    return selectedService.characteristics.isNotEmpty
        ? selectedService.characteristics.first
        : null;
  }

  Future<void> _setNotifications({required bool enabled}) async {
    final characteristic = _characteristic;
    if (characteristic == null) return;
    if (!characteristic.properties.notify &&
        !characteristic.properties.indicate) {
      return;
    }

    try {
      await characteristic.setNotifyValue(enabled);
    } catch (_) {}
  }

  Future<bool> _sendCommand(String command) async {
    final characteristic = _characteristic;
    if (characteristic == null) return false;

    try {
      if (characteristic.properties.write ||
          characteristic.properties.writeWithoutResponse) {
        await characteristic.write(
          utf8.encode('$command\r\n'),
          withoutResponse: !characteristic.properties.write &&
              characteristic.properties.writeWithoutResponse,
        );
        return true;
      }

      if (characteristic.properties.read) {
        final value = await characteristic.read();
        _handleScaleData(value);
        return true;
      }
    } catch (error) {
      state = state.copyWith(
        lastError: 'Failed to request scale data: $error',
        statusMessage: 'Failed to read scale',
      );
    }
    return false;
  }

  void _handleScaleData(List<int> data) {
    if (data.isEmpty) return;
    final isCommandEcho =
        (data.length == 3 && data[0] == 76 && data[1] == 13 && data[2] == 10) ||
            (data.length == 2 && data[0] == 76 && data[1] == 10) ||
            (data.length == 1 && data[0] == 76);
    if (isCommandEcho) return;

    final decoded = utf8.decode(data, allowMalformed: true);
    if (decoded.trim() == _requestCommand) return;

    _incomingBuffer += decoded;
    _processIncomingBuffer();
  }

  void _processIncomingBuffer() {
    final matches = RegExp(r'((?:ST|US),GS,.*?(?=(?:ST|US),GS|[\r\n]|$))')
        .allMatches(_incomingBuffer)
        .toList();

    var consumedUntil = 0;
    for (final match in matches) {
      final frame = match.group(1);
      if (frame == null || frame.isEmpty) continue;
      final isLastMatch = match.end == _incomingBuffer.length;
      final hasTerminator = frame.endsWith('\n') || frame.endsWith('\r');
      final looksComplete = _looksLikeCompleteFrame(frame);
      if (isLastMatch && !hasTerminator && !looksComplete) break;
      _applyParsedFrame(frame);
      consumedUntil = match.end;
    }

    if (consumedUntil > 0) {
      _incomingBuffer = _incomingBuffer.substring(consumedUntil);
    }

    if (consumedUntil == 0 &&
        (_incomingBuffer.contains('\n') || _incomingBuffer.contains('\r'))) {
      _processSimpleNumericBuffer();
    }

    if (_incomingBuffer.length > 256) {
      final stableIndex = _incomingBuffer.lastIndexOf('ST,GS,');
      final unstableIndex = _incomingBuffer.lastIndexOf('US,GS,');
      final keepFrom =
          stableIndex > unstableIndex ? stableIndex : unstableIndex;
      _incomingBuffer =
          keepFrom >= 0 ? _incomingBuffer.substring(keepFrom) : '';
    }
  }

  void _processSimpleNumericBuffer() {
    final lines = _incomingBuffer.split(RegExp(r'[\r\n]+'));
    final incompleteTrail =
        _incomingBuffer.endsWith('\n') || _incomingBuffer.endsWith('\r')
            ? ''
            : (lines.isNotEmpty ? lines.last : '');

    for (var i = 0; i < lines.length - (incompleteTrail.isEmpty ? 0 : 1); i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line == _requestCommand) continue;
      final match =
          RegExp(r'^([+\-]?\s*\d+(?:\.\d+)?)\s*([a-zA-Z]*)$').firstMatch(line);
      if (match == null) continue;
      final rawWeight =
          double.tryParse((match.group(1) ?? '').replaceAll(' ', ''));
      if (rawWeight == null) continue;
      final unit = (match.group(2) ?? '').isEmpty ? 'kg' : match.group(2)!;
      final weightInKg = _convertWeightToKg(rawWeight, unit);
      if (weightInKg == null) continue;

      state = state.copyWith(
        weight: _round(weightInKg),
        uom: 'kg',
        isStable: true,
        isStreaming: true,
        lastError: '',
        statusMessage: 'Reading scale',
      );
    }

    _incomingBuffer = incompleteTrail;
  }

  bool _looksLikeCompleteFrame(String rawFrame) {
    final clean = rawFrame.trim().replaceAll(RegExp(r'[\r\n]'), '');
    if (!(clean.startsWith('ST,GS,') || clean.startsWith('US,GS,'))) {
      return false;
    }
    return RegExp(r'^(?:ST|US),GS,[+\-]\s*[0-9]+(?:\.[0-9]+)?[a-zA-Z]+.*$')
        .hasMatch(clean);
  }

  void _applyParsedFrame(String rawFrame) {
    final parsed = _parseScaleFrame(rawFrame);
    if (parsed == null) return;
    state = state.copyWith(
      weight: _round(parsed.weight),
      uom: parsed.unit,
      isStable: parsed.isStable,
      isStreaming: true,
      lastError: '',
      statusMessage: parsed.isStable ? 'Stable reading' : 'Unstable reading',
    );
  }

  _ParsedScaleFrame? _parseScaleFrame(String rawData) {
    final cleanData = rawData.trim().replaceAll(RegExp(r'[\r\n]'), '');
    if (!(cleanData.startsWith('ST,GS,') || cleanData.startsWith('US,GS,'))) {
      return null;
    }

    final weightMatch = RegExp(r'[+\-]\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]+)')
        .firstMatch(cleanData);
    if (weightMatch == null) return null;

    final magnitude = double.tryParse(weightMatch.group(1) ?? '');
    final unit = (weightMatch.group(2) ?? '').toLowerCase();
    if (magnitude == null || unit.isEmpty) return null;

    final signedToken = weightMatch.group(0) ?? '';
    final signedMagnitude =
        signedToken.trim().startsWith('-') ? -magnitude : magnitude;
    final weightInKg = _convertWeightToKg(signedMagnitude, unit);
    if (weightInKg == null) return null;

    return _ParsedScaleFrame(
      weight: weightInKg,
      unit: 'kg',
      isStable: cleanData.startsWith('ST,GS,') && weightInKg >= 0,
    );
  }

  double? _convertWeightToKg(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
        return value;
      case 'g':
        return value / 1000.0;
      case 'oz':
        return value * 0.0283495;
      case 'lb':
        return value * 0.45359237;
      default:
        return null;
    }
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<bool> _ensureBluetoothEnabled() async {
    var adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState == BluetoothAdapterState.on) return true;

    try {
      await FlutterBluePlus.turnOn();
      await Future.delayed(const Duration(milliseconds: 500));
      adapterState = await FlutterBluePlus.adapterState.first;
    } catch (_) {}
    return adapterState == BluetoothAdapterState.on;
  }

  List<ScanResult> _discoverableDevices(List<ScanResult> results) {
    final devices = <String, ScanResult>{};
    for (final result in results) {
      devices[result.device.remoteId.toString()] = result;
    }
    return devices.values.toList();
  }

  bool _looksLikeScale(ScanResult result) {
    final name = _deviceName(result.device).toLowerCase();
    final hasScaleName =
        _scaleNamePatterns.any((pattern) => name.contains(pattern));
    final hasScaleService = result.advertisementData.serviceUuids.any(
      (uuid) => uuid.toString().toUpperCase().contains('FFE0'),
    );
    return hasScaleName || hasScaleService;
  }

  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    state = state.copyWith(isScanning: false);
  }

  void _startPeriodicCommunication() {
    _stopPeriodicCommunication();
    _communicationTimer = Timer.periodic(_commandInterval, (_) {
      unawaited(_sendCommand(_requestCommand));
    });
  }

  void _stopPeriodicCommunication() {
    _communicationTimer?.cancel();
    _communicationTimer = null;
  }

  void _reset({required bool clearDevice}) {
    _stopPeriodicCommunication();
    _incomingBuffer = '';
    state = state.copyWith(
      clearDevice: clearDevice,
      deviceName: clearDevice ? '' : state.deviceName,
      weight: clearDevice ? 0 : state.weight,
      uom: clearDevice ? 'kg' : state.uom,
      isConnecting: false,
      isStreaming: false,
      isStable: false,
      statusMessage: clearDevice ? 'Scale disconnected' : state.statusMessage,
    );
  }

  String _deviceName(BluetoothDevice device) {
    final advertisedName = device.advName.trim();
    final platformName = device.platformName.trim();
    if (advertisedName.isNotEmpty) return advertisedName;
    if (platformName.isNotEmpty) return platformName;
    return 'Unknown Scale';
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));

  @override
  void dispose() {
    _stopPeriodicCommunication();
    unawaited(_weightSubscription?.cancel() ?? Future<void>.value());
    unawaited(_scanSubscription?.cancel() ?? Future<void>.value());
    unawaited(_connectionSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}

class _ParsedScaleFrame {
  const _ParsedScaleFrame({
    required this.weight,
    required this.unit,
    required this.isStable,
  });

  final double weight;
  final String unit;
  final bool isStable;
}
