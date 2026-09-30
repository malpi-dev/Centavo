import 'dart:async';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/data/dtos/budget_dto.dart';
import 'package:centavo/features/backup/data/dtos/category_dto.dart';
import 'package:centavo/features/backup/data/dtos/profile_dto.dart';
import 'package:centavo/features/backup/data/dtos/transaction_dto.dart';
import 'package:centavo/features/backup/data/supabase_error_mapper.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only place that reads or writes business data in Supabase (schema
/// `centavo`). Every call runs under the user's session, so RLS applies.
class SupabaseBackupRepository implements BackupRepository {
  SupabaseBackupRepository(this._client);

  static const _timeout = Duration(seconds: 20);
  static const _pageSize = 1000;

  final SupabaseClient _client;

  SupabaseQuerySchema get _db => _client.schema('centavo');

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthError(AuthErrorKind.notSignedIn);
    return id;
  }

  Future<T> _guard<T>(Future<T> Function(String userId) body) async {
    try {
      final userId = _userId;
      return await body(userId).timeout(_timeout);
    } on Object catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<BackupProfile> ensureProfile(String currencyCode) => _guard((_) async {
    final result = await _db.rpc<dynamic>(
      'ensure_profile',
      params: {'p_currency_code': currencyCode},
    );
    final json = result is List ? result.first : result;
    return ProfileDto.fromJson(
      Map<String, dynamic>.from(json as Map),
    ).toDomain();
  });

  @override
  Future<void> updateCurrency(String currencyCode) => _guard(
    (userId) => _db
        .from('profiles')
        .update({'currency_code': currencyCode})
        .eq('id', userId),
  );

  @override
  Future<BackupProfile?> fetchProfile() => _guard((userId) async {
    final row = await _db
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : ProfileDto.fromJson(row).toDomain();
  });

  @override
  Future<void> upsertCategories(List<Category> rows) => _guard((userId) async {
    if (rows.isEmpty) return;
    await _db.from('categories').upsert([
      for (final r in rows) CategoryDto.fromDomain(r, userId: userId).toJson(),
    ], onConflict: 'user_id,id');
  });

  @override
  Future<void> upsertBudgets(List<Budget> rows) => _guard((userId) async {
    if (rows.isEmpty) return;
    await _db.from('budgets').upsert([
      for (final r in rows) BudgetDto.fromDomain(r, userId: userId).toJson(),
    ], onConflict: 'id');
  });

  @override
  Future<void> upsertTransactions(List<MoneyTransaction> rows) =>
      _guard((userId) async {
        if (rows.isEmpty) return;
        await _db.from('transactions').upsert([
          for (final r in rows)
            TransactionDto.fromDomain(r, userId: userId).toJson(),
        ], onConflict: 'id');
      });

  /// PostgREST returns at most 1000 rows per request, so page through.
  Future<List<Map<String, dynamic>>> _fetchAll(
    String table,
    String userId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (var from = 0; ; from += _pageSize) {
      final chunk = await _db
          .from(table)
          .select()
          .eq('user_id', userId)
          .order('updated_at')
          .order('id')
          .range(from, from + _pageSize - 1);
      rows.addAll(chunk);
      if (chunk.length < _pageSize) return rows;
    }
  }

  @override
  Future<List<Category>> fetchCategories() => _guard((userId) async {
    final rows = await _fetchAll('categories', userId);
    return [for (final r in rows) CategoryDto.fromJson(r).toDomain()];
  });

  @override
  Future<List<Budget>> fetchBudgets() => _guard((userId) async {
    final rows = await _fetchAll('budgets', userId);
    return [for (final r in rows) BudgetDto.fromJson(r).toDomain()];
  });

  @override
  Future<List<MoneyTransaction>> fetchTransactions() => _guard((userId) async {
    final rows = await _fetchAll('transactions', userId);
    return [for (final r in rows) TransactionDto.fromJson(r).toDomain()];
  });

  @override
  Future<void> deleteAll() => _guard((userId) async {
    // Children first.
    for (final table in const ['transactions', 'budgets', 'categories']) {
      await _db.from(table).delete().eq('user_id', userId);
    }
  });
}
