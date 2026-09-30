# Centavo

Offline-first personal finance app (Flutter). Global portfolio rules live in `../CLAUDE.md`; the implementation plan
lives in `docs/implementation/` (read `00-guia-general.md` and `bitacora.md` first).

## Documented exception to portfolio rule 4

The business data repositories (`TransactionRepository`, `CategoryRepository`, `BudgetRepository`) have `drift_*` +
`mock_*` implementations, not `supabase_*`, because Drift is the source of truth (offline-first). Supabase is only a
backup target, used exclusively by `BackupRepository` and `AuthRepository`, which do have `supabase_*` + `mock_*`
implementations.

## Commands

- `./tool/check.sh` — full verification (pub get, gen-l10n, build_runner, format, architecture check, analyze, tests).
- `dart run build_runner watch -d` — regenerate code while developing.
- `flutter run --dart-define-from-file=.env.json` — run with backup configured (plain `flutter run` = local + demo mode).

## Rules

- Money is always `int` minor units (`amountMinor`); never `double`.
- Timestamps are UTC, obtained through `Clock`; days are `LocalDate`, months are `YearMonth`.
- UI strings live in `lib/l10n/app_en.arb`; no literals in widgets.
- Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) are not committed.
- Code, commits, PRs and docs of the repo are in English (except `docs/`, in Spanish). Conventional Commits.
