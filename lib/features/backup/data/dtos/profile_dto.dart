import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_dto.g.dart';

@JsonSerializable()
class ProfileDto {
  const ProfileDto({required this.id, required this.currencyCode});

  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDtoFromJson(json);

  final String id;
  final String currencyCode;

  Map<String, dynamic> toJson() => _$ProfileDtoToJson(this);

  BackupProfile toDomain() => BackupProfile(currencyCode: currencyCode);
}
