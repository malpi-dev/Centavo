import 'package:centavo/core/domain/id_generator.dart';

class SequentialIdGenerator implements IdGenerator {
  int _n = 0;

  @override
  String newId() => 'id-${++_n}';
}
