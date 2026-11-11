import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Day, month and year dropdowns. [onChanged] gets a date once all three are picked, and
/// null while any is missing. Days follow the chosen month and year (no 30 February), and
/// future dates can't be picked.
class BirthdayPicker extends StatefulWidget {
  const BirthdayPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.today,
    this.decoration,
    this.style,
    this.dropdownColor,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  /// For tests; defaults to the device's date.
  final DateTime? today;

  /// Wraps each dropdown's label; lets dark screens style the fields.
  final InputDecoration Function(String label)? decoration;
  final TextStyle? style;
  final Color? dropdownColor;

  static const int oldestYears = 120;

  @override
  State<BirthdayPicker> createState() => _BirthdayPickerState();
}

class _BirthdayPickerState extends State<BirthdayPicker> {
  int? _day;
  int? _month;
  int? _year;

  @override
  void initState() {
    super.initState();
    _take(widget.value);
  }

  @override
  void didUpdateWidget(BirthdayPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _current) _take(widget.value);
  }

  void _take(DateTime? date) {
    _day = date?.day;
    _month = date?.month;
    _year = date?.year;
  }

  DateTime get _today {
    final DateTime now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? get _current => (_day == null || _month == null || _year == null) ? null : DateTime(_year!, _month!, _day!);

  static int daysIn(int? month, int? year) {
    if (month == null) return 31;
    // Day 0 of the next month is the last day of this one; a leap year is assumed until one is picked.
    return DateTime(year ?? 2000, month + 1, 0).day;
  }

  int get _maxDay {
    int max = daysIn(_month, _year);
    if (_year == _today.year && _month == _today.month) max = _today.day;
    return max;
  }

  int get _maxMonth => _year == _today.year ? _today.month : 12;

  void _changed({int? day, int? month, int? year}) {
    setState(() {
      _day = day ?? _day;
      _month = month ?? _month;
      _year = year ?? _year;
      if (_month != null && _month! > _maxMonth) _month = null;
      if (_day != null && _day! > _maxDay) _day = null;
    });
    widget.onChanged(_current);
  }

  InputDecoration _decoration(String label) =>
      widget.decoration?.call(label) ??
      InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final List<String> monthNames = DateFormat.MMM().dateSymbols.SHORTMONTHS;
    final int thisYear = _today.year;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            // Keyed on the value so a cleared day (e.g. 31 after picking February) resets the field.
            key: ValueKey<String>('birthday-day:$_day:$_maxDay'),
            initialValue: _day,
            isExpanded: true,
            style: widget.style,
            dropdownColor: widget.dropdownColor,
            decoration: _decoration('Day'),
            items: <DropdownMenuItem<int>>[
              for (int d = 1; d <= _maxDay; d++) DropdownMenuItem<int>(value: d, child: Text('$d')),
            ],
            onChanged: (int? d) => _changed(day: d),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<int>(
            key: ValueKey<String>('birthday-month:$_month:$_maxMonth'),
            initialValue: _month,
            isExpanded: true,
            style: widget.style,
            dropdownColor: widget.dropdownColor,
            decoration: _decoration('Month'),
            items: <DropdownMenuItem<int>>[
              for (int m = 1; m <= _maxMonth; m++) DropdownMenuItem<int>(value: m, child: Text(monthNames[m - 1])),
            ],
            onChanged: (int? m) => _changed(month: m),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<int>(
            key: ValueKey<String>('birthday-year:$_year'),
            initialValue: _year,
            isExpanded: true,
            style: widget.style,
            dropdownColor: widget.dropdownColor,
            decoration: _decoration('Year'),
            items: <DropdownMenuItem<int>>[
              for (int y = thisYear; y >= thisYear - BirthdayPicker.oldestYears; y--)
                DropdownMenuItem<int>(value: y, child: Text('$y')),
            ],
            onChanged: (int? y) => _changed(year: y),
          ),
        ),
      ],
    );
  }
}
