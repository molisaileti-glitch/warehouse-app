class WorkerModel {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final int mcu;
  final int amcos;
  final String? warehouseId;
  final String role;

  const WorkerModel({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.mcu,
    required this.amcos,
    this.warehouseId,
    this.role = 'AMCOS_USER',
  });

  Map<String, dynamic> toJson() {
    final collectionCenter = int.tryParse(warehouseId ?? '');
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'password': password,
      'role': role,
      'mcu': mcu,
      'amcos': amcos,
      if (warehouseId != null) 'warehouseId': warehouseId,
      if (collectionCenter != null) 'collectionCenterId': collectionCenter,
      if (collectionCenter != null) 'collectionCenter': collectionCenter,
    };
  }
}
