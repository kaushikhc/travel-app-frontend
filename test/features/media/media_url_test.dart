import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';
import 'package:travel_app_frontend/features/media/data/media_repository.dart';

class CountingMediaRepository extends MediaRepository {
  CountingMediaRepository() : super(ApiClient(baseUrl: 'https://api.example/api'));
  int calls = 0;

  @override
  Future<String?> fetchDownloadUrl(int mediaId) async {
    calls++;
    return 'https://cdn.example/$mediaId?v=$calls';
  }
}

void main() {
  test('a link is reused until shortly before it expires, then fetched again', () {
    fakeAsync((FakeAsync async) {
      final CountingMediaRepository repo = CountingMediaRepository();
      final ProviderContainer c = ProviderContainer(overrides: [mediaRepositoryProvider.overrideWithValue(repo)]);
      String? url;
      c.read(mediaUrlProvider(5).future).then((String? v) => url = v);
      async.flushMicrotasks();
      expect(url, 'https://cdn.example/5?v=1');

      async.elapse(const Duration(minutes: 30));
      c.read(mediaUrlProvider(5).future).then((String? v) => url = v);
      async.flushMicrotasks();
      expect(repo.calls, 1);

      async.elapse(mediaUrlReuse);
      c.read(mediaUrlProvider(5).future).then((String? v) => url = v);
      async.flushMicrotasks();
      expect(repo.calls, 2);
      expect(url, 'https://cdn.example/5?v=2');
      c.dispose();
    });
  });
}
