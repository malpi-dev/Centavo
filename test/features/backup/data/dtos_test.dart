import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/backup/data/dtos/budget_dto.dart';
import 'package:centavo/features/backup/data/dtos/category_dto.dart';
import 'package:centavo/features/backup/data/dtos/profile_dto.dart';
import 'package:centavo/features/backup/data/dtos/transaction_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  const userId = 'user-1';
  // Not UTC on purpose: the DTO must convert.
  final created = DateTime.parse('2026-10-01T10:00:00.123+02:00');
  final updated = DateTime.utc(2026, 10, 2, 8, 30, 15, 456);

  group('CategoryDto', () {
    final category = aCategory(
      id: 'c-1',
      createdAt: created,
      updatedAt: updated,
      archivedAt: updated,
      isDefault: true,
    );

    test('toJson uses snake_case, ARGB ints and UTC ISO dates', () {
      final json = CategoryDto.fromDomain(category, userId: userId).toJson();
      expect(json, {
        'user_id': userId,
        'id': 'c-1',
        'name': 'Food',
        'type': 'expense',
        'icon': 'food',
        'color': 0xFFE65100,
        'is_default': true,
        'created_at': '2026-10-01T08:00:00.123Z',
        'updated_at': '2026-10-02T08:30:15.456Z',
        'archived_at': '2026-10-02T08:30:15.456Z',
        'deleted_at': null,
      });
    });

    test('round trips without loss', () {
      final json = CategoryDto.fromDomain(category, userId: userId).toJson();
      final back = CategoryDto.fromJson(json).toDomain();
      expect(back, category.copyWith(createdAt: created.toUtc()));
      expect(back.createdAt.isUtc, isTrue);
    });

    test('reads what PostgREST returns (offset dates, synced_at)', () {
      final dto = CategoryDto.fromJson({
        'user_id': userId,
        'id': 'c-1',
        'name': 'Salary',
        'type': 'income',
        'icon': 'work',
        'color': 4294967295,
        'is_default': false,
        'archived_at': null,
        'deleted_at': null,
        'created_at': '2026-10-01T08:00:00.123456+00:00',
        'updated_at': '2026-10-01T08:00:00+00:00',
        'synced_at': '2026-10-01T08:00:01+00:00',
      });
      expect(dto.type, TransactionType.income);
      expect(dto.color, 0xFFFFFFFF);
      expect(dto.updatedAt, DateTime.utc(2026, 10, 1, 8));
      expect(dto.updatedAt.isUtc, isTrue);
    });
  });

  group('TransactionDto', () {
    final tx = aTransaction(
      id: 't-1',
      note: 'coffee',
      occurredOn: LocalDate(2026, 3, 9),
      createdAt: created,
      updatedAt: updated,
      deletedAt: updated,
    );

    test('occurred_on is YYYY-MM-DD', () {
      final json = TransactionDto.fromDomain(tx, userId: userId).toJson();
      expect(json['occurred_on'], '2026-03-09');
      expect(json['amount_minor'], 1000);
      expect(json['category_id'], 'cat-1');
      expect(json['deleted_at'], '2026-10-02T08:30:15.456Z');
      expect(json.containsKey('synced_at'), isFalse);
    });

    test('round trips without loss', () {
      final back = TransactionDto.fromJson(
        TransactionDto.fromDomain(tx, userId: userId).toJson(),
      ).toDomain();
      expect(back, tx.copyWith(createdAt: created.toUtc()));
    });
  });

  group('BudgetDto', () {
    final budget = aBudget(
      id: 'b-1',
      month: const YearMonth(2026, 2),
      createdAt: created,
      updatedAt: updated,
    );

    test('month is YYYY-MM-01', () {
      final json = BudgetDto.fromDomain(budget, userId: userId).toJson();
      expect(json['month'], '2026-02-01');
      expect(json['limit_minor'], 10000);
    });

    test('round trips without loss', () {
      final back = BudgetDto.fromJson(
        BudgetDto.fromDomain(budget, userId: userId).toJson(),
      ).toDomain();
      expect(back, budget.copyWith(createdAt: created.toUtc()));
    });
  });

  test('ProfileDto reads the currency', () {
    final dto = ProfileDto.fromJson({
      'id': userId,
      'currency_code': 'EUR',
      'created_at': '2026-10-01T08:00:00+00:00',
    });
    expect(dto.toDomain().currencyCode, 'EUR');
  });
}
