import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/time/api_time.dart';

void main() {
  test('offset-less API timestamps are read as UTC', () {
    final DateTime? t = ApiTime.parseUtc('2026-11-11T12:30:00');
    expect(t, DateTime.utc(2026, 11, 11, 12, 30));
    expect(t!.isUtc, isTrue);
  });

  test('timestamps with Z or an offset keep their instant', () {
    expect(ApiTime.parseUtc('2026-11-11T12:30:00Z'), DateTime.utc(2026, 11, 11, 12, 30));
    expect(ApiTime.parseUtc('2026-11-11T18:00:00+05:30'), DateTime.utc(2026, 11, 11, 12, 30));
    expect(ApiTime.parseUtc('2026-11-11T12:30:00.123456'), DateTime.utc(2026, 11, 11, 12, 30, 0, 123, 456));
  });

  test('empty or bad input gives null', () {
    expect(ApiTime.parseUtc(null), isNull);
    expect(ApiTime.parseUtc(''), isNull);
    expect(ApiTime.parseUtc('yesterday'), isNull);
  });

  test('formatting uses the device zone', () {
    final DateTime utc = DateTime.utc(2026, 11, 11, 12, 30);
    expect(ApiTime.formatDateTime(utc, locale: 'en_US'),
        ApiTime.formatDateTime(utc.toLocal(), locale: 'en_US'));
    expect(ApiTime.formatMonthYear(utc, locale: 'en_US'), contains('2026'));
  });
}
