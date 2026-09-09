import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';
import 'package:warehouse_app/features/moisture/domain/models/moisture_reading.dart';

class MoistureUsbDevice {
  final UsbDevice device;

  const MoistureUsbDevice(this.device);

  static const _knownSerialVendorIds = {
    1027, // FTDI
    1659, // Prolific PL2303
    4292, // Silicon Labs CP210x
    6790, // WCH CH34x
    9025, // Arduino-compatible CDC devices
  };

  String get name {
    final product = device.productName?.trim();
    if (product != null && product.isNotEmpty) return product;
    final manufacturer = device.manufacturerName?.trim();
    if (manufacturer != null && manufacturer.isNotEmpty) return manufacturer;
    return 'USB moisture meter';
  }

  bool get isLikelySerialDevice {
    final vendorId = device.vid;
    return vendorId != null && _knownSerialVendorIds.contains(vendorId);
  }

  String get description =>
      'Vendor ${device.vid ?? '-'} - Product ${device.pid ?? '-'}';
}

class MoistureMeterScanResult {
  final List<MoistureUsbDevice> devices;
  final int ignoredDeviceCount;

  const MoistureMeterScanResult({
    required this.devices,
    required this.ignoredDeviceCount,
  });
}

class LandtekMoistureMeterService {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _buffer = <int>[];
  final _readingController = StreamController<MoistureReading>.broadcast();
  final _logController = StreamController<String>.broadcast();

  Stream<MoistureReading> get readings => _readingController.stream;
  Stream<String> get logs => _logController.stream;
  bool get isConnected => _port != null;

  Future<MoistureMeterScanResult> scanDevices() async {
    _log('Scanning USB devices...');
    final usbDevices = await UsbSerial.listDevices();
    final devices = usbDevices.map(MoistureUsbDevice.new).toList();
    final serialDevices =
        devices.where((device) => device.isLikelySerialDevice).toList();

    _log(
      'USB scan found ${devices.length} device(s), '
      '${serialDevices.length} serial candidate(s).',
    );
    for (final device in devices) {
      _log(
        '${device.isLikelySerialDevice ? 'serial' : 'ignored'}: '
        '${device.name} (${device.description})',
      );
    }

    return MoistureMeterScanResult(
      devices: serialDevices,
      ignoredDeviceCount: devices.length - serialDevices.length,
    );
  }

  Future<void> connect(
    MoistureUsbDevice device, {
    int baudRate = 9600,
  }) async {
    _log(
      'Connecting to ${device.name} (${device.description}) '
      'at $baudRate baud...',
    );
    if (!device.isLikelySerialDevice) {
      throw Exception(
        'The selected USB device is not a serial moisture meter.',
      );
    }
    await disconnect();
    final port = await device.device.create();
    if (port == null) {
      _log('Failed to create USB serial port.');
      throw Exception('Could not open USB moisture meter.');
    }

    final opened = await port.open();
    if (opened != true) {
      _log('USB serial port open failed or permission was denied.');
      throw Exception('USB permission was not granted.');
    }

    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _port = port;
    final inputStream = port.inputStream;
    if (inputStream == null) {
      await disconnect();
      _log('Connected port has no input stream.');
      throw Exception('Could not listen for moisture meter data.');
    }

    _subscription = inputStream.listen(
      _handleBytes,
      onError: (Object error) => _log('Serial input error: $error'),
      cancelOnError: false,
    );
    _log(
      'Connected. Listening at $baudRate baud, 8 data bits, 1 stop bit, no parity.',
    );
  }

  Future<MoistureReading> readMeasurement({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_port == null) {
      throw Exception('Connect the moisture meter first.');
    }
    _log('Waiting for moisture packet for ${timeout.inSeconds}s...');
    return readings.first.timeout(
      timeout,
      onTimeout: () {
        _log('Timeout: no valid moisture packet received.');
        throw TimeoutException(
          'No moisture reading received. Press the meter read/send button and try again.',
        );
      },
    );
  }

  void _handleBytes(Uint8List data) {
    _log('Raw bytes (${data.length}): ${_hex(data)}');
    _buffer.addAll(data);
    while (_buffer.length >= 9) {
      final start = _buffer.indexOf(0x30);
      if (start < 0) {
        _log(
          'No packet header 0x30 found. Clearing ${_buffer.length} byte(s). '
          'If this repeats, try another baud rate.',
        );
        _buffer.clear();
        return;
      }
      if (start > 0) {
        _log('Discarding $start byte(s) before packet header.');
        _buffer.removeRange(0, start);
      }
      if (_buffer.length < 9) return;

      final packet = _buffer.take(9).toList();
      _buffer.removeRange(0, 9);
      _log('Candidate packet: ${_hex(packet)}');
      final reading = LandtekPacketParser.parse(packet);
      if (reading != null) {
        _log(
          'Parsed moisture ${reading.value}% '
          'with material ${_meterCodeLabel(reading.materialCode)}.',
        );
        _readingController.add(reading);
      } else {
        _log('Packet ignored: invalid header, checksum, or value format.');
      }
    }
  }

  Future<void> disconnect() async {
    if (_port != null || _subscription != null) {
      _log('Disconnecting moisture meter.');
    }
    await _subscription?.cancel();
    _subscription = null;
    final port = _port;
    _port = null;
    if (port != null) {
      await port.close();
    }
    _buffer.clear();
  }

  Future<void> dispose() async {
    await disconnect();
    await _readingController.close();
    await _logController.close();
  }

  void _log(String message) {
    final line = '${DateTime.now().toIso8601String()} $message';
    developer.log(line, name: 'moisture.meter');
    // ignore: avoid_print
    print('[moisture.meter] $line');
    if (!_logController.isClosed) {
      _logController.add(line);
    }
  }

  String _hex(Iterable<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  String _meterCodeLabel(int? value) {
    if (value == null) return 'unknown';
    return 'Cd${value.toRadixString(16).padLeft(2, '0')}';
  }
}

class LandtekPacketParser {
  static MoistureReading? parse(List<int> packet) {
    if (packet.length != 9 || packet.first != 0x30) return null;

    final expectedChecksum = packet
        .take(8)
        .fold<int>(0x08, (sum, value) => (sum + value) & 0xFF);
    if (expectedChecksum != packet[8]) return null;

    final rawDigits = packet
        .skip(2)
        .take(5)
        .map(_decodeDigit)
        .where((digit) => digit >= 0 && digit <= 9)
        .join();
    if (rawDigits.isEmpty) return null;

    final decimalPlaces = packet[7].clamp(0, 4).toInt();
    final rawValue = double.tryParse(rawDigits);
    if (rawValue == null) return null;

    final divisor = _pow10(decimalPlaces);
    return MoistureReading(
      value: rawValue / divisor,
      materialCode: packet[1],
      measuredAt: DateTime.now(),
    );
  }

  static int _decodeDigit(int value) {
    if (value >= 0x30 && value <= 0x39) return value - 0x30;
    return value & 0x0F;
  }

  static double _pow10(int value) {
    var result = 1.0;
    for (var i = 0; i < value; i++) {
      result *= 10;
    }
    return result;
  }
}
