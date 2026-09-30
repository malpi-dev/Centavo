import 'package:centavo/core/domain/local_date.dart';

/// Source of the current time. Inject it; never call `DateTime.now()` elsewhere.
abstract interface class Clock {
  DateTime nowUtc();
  LocalDate today();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  LocalDate today() => LocalDate.fromDateTime(DateTime.now());
}

/// Deterministic clock for tests and previews. [now] is mutable so tests can
/// advance time.
class FixedClock implements Clock {
  FixedClock(DateTime now, {LocalDate? today})
    : now = now.toUtc(),
      _today = today;

  DateTime now;
  final LocalDate? _today;

  @override
  DateTime nowUtc() => now;

  @override
  LocalDate today() => _today ?? LocalDate.fromDateTime(now);
}
