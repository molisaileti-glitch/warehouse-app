import 'package:flutter/services.dart';

class ReportFileActionService {
  const ReportFileActionService();

  static const _channel = MethodChannel('warehouse_app.platform/files');
  static const excelMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  Future<void> openExcel(String path) {
    return _channel.invokeMethod<void>('openFile', {
      'path': path,
      'mimeType': excelMimeType,
    });
  }

  Future<void> shareExcel(String path, String fileName) {
    return _channel.invokeMethod<void>('shareFile', {
      'path': path,
      'fileName': fileName,
      'mimeType': excelMimeType,
    });
  }

  Future<bool> saveExcelAs(String path, String fileName) async {
    final result = await _channel.invokeMethod<bool>('saveFileAs', {
      'path': path,
      'fileName': fileName,
      'mimeType': excelMimeType,
    });
    return result ?? false;
  }
}
