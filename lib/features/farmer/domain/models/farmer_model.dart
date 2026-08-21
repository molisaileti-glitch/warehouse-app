import 'package:warehouse_app/core/database/app_database.dart';

class FarmerCreateInput {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String sex;
  final String idType;
  final String idNumber;
  final String dob;
  final String phoneNumber;
  final String? tumeNumber;
  final String? amcosMemberID;
  final int mainCrop;
  final int secondaryCrop;
  final int amcos;
  final int mcu;
  final String memberType;
  final String? ttbNumber;
  final String? tinNumber;
  final String? voterId;
  final String? driversLicense;
  final String maritalStatus;
  final double? noOfShares;

  const FarmerCreateInput({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.sex,
    required this.idType,
    required this.idNumber,
    required this.dob,
    required this.phoneNumber,
    this.tumeNumber,
    this.amcosMemberID,
    required this.mainCrop,
    required this.secondaryCrop,
    required this.amcos,
    required this.mcu,
    required this.memberType,
    this.ttbNumber,
    this.tinNumber,
    this.voterId,
    this.driversLicense,
    required this.maritalStatus,
    this.noOfShares,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      if (_hasValue(middleName)) 'middleName': middleName!.trim(),
      'lastName': lastName,
      'sex': sex,
      'idType': idType,
      'idNumber': idNumber,
      'dob': dob,
      'phoneNumber': phoneNumber,
      if (_hasValue(tumeNumber)) 'tumeNumber': tumeNumber!.trim(),
      if (_hasValue(amcosMemberID)) 'amcosMemberID': amcosMemberID!.trim(),
      'mainCrop': mainCrop,
      'secondaryCrop': secondaryCrop,
      'status': 'ACTIVE',
      'amcos': amcos,
      'mcu': mcu,
      'educationLevel': 'PRIMARY',
      'memberType': memberType,
      if (_hasValue(ttbNumber)) 'ttbNumber': ttbNumber!.trim(),
      if (_hasValue(tinNumber)) 'tinNumber': tinNumber!.trim(),
      if (_hasValue(voterId)) 'voterId': voterId!.trim(),
      if (_hasValue(driversLicense)) 'driversLicense': driversLicense!.trim(),
      'maritalStatus': maritalStatus,
      if (noOfShares != null) 'noOfShares': noOfShares,
    };
  }

  static bool _hasValue(String? value) => value?.trim().isNotEmpty ?? false;
}

class FarmerModel {
  final int id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String sex;
  final String idType;
  final String idNumber;
  final String dob;
  final String phoneNumber;
  final String? tumeNumber;
  final String? amcosMemberID;
  final int mainCrop;
  final int secondaryCrop;
  final String status;
  final int amcos;
  final String? amcosName;
  final int mcu;
  final String? mcuName;
  final String educationLevel;
  final String memberType;
  final String? ttbNumber;
  final String? tinNumber;
  final String? voterId;
  final String? driversLicense;
  final bool fingerprintCaptured;
  final String? uuid;
  final String maritalStatus;
  final double? noOfShares;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FarmerModel({
    required this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.sex,
    required this.idType,
    required this.idNumber,
    required this.dob,
    required this.phoneNumber,
    this.tumeNumber,
    this.amcosMemberID,
    required this.mainCrop,
    required this.secondaryCrop,
    required this.status,
    required this.amcos,
    this.amcosName,
    required this.mcu,
    this.mcuName,
    required this.educationLevel,
    required this.memberType,
    this.ttbNumber,
    this.tinNumber,
    this.voterId,
    this.driversLicense,
    required this.fingerprintCaptured,
    this.uuid,
    required this.maritalStatus,
    this.noOfShares,
    this.createdAt,
    this.updatedAt,
  });

  factory FarmerModel.fromJson(Map<String, dynamic> json) {
    return FarmerModel(
      id: _int(json['id']),
      firstName: _string(json['firstName']),
      middleName: _nullableString(json['middleName']),
      lastName: _string(json['lastName']),
      sex: _string(json['sex']),
      idType: _string(json['idType']),
      idNumber: _string(json['idNumber']),
      dob: _string(json['dob']),
      phoneNumber: _string(json['phoneNumber']),
      tumeNumber: _nullableString(json['tumeNumber']),
      amcosMemberID: _nullableString(json['amcosMemberID']),
      mainCrop: _int(json['mainCrop']),
      secondaryCrop: _int(json['secondaryCrop']),
      status: _string(json['status'], fallback: 'ACTIVE'),
      amcos: _int(json['amcos']),
      amcosName: _nullableString(json['amcosName']),
      mcu: _int(json['mcu']),
      mcuName: _nullableString(json['mcuName']),
      educationLevel: _string(json['educationLevel'], fallback: 'PRIMARY'),
      memberType: _string(json['memberType']),
      ttbNumber: _nullableString(json['ttbNumber']),
      tinNumber: _nullableString(json['tinNumber']),
      voterId: _nullableString(json['voterId']),
      driversLicense: _nullableString(json['driversLicense']),
      fingerprintCaptured: _bool(json['fingerprintCaptured']),
      uuid: _nullableString(json['uuid']),
      maritalStatus: _string(json['maritalStatus'], fallback: 'SINGLE'),
      noOfShares: _double(json['noOfShares']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  FarmersCompanion toCompanion({
    int? localId,
    int? serverId,
    String? uuidOverride,
  }) {
    return FarmersCompanion.insert(
      id: Value(localId ?? id),
      serverId: Value(serverId),
      firstName: firstName,
      middleName: Value(middleName),
      lastName: lastName,
      sex: sex,
      idType: idType,
      idNumber: idNumber,
      dob: dob,
      phoneNumber: phoneNumber,
      tumeNumber: Value(tumeNumber),
      amcosMemberID: Value(amcosMemberID),
      mainCrop: mainCrop,
      secondaryCrop: secondaryCrop,
      status: Value(status),
      amcos: amcos,
      amcosName: Value(amcosName),
      mcu: mcu,
      mcuName: Value(mcuName),
      educationLevel: Value(educationLevel),
      memberType: memberType,
      ttbNumber: Value(ttbNumber),
      tinNumber: Value(tinNumber),
      voterId: Value(voterId),
      driversLicense: Value(driversLicense),
      fingerprintCaptured: Value(fingerprintCaptured),
      uuid: Value(uuidOverride ?? uuid),
      maritalStatus: maritalStatus,
      noOfShares: Value(noOfShares),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _double(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
