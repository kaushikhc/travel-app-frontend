import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/memories/data/memory_repository.dart';
import 'package:travel_app_frontend/features/memories/domain/memory_model.dart';

void main() {
  test('create body carries the tagged place', () {
    final Map<String, dynamic> body = MemoryRepository.createBody(
      tripId: 3,
      placeId: 9,
      visibility: MemoryVisibility.private,
      tags: const <String>[],
      mediaIds: const <int>[],
    );
    expect(body['placeId'], 9);
  });

  test('update body sends placeId only when the place changed', () {
    Map<String, dynamic> body({bool changed = false, int? placeId}) => MemoryRepository.updateBody(
          title: 't',
          note: '',
          visibility: MemoryVisibility.private,
          tags: const <String>[],
          mediaIds: const <int>[],
          placeChanged: changed,
          placeId: placeId,
        );
    expect(body().containsKey('placeId'), isFalse);
    expect(body(changed: true, placeId: 4)['placeId'], 4);
    expect(body(changed: true).containsKey('placeId'), isTrue); // null clears the place
    expect(body(changed: true)['placeId'], isNull);
  });
}
