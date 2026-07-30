import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_app/features/owner/screens/warehouse_list_screen.dart';

void main() {
  group('buildWarehouseGpsLocation', () {
    test('builds a full address from selected location values', () {
      final address = buildWarehouseGpsLocation(
        regionName: 'Dar es Salaam',
        districtName: 'Temeke',
        wardName: 'Miburani',
        villageName: 'Mwananyamala',
      );

      expect(address, 'Dar es Salaam, Temeke, Miburani, Mwananyamala');
    });

    test('ignores empty values and keeps the meaningful parts', () {
      final address = buildWarehouseGpsLocation(
        regionName: '',
        districtName: 'Ilala',
        wardName: null,
        villageName: 'Mchichani',
      );

      expect(address, 'Ilala, Mchichani');
    });
  });
}
