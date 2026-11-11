import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';

/// The API stores and returns every timestamp in UTC, often without an offset
/// (e.g. `2026-11-11T12:00:00`). Parse with these helpers, never `DateTime.parse` directly,
/// which would read an offset-less value as device-local time.
abstract final class ApiTime {
  static final RegExp _hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  /// Parses an API timestamp as UTC. Returns null for null or unparseable input.
  static DateTime? parseUtc(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final String text = value.trim();
    return DateTime.tryParse(_hasOffset.hasMatch(text) ? text : '${text}Z')?.toUtc();
  }

  /// Date in the device's time zone and locale, e.g. "11 Nov 2026".
  static String formatDate(DateTime utc, {String? locale}) =>
      DateFormat.yMMMd(locale).format(utc.toLocal());

  /// Date and time in the device's time zone and locale.
  static String formatDateTime(DateTime utc, {String? locale}) =>
      DateFormat.yMMMd(locale).add_jm().format(utc.toLocal());

  /// Month and year in the device's time zone, e.g. "November 2026".
  static String formatMonthYear(DateTime utc, {String? locale}) =>
      DateFormat.yMMMM(locale).format(utc.toLocal());
}

/// The device's IANA time zone (e.g. `Asia/Kolkata`), sent to the profile so trip dates roll
/// over at the traveler's local midnight.
abstract class DeviceTimeZone {
  Future<String?> current();
}

class PlatformDeviceTimeZone implements DeviceTimeZone {
  const PlatformDeviceTimeZone();

  @override
  Future<String?> current() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return null;
    }
  }
}

final deviceTimeZoneProvider = Provider<DeviceTimeZone>((Ref ref) => const PlatformDeviceTimeZone());
