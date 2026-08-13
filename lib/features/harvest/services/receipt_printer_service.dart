import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/l10n/app_localizations.dart';

class ThermalPrinterDevice {
  final String name;
  final String address;

  const ThermalPrinterDevice({
    required this.name,
    required this.address,
  });

  factory ThermalPrinterDevice.fromMap(Map<dynamic, dynamic> map) {
    return ThermalPrinterDevice(
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Bluetooth Printer',
      address: map['address'] as String,
    );
  }
}

class ReceiptPrinterException implements Exception {
  final String message;

  const ReceiptPrinterException(this.message);

  @override
  String toString() => message;
}

class ReceiptPrinterService {
  static const _channel =
      MethodChannel('warehouse_app.bluetooth.print.receipt');
  static const _paperWidth = 32;

  Future<void> ensureBluetoothPermission(String permissionMessage) async {
    if (!Platform.isAndroid) return;

    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final denied = statuses.values.any((status) => !status.isGranted);
    if (denied) {
      throw ReceiptPrinterException(permissionMessage);
    }
  }

  Future<ThermalPrinterDevice> pickPrinter() async {
    try {
      final device = await _channel.invokeMapMethod<dynamic, dynamic>(
        'pickPrinter',
      );
      if (device == null) {
        throw const ReceiptPrinterException('No printer was selected.');
      }
      return ThermalPrinterDevice.fromMap(device);
    } on PlatformException catch (error) {
      throw ReceiptPrinterException(
        error.message ?? 'Could not select a printer.',
      );
    }
  }

  Future<List<ThermalPrinterDevice>> scanPrinters() async {
    try {
      final devices = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'scanPrinters',
      );
      return (devices ?? const <Map<dynamic, dynamic>>[])
          .map(ThermalPrinterDevice.fromMap)
          .toList();
    } on PlatformException catch (error) {
      throw ReceiptPrinterException(
        error.message ?? 'Could not scan printers.',
      );
    }
  }

  Future<List<ThermalPrinterDevice>> pairedPrinters() async {
    try {
      final devices = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'getPairedPrinters',
      );
      return (devices ?? const <Map<dynamic, dynamic>>[])
          .map(ThermalPrinterDevice.fromMap)
          .toList();
    } on PlatformException catch (error) {
      throw ReceiptPrinterException(
        error.message ?? 'Could not load paired printers.',
      );
    }
  }

  Future<void> printHarvestReceipt({
    required ThermalPrinterDevice printer,
    required FarmerHarvest harvest,
    required List<FarmerHarvestBag> bags,
    required AppLocalizations l10n,
    required bool includeBagDetails,
  }) async {
    final bytes = buildHarvestReceiptBytes(
      harvest: harvest,
      bags: bags,
      l10n: l10n,
      includeBagDetails: includeBagDetails,
    );

    try {
      await _channel.invokeMethod<void>('printReceipt', {
        'address': printer.address,
        'data': bytes,
      });
    } on PlatformException catch (error) {
      throw ReceiptPrinterException(
          error.message ?? 'Could not print receipt.');
    }
  }

  Uint8List buildHarvestReceiptBytes({
    required FarmerHarvest harvest,
    required List<FarmerHarvestBag> bags,
    required AppLocalizations l10n,
    required bool includeBagDetails,
  }) {
    final builder = BytesBuilder();
    void bytes(List<int> value) => builder.add(value);
    void text(String value) => builder.add(latin1.encode(_sanitize(value)));
    void line([String value = '']) => text('$value\n');
    void center(String value) => line(_center(value));

    final receivedDate = DateFormat('dd/MM/yyyy').format(harvest.receivedAt);
    final receivedTime = DateFormat('HH:mm:ss').format(harvest.receivedAt);
    final printedAt = DateTime.now();
    final printDate = DateFormat('dd/MM/yyyy').format(printedAt);
    final printTime = DateFormat('HH:mm:ss').format(printedAt);
    final unit = harvest.uomName ?? 'Kg';

    bytes([0x1B, 0x40]);
    bytes([0x1B, 0x61, 0x01]);
    bytes([0x1B, 0x45, 0x01]);
    center('*** ${l10n.harvestRequestReceipt.toUpperCase()} ***');
    bytes([0x1B, 0x45, 0x00]);
    line('=' * _paperWidth);

    bytes([0x1B, 0x61, 0x00]);
    _row(line, l10n.receiptFarmer, harvest.farmerName);
    _row(line, l10n.receiptPhone, harvest.farmerPhoneNumber);
    _row(line, l10n.receiptCenter, harvest.collectionCenterName);
    if (harvest.receivedByName != null) {
      _row(line, l10n.receiptReceivedBy, harvest.receivedByName!);
    }
    _row(line, l10n.receiptCrop, harvest.cropName);
    _row(line, l10n.receiptGross, '${_weight(harvest.grossWeight)} $unit');
    _row(line, l10n.receiptNet, '${_weight(harvest.netWeight)} $unit');
    _row(line, l10n.receiptPackaging, harvest.packaging);
    line(_divider());
    center('${l10n.receiptTotalBags} (${bags.length})');
    line(_divider());

    if (includeBagDetails && bags.isNotEmpty) {
      for (final bag in bags) {
        _row(line, l10n.receiptTagNumber, bag.tag);
        _row(line, l10n.receiptGross, '${_weight(bag.grossWeight)} $unit');
        _row(line, l10n.receiptNet, '${_weight(bag.netWeight)} $unit');
        _row(line, l10n.receiptMoisturePercent,
            '${_weight(bag.moistureContent)} %');
        _row(
          line,
          l10n.receiptPackagingWeight,
          '${_weight(bag.packagingWeight)} $unit',
        );
        line(_divider());
      }
    } else {
      center(
        bags.isEmpty
            ? l10n.receiptNoBagsFound
            : l10n.receiptBagDetailsNotPrinted,
      );
      line(_divider());
    }

    line('${l10n.receiptNumber} ${harvest.receiptNumber}');
    _row(line, l10n.receiptReceivedDate, receivedDate);
    _row(line, l10n.receiptReceivedTime, receivedTime);
    _row(line, l10n.receiptPrintDate, printDate);
    _row(line, l10n.receiptPrintTime, printTime);
    line(_divider());
    bytes([0x1B, 0x61, 0x01]);
    center('*** ${l10n.receiptEnd.toUpperCase()} ***');
    line('=' * _paperWidth);
    line('');
    line('');
    center(l10n.poweredByShambabora.toUpperCase());
    line('=' * _paperWidth);
    line('');
    line('');
    line('');
    return builder.toBytes();
  }

  void _row(void Function(String) line, String label, String value) {
    final left = label.length > 14 ? label.substring(0, 14) : label;
    final rightWidth = _paperWidth - left.length - 1;
    final right =
        value.length > rightWidth ? value.substring(0, rightWidth) : value;
    final spaces = _paperWidth - left.length - right.length;
    line('$left${' ' * spaces}$right');
  }

  String _center(String value) {
    if (value.length >= _paperWidth) return value.substring(0, _paperWidth);
    final leftPadding = ((_paperWidth - value.length) / 2).floor();
    return '${' ' * leftPadding}$value';
  }

  String _divider() => '-' * _paperWidth;

  String _weight(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    return value.toStringAsFixed(2);
  }

  String _sanitize(String value) {
    return value.replaceAll(RegExp(r'[^\x00-\x7F]'), ' ');
  }
}
