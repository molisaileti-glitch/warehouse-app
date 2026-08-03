import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/features/harvest/domain/models/harvest_model.dart';

final harvestReceivingControllerProvider = StateNotifierProvider.family<
    HarvestReceivingController, HarvestReceivingState, String>(
  (ref, warehouseId) => HarvestReceivingController(),
);

class HarvestReceivingState {
  final int? farmerId;
  final int? cropId;
  final int? cropGradeId;
  final int? uomId;
  final String packaging;
  final List<HarvestBagInput> bags;
  final FarmerHarvest? savedHarvest;
  final int savedBagCount;

  const HarvestReceivingState({
    this.farmerId,
    this.cropId,
    this.cropGradeId,
    this.uomId,
    this.packaging = 'BAGS',
    this.bags = const [],
    this.savedHarvest,
    this.savedBagCount = 0,
  });

  bool get hasDetails => farmerId != null && cropId != null;
  bool get hasReceipt => savedHarvest != null;

  HarvestReceivingState copyWith({
    int? farmerId,
    int? cropId,
    int? cropGradeId,
    int? uomId,
    String? packaging,
    List<HarvestBagInput>? bags,
    FarmerHarvest? savedHarvest,
    int? savedBagCount,
    bool clearCropGrade = false,
    bool clearReceipt = false,
  }) {
    return HarvestReceivingState(
      farmerId: farmerId ?? this.farmerId,
      cropId: cropId ?? this.cropId,
      cropGradeId: clearCropGrade ? null : cropGradeId ?? this.cropGradeId,
      uomId: uomId ?? this.uomId,
      packaging: packaging ?? this.packaging,
      bags: bags ?? this.bags,
      savedHarvest: clearReceipt ? null : savedHarvest ?? this.savedHarvest,
      savedBagCount: savedBagCount ?? this.savedBagCount,
    );
  }
}

class HarvestReceivingController extends StateNotifier<HarvestReceivingState> {
  HarvestReceivingController() : super(const HarvestReceivingState());

  void setDetails({
    required int farmerId,
    required int cropId,
    int? uomId,
    int? cropGradeId,
    required String packaging,
  }) {
    final detailsChanged = state.farmerId != farmerId ||
        state.cropId != cropId ||
        state.cropGradeId != cropGradeId ||
        state.uomId != uomId ||
        state.packaging != packaging;

    state = state.copyWith(
      farmerId: farmerId,
      cropId: cropId,
      cropGradeId: cropGradeId,
      uomId: uomId,
      packaging: packaging,
      bags: detailsChanged ? const [] : state.bags,
      clearCropGrade: cropGradeId == null,
      clearReceipt: true,
    );
  }

  void addBag(HarvestBagInput bag) {
    state = state.copyWith(
      bags: [...state.bags, bag],
      clearReceipt: true,
    );
  }

  void removeBag(int index) {
    if (index < 0 || index >= state.bags.length) return;
    final next = [...state.bags]..removeAt(index);
    state = state.copyWith(bags: next, clearReceipt: true);
  }

  void markSaved(FarmerHarvest harvest) {
    state = state.copyWith(
      savedHarvest: harvest,
      savedBagCount: state.bags.length,
      bags: const [],
    );
  }

  void reset() {
    state = const HarvestReceivingState();
  }
}
