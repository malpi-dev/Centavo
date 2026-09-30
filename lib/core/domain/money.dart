import 'package:meta/meta.dart';

/// An amount in minor units (e.g. cents) with its currency. Never a double.
@immutable
class Money implements Comparable<Money> {
  const Money(this.amountMinor, this.currencyCode);

  const Money.zero(this.currencyCode) : amountMinor = 0;

  final int amountMinor;
  final String currencyCode;

  /// Throws [ArgumentError] if currencies differ (programming error).
  Money operator +(Money other) {
    _checkSameCurrency(other);
    return Money(amountMinor + other.amountMinor, currencyCode);
  }

  Money operator -(Money other) {
    _checkSameCurrency(other);
    return Money(amountMinor - other.amountMinor, currencyCode);
  }

  bool get isZero => amountMinor == 0;

  bool get isNegative => amountMinor < 0;

  /// Ratio of this amount to [total] in basis points (10000 = 100 %), integer
  /// math, truncated. 0 when total is 0.
  int basisPointsOf(Money total) {
    _checkSameCurrency(total);
    if (total.amountMinor == 0) return 0;
    return amountMinor * 10000 ~/ total.amountMinor;
  }

  /// Display-only ratio. Never use it to decide business states.
  double ratioOf(Money total) {
    _checkSameCurrency(total);
    if (total.amountMinor == 0) return 0;
    return amountMinor / total.amountMinor;
  }

  void _checkSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw ArgumentError(
        'Currency mismatch: $currencyCode vs ${other.currencyCode}',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _checkSameCurrency(other);
    return amountMinor.compareTo(other.amountMinor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.amountMinor == amountMinor &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(amountMinor, currencyCode);

  @override
  String toString() => 'Money($amountMinor $currencyCode)';
}
