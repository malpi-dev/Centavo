import 'package:centavo/core/domain/transaction_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';

@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required TransactionType type,

    /// One of `categoryIconKeys`.
    required String icon,

    /// One of `categoryColorPalette` (light ARGB).
    required int color,
    required bool isDefault,

    /// UTC.
    required DateTime createdAt,

    /// UTC, last-write-wins key.
    required DateTime updatedAt,
    DateTime? archivedAt,

    /// Tombstone.
    DateTime? deletedAt,
  }) = _Category;
  const Category._();

  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;
}
