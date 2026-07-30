import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:warehouse_app/core/database/app_database.dart';
import 'package:warehouse_app/core/database/database_provider.dart';
import 'package:warehouse_app/core/network/api_client.dart';
import 'package:warehouse_app/features/additional.data/crop/data/repositories/crop_repository.dart';

final cropRepositoryProvider = Provider<CropRepository>((ref) {
  return CropRepository(
    dio: ref.watch(apiClientProvider).dio,
    dao: ref.watch(cropDaoProvider),
  );
});

final allCropsProvider = StreamProvider<List<Crop>>((ref) {
  return ref
      .watch(cropDaoProvider)
      .watchAllCropsWithGradeCounts()
      .map(_deduplicateCrops);
});

String _normalizeCropName(String value) {
  final text = value.trim();
  return switch (text.toLowerCase()) {
    'potato' => 'POTATO',
    'rice' => 'RICE',
    _ => text,
  };
}

List<Crop> _deduplicateCrops(List<CropWithGradeCount> crops) {
  final cropsByName = <String, CropWithGradeCount>{};

  for (final option in crops) {
    final normalizedName = _normalizeCropName(option.crop.name);
    final key = normalizedName.toLowerCase();
    final normalizedOption = CropWithGradeCount(
      crop: option.crop.copyWith(name: normalizedName),
      gradeCount: option.gradeCount,
    );
    final existingOption = cropsByName[key];

    if (existingOption == null ||
        _shouldPreferCrop(normalizedOption, existingOption)) {
      cropsByName[key] = normalizedOption;
    }
  }

  return cropsByName.values.map((option) => option.crop).toList()
    ..sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
}

bool _shouldPreferCrop(
  CropWithGradeCount candidate,
  CropWithGradeCount existing,
) {
  final candidateHasGrades = candidate.gradeCount > 0;
  final existingHasGrades = existing.gradeCount > 0;

  if (candidateHasGrades != existingHasGrades) {
    return candidateHasGrades;
  }

  return candidate.crop.id < existing.crop.id;
}
