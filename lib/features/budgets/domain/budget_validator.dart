import 'package:centavo/core/domain/amount_parser.dart';
import 'package:centavo/core/errors/domain_error.dart';

/// Field 'limit'; same rules as a transaction amount.
Map<String, ValidationReason> validateBudgetForm({
  required String limitText,
  required int minorUnits,
}) {
  try {
    final limit = parseAmountToMinor(
      limitText,
      minorUnits: minorUnits,
      field: 'limit',
    );
    if (limit <= 0) return {'limit': ValidationReason.mustBePositive};
  } on ValidationError catch (e) {
    return {'limit': e.reason};
  }
  return {};
}
