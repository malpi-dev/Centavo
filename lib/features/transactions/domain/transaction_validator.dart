import 'package:centavo/core/domain/amount_parser.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';

const maxNoteLength = 140;

/// '' or whitespace -> null; otherwise trimmed.
String? normalizeNote(String? note) {
  final trimmed = note?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Form-level validation (all field errors at once). Fields: 'amount',
/// 'category', 'note'. Amount must be > 0; category required; note <= 140
/// after trim.
Map<String, ValidationReason> validateTransactionForm({
  required String amountText,
  required int minorUnits,
  required String? categoryId,
  required String note,
}) {
  final errors = <String, ValidationReason>{};
  try {
    final amount = parseAmountToMinor(amountText, minorUnits: minorUnits);
    if (amount <= 0) errors['amount'] = ValidationReason.mustBePositive;
  } on ValidationError catch (e) {
    errors['amount'] = e.reason;
  }
  if (categoryId == null || categoryId.isEmpty) {
    errors['category'] = ValidationReason.required;
  }
  if ((normalizeNote(note) ?? '').length > maxNoteLength) {
    errors['note'] = ValidationReason.tooLong;
  }
  return errors;
}

/// Repository-level guard. Throws the first ValidationError found.
void assertValidDraft(TransactionDraft draft) {
  if (draft.amountMinor <= 0) {
    throw const ValidationError('amount', ValidationReason.mustBePositive);
  }
  if ((normalizeNote(draft.note) ?? '').length > maxNoteLength) {
    throw const ValidationError('note', ValidationReason.tooLong);
  }
}
