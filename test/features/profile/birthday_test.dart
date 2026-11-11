import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/profile/data/profile_repository.dart';
import 'package:travel_app_frontend/features/profile/domain/api_date.dart';
import 'package:travel_app_frontend/features/profile/domain/profile_model.dart';
import 'package:travel_app_frontend/features/profile/presentation/widgets/birthday_picker.dart';

Future<void> pick(WidgetTester tester, String fieldPrefix, String item) async {
  await tester.tap(
    find.byWidgetPredicate(
      (Widget w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(fieldPrefix),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  test('ApiDate reads and writes yyyy-MM-dd and rejects impossible dates', () {
    expect(ApiDate.parse('1990-04-23'), DateTime(1990, 4, 23));
    expect(ApiDate.parse('2020-02-30'), isNull);
    expect(ApiDate.parse('14 Jan 1995'), isNull);
    expect(ApiDate.format(DateTime(1995, 1, 4)), '1995-01-04');
  });

  test('profile JSON carries birthday as a date and photoMediaId', () {
    final ProfileModel p = ProfileModel.fromJson(<String, dynamic>{
      'travelerId': 1,
      'username': 'sam',
      'birthday': '1990-04-23',
      'photoMediaId': 9,
      'photoUrl': 'https://bucket.example/x',
    });
    expect(p.birthday, DateTime(1990, 4, 23));
    expect(p.photoMediaId, 9);
    expect(p.toJson()['birthday'], '1990-04-23');
  });

  test('the update sends photoMediaId only when a new photo was uploaded, and never a photo URL', () {
    final Map<String, dynamic> withPhoto = ProfileRepository.updateBody(
      displayName: 'Sam',
      photoMediaId: 7,
      birthday: DateTime(1990, 4, 23),
    );
    expect(withPhoto['photoMediaId'], 7);
    expect(withPhoto['birthday'], '1990-04-23');
    expect(withPhoto.containsKey('photoUrl'), isFalse);
    expect(ProfileRepository.updateBody(displayName: 'Sam').containsKey('photoMediaId'), isFalse);
  });

  Future<List<DateTime?>> pumpPicker(WidgetTester tester, DateTime? value) async {
    final List<DateTime?> changes = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirthdayPicker(value: value, onChanged: changes.add, today: DateTime(2026, 11, 11)),
        ),
      ),
    );
    return changes;
  }

  testWidgets('BirthdayPicker reports a date once day, month and year are all picked', (WidgetTester tester) async {
    final List<DateTime?> changes = await pumpPicker(tester, null);
    await pick(tester, 'birthday-day', '5');
    await pick(tester, 'birthday-year', '2023');
    expect(changes.last, isNull);
    await pick(tester, 'birthday-month', 'Jan');
    expect(changes.last, DateTime(2023, 1, 5));
  });

  testWidgets('BirthdayPicker clears a day the new month does not have', (WidgetTester tester) async {
    final List<DateTime?> changes = await pumpPicker(tester, DateTime(2023, 1, 31));
    await pick(tester, 'birthday-month', 'Feb');
    expect(changes.last, isNull, reason: '31 February does not exist, so the day is cleared');
    await pick(tester, 'birthday-day', '5');
    expect(changes.last, DateTime(2023, 2, 5));
  });
}
