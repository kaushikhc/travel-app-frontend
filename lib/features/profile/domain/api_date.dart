/// Calendar dates without a time (birthday), sent to the API as `yyyy-MM-dd`.
abstract final class ApiDate {
  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses `yyyy-MM-dd` into a local date at midnight; null for anything else.
  static DateTime? parse(String? value) {
    final RegExpMatch? m = value == null ? null : _date.firstMatch(value.trim());
    if (m == null) return null;
    final DateTime date = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    // DateTime rolls 2020-02-30 over to March; treat that as invalid.
    return date.month == int.parse(m[2]!) ? date : null;
  }

  static String format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
