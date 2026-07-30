import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_app/features/auth/screens/register_screen.dart';

void main() {
  group('parseRegionsPayload', () {
    test('parses a direct list payload', () {
      final regions = parseRegionsPayload([
        {'id': 1, 'name': 'DAR ES SALAAM', 'postCode': '111'},
      ]);

      expect(regions, hasLength(1));
      expect(regions.first.name, 'DAR ES SALAAM');
    });

    test('parses a wrapped data payload', () {
      final regions = parseRegionsPayload({
        'data': [
          {'id': 2, 'name': 'MOROGORO', 'postCode': '671'},
        ],
      });

      expect(regions, hasLength(1));
      expect(regions.first.name, 'MOROGORO');
    });
  });
}
