import 'package:centavo/core/domain/id_generator.dart';
import 'package:uuid/uuid.dart';

class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();

  @override
  String newId() => const Uuid().v4();
}
