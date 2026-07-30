import 'package:warehouse_app/core/database/app_database.dart';

class FarmerDependantInput {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String relationship;
  final String gender;
  final String? email;
  final String? address;
  final String? phoneNumber;
  final String dob;

  const FarmerDependantInput({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.relationship,
    required this.gender,
    this.email,
    this.address,
    this.phoneNumber,
    required this.dob,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      if (_hasValue(middleName)) 'middleName': middleName!.trim(),
      'lastName': lastName,
      'relationship': relationship,
      'gender': gender,
      if (_hasValue(email)) 'email': email!.trim(),
      if (_hasValue(address)) 'address': address!.trim(),
      if (_hasValue(phoneNumber)) 'phoneNumber': phoneNumber!.trim(),
      'dob': dob,
    };
  }

  static bool _hasValue(String? value) => value?.trim().isNotEmpty ?? false;
}

class FarmerDependantModel {
  final int id;
  final int farmerId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String relationship;
  final String dob;
  final String gender;
  final String? phoneNumber;
  final String? address;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FarmerDependantModel({
    required this.id,
    required this.farmerId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.relationship,
    required this.dob,
    required this.gender,
    this.phoneNumber,
    this.address,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory FarmerDependantModel.fromJson(
    Map<String, dynamic> json, {
    int? fallbackFarmerId,
  }) {
    return FarmerDependantModel(
      id: _int(json['id']),
      farmerId: _int(json['farmerId'] ?? fallbackFarmerId),
      firstName: _string(json['firstName']),
      middleName: _nullableString(json['middleName']),
      lastName: _string(json['lastName']),
      relationship: _string(json['relationship']),
      dob: _string(json['dob']),
      gender: _string(json['gender']),
      phoneNumber: _nullableString(json['phoneNumber']),
      address: _nullableString(json['address']),
      email: _nullableString(json['email']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  FarmerDependantsCompanion toCompanion() {
    return FarmerDependantsCompanion.insert(
      id: Value(id),
      farmerId: farmerId,
      firstName: firstName,
      middleName: Value(middleName),
      lastName: lastName,
      relationship: relationship,
      dob: dob,
      gender: gender,
      phoneNumber: Value(phoneNumber),
      address: Value(address),
      email: Value(email),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
