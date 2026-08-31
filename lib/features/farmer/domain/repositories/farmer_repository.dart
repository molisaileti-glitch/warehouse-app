import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_dependant_model.dart';
import 'package:warehouse_app/features/farmer/domain/models/farmer_model.dart';

abstract class FarmerRepository {
  Stream<List<Farmer>> watchAllFarmers();
  Stream<Farmer?> watchFarmerById(int id);
  Stream<List<FarmerDependant>> watchDependantsForFarmer(int farmerId);
  Future<int> pullFromServer({required Set<int> amcosIds});
  Future<int> pullDependantsForFarmers(List<Farmer> farmers);

  Future<FarmerCreateResult> createFarmer({
    required FarmerCreateInput farmer,
    List<FarmerDependantInput> dependants = const [],
  });

  Future<FarmerDependantCreateResult> addDependant({
    required int farmerId,
    required FarmerDependantInput dependant,
  });
}

class FarmerCreateResult {
  final bool success;
  final Farmer? farmer;
  final String? error;
  final int createdDependants;
  final List<String> dependantErrors;

  const FarmerCreateResult._({
    required this.success,
    this.farmer,
    this.error,
    this.createdDependants = 0,
    this.dependantErrors = const [],
  });

  factory FarmerCreateResult.success({
    required Farmer farmer,
    int createdDependants = 0,
    List<String> dependantErrors = const [],
  }) {
    return FarmerCreateResult._(
      success: true,
      farmer: farmer,
      createdDependants: createdDependants,
      dependantErrors: dependantErrors,
    );
  }

  factory FarmerCreateResult.failure(String error) {
    return FarmerCreateResult._(success: false, error: error);
  }
}

class FarmerDependantCreateResult {
  final bool success;
  final FarmerDependant? dependant;
  final String? error;

  const FarmerDependantCreateResult._({
    required this.success,
    this.dependant,
    this.error,
  });

  factory FarmerDependantCreateResult.success([FarmerDependant? dependant]) {
    return FarmerDependantCreateResult._(
      success: true,
      dependant: dependant,
    );
  }

  factory FarmerDependantCreateResult.failure(String error) {
    return FarmerDependantCreateResult._(success: false, error: error);
  }
}
