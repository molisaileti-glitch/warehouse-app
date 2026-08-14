import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_app/features/warehouse/domain/models/warehouse_model.dart';

void main() {
  group('WarehouseModel', () {
    test('parses API payload into the new domain shape', () {
      final model = WarehouseModel.fromJson({
        'id': 1,
        'uuid': 'warehouse-uuid-1',
        'name': 'Kuhic - Powlowski',
        'mcu': 2,
        'gpsLocation': '-157.7205',
        'amcos': 2,
        'amcosName': 'Tremblay - Powlowski',
        'village': 1,
        'villageName': 'Borer Station',
        'synced': true,
        'syncAction': 'created',
        'createdAt': '2026-07-14T10:00:00.000Z',
      });

      expect(model.uuid, 'warehouse-uuid-1');
      expect(model.id, '1');
      expect(model.name, 'Kuhic - Powlowski');
      expect(model.ownerId, '2');
      expect(model.gpsLocation, '-157.7205');
      expect(model.amcos, 2);
      expect(model.amcosName, 'Tremblay - Powlowski');
      expect(model.village, 1);
      expect(model.villageName, 'Borer Station');
      expect(model.synced, isTrue);
      expect(model.syncAction, 'created');
      expect(model.createdAt, isNotNull);
    });

    test('serializes back to JSON with uuid and numeric id', () {
      final model = WarehouseModel(
        uuid: 'warehouse-uuid-2',
        id: '2',
        name: 'A warehouse',
        ownerId: '2',
        gpsLocation: '-10.12',
        amcos: 3,
        amcosName: 'AMCOS One',
        village: 4,
        villageName: 'Village One',
        synced: true,
        syncAction: 'created',
        createdAt: DateTime.utc(2026, 7, 14, 10, 0),
      );

      final json = model.toJson();

      expect(json['uuid'], 'warehouse-uuid-2');
      expect(json['id'], 2);
      expect(json['name'], 'A warehouse');
      expect(json['mcu'], 2);
      expect(json['gpsLocation'], '-10.12');
    });

    test('builds sync payload without local-only sync metadata', () {
      const model = WarehouseModel(
        uuid: 'warehouse-uuid-3',
        id: '3',
        name: 'Sync me',
        ownerId: '2',
        gpsLocation: '-5.5',
        synced: true,
        syncAction: 'updated',
      );

      final payload = model.toSyncPayload();

      expect(payload['uuid'], 'warehouse-uuid-3');
      expect(payload['name'], 'Sync me');
      expect(payload['mcu'], 2);
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('synced'), isFalse);
      expect(payload.containsKey('syncAction'), isFalse);
    });

    test('builds a sync payload without sync metadata or id', () {
      const model = WarehouseModel(
        uuid: 'warehouse-uuid-2',
        id: '2',
        name: 'A warehouse',
        gpsLocation: '-10.12',
      );

      final payload = model.toSyncPayload();

      expect(payload['uuid'], 'warehouse-uuid-2');
      expect(payload['name'], 'A warehouse');
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('synced'), isFalse);
      expect(payload.containsKey('syncAction'), isFalse);
    });
  });
}
