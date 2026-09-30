import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/backup/data/dtos/json_converters.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category_dto.g.dart';

@JsonSerializable()
@UtcDateTimeConverter()
class CategoryDto {
  const CategoryDto({
    required this.userId,
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  factory CategoryDto.fromDomain(Category c, {required String userId}) =>
      CategoryDto(
        userId: userId,
        id: c.id,
        name: c.name,
        type: c.type,
        icon: c.icon,
        color: c.color,
        isDefault: c.isDefault,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        archivedAt: c.archivedAt,
        deletedAt: c.deletedAt,
      );

  factory CategoryDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryDtoFromJson(json);

  final String userId;
  final String id;
  final String name;
  final TransactionType type;
  final String icon;
  final int color;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => _$CategoryDtoToJson(this);

  Category toDomain() => Category(
    id: id,
    name: name,
    type: type,
    icon: icon,
    color: color,
    isDefault: isDefault,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
  );
}
