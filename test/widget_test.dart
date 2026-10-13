import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:summerschool/providers/weekly_schedule_provider.dart';
import 'package:summerschool/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email validator should accept valid email', () {
      expect(Validators.email('user@example.com'), isNull);
    });

    test('email validator should reject invalid email', () {
      expect(Validators.email('invalid-email'), isNotNull);
    });

    test('password validator should reject short password', () {
      expect(Validators.password('123'), isNotNull);
    });
  });

  group('Localization', () {
    test(
      'uses the requested spiritual note wording in English and Arabic',
      () async {
        final en =
            jsonDecode(await File('assets/translations/en.json').readAsString())
                as Map<String, dynamic>;
        final ar =
            jsonDecode(await File('assets/translations/ar.json').readAsString())
                as Map<String, dynamic>;

        expect(en['spiritual_note'], 'Spiritual Note');
        expect(ar['spiritual_note'], 'النوتة الروحية');
      },
    );
  });

  group('Weekly schedule day selector', () {
    test('uses only Sunday and Wednesday as selectable days', () {
      expect(WeeklyScheduleDays.values, const [
        WeeklyScheduleDays.sunday,
        WeeklyScheduleDays.wednesday,
      ]);
    });

    test(
      'maps each selectable day to the correct date inside the selected week',
      () {
        final weekStart = DateTime(2026, 10, 4);

        expect(
          WeeklyScheduleDays.dateForDay(WeeklyScheduleDays.sunday, weekStart),
          DateTime(2026, 10, 4),
        );
        expect(
          WeeklyScheduleDays.dateForDay(
            WeeklyScheduleDays.wednesday,
            weekStart,
          ),
          DateTime(2026, 10, 7),
        );
      },
    );

    test('defaults to Sunday unless today is Sunday or Wednesday', () {
      final today = DateTime.now();
      final weekStart = _weekStartOf(today);
      final expected =
          (today.weekday == DateTime.wednesday ||
              today.weekday == DateTime.sunday)
          ? WeeklyScheduleDays.dayForDate(today)
          : WeeklyScheduleDays.sunday;

      expect(WeeklyScheduleDays.defaultSelectedDayForWeek(weekStart), expected);
      expect(
        WeeklyScheduleDays.defaultSelectedDayForWeek(
          weekStart.subtract(const Duration(days: 7)),
        ),
        WeeklyScheduleDays.sunday,
      );
    });
  });
}

DateTime _weekStartOf(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  var diff = local.weekday - DateTime.sunday;
  if (diff < 0) diff += 7;
  return local.subtract(Duration(days: diff));
}
