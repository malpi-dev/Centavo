# Fase 03 · Dominio

**Rama:** `feat/fase-03-dominio`
**Objetivo:** modelos `freezed`, interfaces de repositorio, validadores y casos de uso de categorías, movimientos,
presupuestos, dashboard y exportación. Todo **Dart puro** y cubierto por tests. Sin UI ni persistencia.
**Referencias:** definición §3.1 (F2–F5, F7), §6 completo, §13 (unit de dominio).
**Requisitos previos:** fase 02 terminada.

> Regla de oro: nada de esta fase importa Flutter, Drift, Supabase ni Riverpod. `./tool/check_architecture.sh` lo vigila.
> Los casos de uso de respaldo (`RunBackup`, `RestoreBackup`) y los métodos de repositorio que necesitan se añaden en la fase 12.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Tipo de movimiento (`lib/core/domain/transaction_type.dart`)

```dart
enum TransactionType { income, expense }
```

Vive en `core/domain` porque lo comparten categorías, movimientos y presupuestos. El nombre del enum (`income`,
`expense`) es el que se persiste en Drift, Supabase y CSV.

## Paso 2 · `LocalStore` (`lib/core/domain/local_store.dart`)

```dart
/// Operations that span several local repositories.
abstract interface class LocalStore {
  /// Runs [action] atomically (a Drift transaction in production; a plain call in mocks).
  Future<T> runInTransaction<T>(Future<T> Function() action);
  /// Deletes every local row (categories, transactions, budgets, sync state). Used by "Erase all local data".
  Future<void> eraseAll();
}
```

## Paso 3 · Categorías (`lib/features/categories/domain/`)

### 3.1 `category.dart`

```dart
@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required TransactionType type,
    required String icon,          // one of categoryIconKeys
    required int color,            // one of categoryColorPalette (light ARGB)
    required bool isDefault,
    required DateTime createdAt,   // UTC
    required DateTime updatedAt,   // UTC, last-write-wins key
    DateTime? archivedAt,
    DateTime? deletedAt,           // tombstone
  }) = _Category;
  const Category._();
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isArchived && !isDeleted;
}
```

### 3.2 `default_categories.dart`

UUID **fijos** (ver bitácora). Función `List<Category> buildDefaultCategories(DateTime nowUtc)` que devuelve:

| id | name | type | icon | color |
|---|---|---|---|---|
| `00000000-0000-4000-8000-000000000001` | Food | expense | `food` | `0xFFE65100` |
| `00000000-0000-4000-8000-000000000002` | Transport | expense | `transport` | `0xFF1565C0` |
| `00000000-0000-4000-8000-000000000003` | Home | expense | `home` | `0xFF6D4C41` |
| `00000000-0000-4000-8000-000000000004` | Health | expense | `health` | `0xFFC62828` |
| `00000000-0000-4000-8000-000000000005` | Entertainment | expense | `entertainment` | `0xFF7B1FA2` |
| `00000000-0000-4000-8000-000000000006` | Shopping | expense | `shopping` | `0xFFC2185B` |
| `00000000-0000-4000-8000-000000000007` | Other | expense | `other` | `0xFF546E7A` |
| `00000000-0000-4000-8000-000000000101` | Salary | income | `salary` | `0xFF2E7D32` |
| `00000000-0000-4000-8000-000000000102` | Freelance | income | `freelance` | `0xFF00796B` |
| `00000000-0000-4000-8000-000000000103` | Other income | income | `investments` | `0xFF3949AB` |

Todas con `isDefault: true`, `createdAt = updatedAt = nowUtc`. Exporta también las constantes de id
(`DefaultCategoryIds.food`, …) porque las usa el dataset de demo.

### 3.3 `category_validator.dart`

```dart
/// Returns field errors (empty map = valid). Fields: 'name', 'icon', 'color'.
Map<String, ValidationReason> validateCategoryForm({required String name, required String icon, required int color});
/// Trims and collapses inner whitespace ("  Eating   out " → "Eating out").
String normalizeCategoryName(String name);
```

Reglas: nombre normalizado de 1 a 30 caracteres (`required` / `tooLong`); `icon` ∈ `categoryIconKeys` y `color` ∈
`categoryColorPalette` (si no, `notAllowed`).

### 3.4 `category_repository.dart`

```dart
abstract interface class CategoryRepository {
  /// Non-deleted categories (active and archived) ordered by type (expense first), then name case-insensitively.
  Stream<List<Category>> watchAll();
  Future<List<Category>> getAll();
  /// Null when missing or deleted.
  Future<Category?> findById(String id);
  /// Validates (ValidationError), normalizes the name and enforces uniqueness among ACTIVE categories by
  /// (lower(name), type) → DuplicateError('category').
  Future<Category> create({required String name, required TransactionType type, required String icon, required int color});
  /// Updates name, icon and color. Changing type → ValidationError('type', notAllowed). Same uniqueness rule.
  /// Missing/deleted → NotFoundError('category', id).
  Future<Category> update(Category category);
  Future<void> archive(String id);
  /// DuplicateError if an active category with the same name and type exists.
  Future<void> unarchive(String id);
  /// Tombstone. No checks here: DeleteOrArchiveCategory decides whether deleting is allowed.
  Future<void> softDelete(String id);
  /// Inserts categories keeping their ids and timestamps. Ids that already exist (even deleted) are skipped.
  Future<void> insertIfAbsent(List<Category> categories);
}
```

Todas las escrituras ponen `updatedAt = clock.nowUtc()` (regla §6.2.6), salvo `insertIfAbsent`, que respeta los valores recibidos.

### 3.5 Casos de uso

- `seed_default_categories.dart` → `SeedDefaultCategories(CategoryRepository, Clock)`; `call()` =
  `insertIfAbsent(buildDefaultCategories(clock.nowUtc()))`. Idempotente gracias a los ids fijos.
- `delete_or_archive_category.dart`:
  ```dart
  enum CategoryRemoval { deleted, archived }
  class DeleteOrArchiveCategory {
    DeleteOrArchiveCategory({required CategoryRepository categories, required TransactionRepository transactions,
        required BudgetRepository budgets, required LocalStore localStore});
    /// NotFoundError if missing. With non-deleted transactions → archive. Otherwise, inside one local transaction,
    /// soft-delete the category's budgets and then the category.
    Future<CategoryRemoval> call(String categoryId);
  }
  ```

## Paso 4 · Movimientos (`lib/features/transactions/domain/`)

### 4.1 Modelos

```dart
@freezed
abstract class MoneyTransaction with _$MoneyTransaction {   // "Transaction" collides with Drift
  const factory MoneyTransaction({
    required String id,
    required TransactionType type,
    required int amountMinor,       // > 0; the sign comes from type
    required String categoryId,
    required LocalDate occurredOn,
    String? note,                   // trimmed, null when empty, <= 140 chars
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _MoneyTransaction;
}

@freezed
abstract class TransactionDraft with _$TransactionDraft {
  const factory TransactionDraft({
    required TransactionType type,
    required int amountMinor,
    required String categoryId,
    required LocalDate occurredOn,
    String? note,
  }) = _TransactionDraft;
}
```

(Si freezed se queja del orden de parámetros requeridos/opcionales, reordénalos; el orden no importa.)

### 4.2 `transaction_validator.dart`

```dart
const maxNoteLength = 140;

/// Form-level validation (all field errors at once). Fields: 'amount', 'category', 'note'.
/// Uses parseAmountToMinor; amount must be > 0 (mustBePositive); category required; note <= 140 after trim (tooLong).
Map<String, ValidationReason> validateTransactionForm({
  required String amountText, required int minorUnits, required String? categoryId, required String note,
});

/// Repository-level guard. Throws the first ValidationError found (amount <= 0, note too long).
void assertValidDraft(TransactionDraft draft);

/// '' or whitespace → null; otherwise trimmed.
String? normalizeNote(String? note);
```

### 4.3 `transaction_repository.dart`

```dart
abstract interface class TransactionRepository {
  /// Non-deleted transactions with from <= occurredOn < toExclusive, ordered by occurredOn desc, createdAt desc.
  Stream<List<MoneyTransaction>> watchBetween(LocalDate from, LocalDate toExclusive);
  /// Same as watchBetween but one-shot; null bounds are open (export "all").
  Future<List<MoneyTransaction>> getBetween(LocalDate? from, LocalDate? toExclusive);
  Future<MoneyTransaction?> findById(String id);
  /// assertValidDraft + category must exist and not be deleted (NotFoundError('category')) and have the same type
  /// (CategoryTypeMismatchError). Generates id and timestamps.
  Future<MoneyTransaction> create(TransactionDraft draft);
  /// Same checks. NotFoundError('transaction') if missing/deleted.
  Future<MoneyTransaction> update(MoneyTransaction transaction);
  Future<void> softDelete(String id);
  /// Undo of softDelete: deletedAt = null, updatedAt = now.
  Future<void> restore(String id);
  /// Count of non-deleted transactions in a category.
  Future<int> countByCategory(String categoryId);
}
```

## Paso 5 · Presupuestos (`lib/features/budgets/domain/`)

### 5.1 `budget.dart`

```dart
@freezed
abstract class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String categoryId,     // expense categories only
    required YearMonth month,
    required int limitMinor,        // > 0
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Budget;
}
```

### 5.2 `budget_repository.dart`

```dart
abstract interface class BudgetRepository {
  Stream<List<Budget>> watchMonth(YearMonth month);    // non-deleted
  Future<List<Budget>> getMonth(YearMonth month);
  Future<Budget?> findActive(String categoryId, YearMonth month);
  /// Creates or updates THE active budget of (category, month). limitMinor <= 0 → ValidationError('limit', mustBePositive).
  /// Category missing/deleted → NotFoundError('category'); income category → CategoryTypeMismatchError.
  Future<Budget> setLimit({required String categoryId, required YearMonth month, required int limitMinor});
  Future<void> softDelete(String id);
  Future<void> softDeleteByCategory(String categoryId);
}
```

`budget_validator.dart`: `Map<String, ValidationReason> validateBudgetForm({required String limitText, required int minorUnits})`
(campo `limit`; mismas reglas que el monto de un movimiento).

### 5.3 `get_budget_progress.dart`

```dart
enum BudgetStatus { onTrack, warning, exceeded }

@freezed
abstract class BudgetLine with _$BudgetLine {
  const factory BudgetLine({
    required Budget budget, required Category category,
    required Money limit, required Money spent, required Money remaining,   // remaining may be negative
    required int basisPoints,                                              // spent / limit, 10000 = 100 %
    required BudgetStatus status,
  }) = _BudgetLine;
}

@freezed
abstract class BudgetProgressReport with _$BudgetProgressReport {
  const factory BudgetProgressReport({
    required List<BudgetLine> lines,                 // sorted by basisPoints desc, then category name
    required Money totalLimit,
    required Money totalSpent,                       // spent in budgeted categories only
    required Money unbudgetedSpent,                  // expenses in categories without a budget this month
    required List<Category> categoriesWithoutBudget, // ACTIVE expense categories without budget (for "Set budget")
  }) = _BudgetProgressReport;
}

class GetBudgetProgress {
  const GetBudgetProgress();
  BudgetProgressReport call({
    required YearMonth month, required List<Budget> budgets, required List<MoneyTransaction> transactions,
    required List<Category> categories, required String currencyCode,
  });
}
```

Reglas:
- Solo cuentan movimientos `expense` no borrados cuyo `occurredOn` está en `month` (filtra aunque el llamador ya lo haga).
- Estado con **enteros**: `spent * 100 < limit * 80` → `onTrack`; si no, `spent <= limit` → `warning`; si no, `exceeded`.
  (80 % exacto es `warning`; 100 % exacto es `warning`; 100,01 % es `exceeded`.)
- Presupuestos cuya categoría no existe o está borrada se ignoran. Si la categoría está archivada, la línea se muestra.

### 5.4 `copy_budgets_from_previous_month.dart`

```dart
class CopyBudgetsFromPreviousMonth {
  CopyBudgetsFromPreviousMonth({required BudgetRepository budgets, required CategoryRepository categories,
      required LocalStore localStore});
  /// Copies previous-month limits into [month] without overwriting existing budgets and skipping categories that are
  /// archived, deleted or missing. Runs inside one local transaction. Returns how many budgets were created.
  Future<int> call(YearMonth month);
}
```

## Paso 6 · Dashboard (`lib/features/dashboard/domain/`)

### 6.1 `get_month_summary.dart`

```dart
@freezed
abstract class CategorySlice with _$CategorySlice {
  const factory CategorySlice({
    String? categoryId,          // null = "Others" (or a deleted category)
    String? name, String? icon, int? color,
    required Money amount,
    required int basisPoints,    // share of total expenses
  }) = _CategorySlice;
}

@freezed
abstract class MonthSummary with _$MonthSummary {
  const factory MonthSummary({
    required Money income, required Money expense, required Money balance,
    required List<CategorySlice> expenseSlices,   // top N by amount desc (+ "Others" if there are more)
    required int transactionCount,
  }) = _MonthSummary;
  const MonthSummary._();
  bool get isEmpty => transactionCount == 0;
}

class GetMonthSummary {
  const GetMonthSummary();
  MonthSummary call({
    required YearMonth month, required List<MoneyTransaction> transactions, required List<Category> categories,
    required String currencyCode, int topN = 5,
  });
}
```

Reglas: filtra por `month` y no borrados; `balance = income − expense`; agrupa gastos por `categoryId`, ordena por monto
desc (empate: nombre asc); los primeros `topN` son slices con datos de su categoría; el resto se suma en un único slice
`categoryId: null, name: null` ("Others"), solo si hay resto. CA1 de F5: los totales son la suma **exacta** en centavos.

### 6.2 `get_monthly_trend.dart`

```dart
@freezed
abstract class MonthTotals with _$MonthTotals {
  const factory MonthTotals({required YearMonth month, required Money income, required Money expense}) = _MonthTotals;
}

class GetMonthlyTrend {
  const GetMonthlyTrend();
  /// Exactly [months] items, oldest first, ending at [endMonth]; months without data are zero.
  List<MonthTotals> call({required YearMonth endMonth, required List<MoneyTransaction> transactions,
      required String currencyCode, int months = 6});
}
```

## Paso 7 · Exportación (`lib/features/export/domain/`)

### 7.1 Modelos e interfaz

```dart
sealed class ExportRange { const ExportRange(); }
final class ExportMonth extends ExportRange { const ExportMonth(this.month); final YearMonth month; }
final class ExportAll extends ExportRange { const ExportAll(); }

@immutable
class CsvDocument { const CsvDocument({required this.fileName, required this.content}); final String fileName; final String content; }

/// Writes the document to a temporary file and opens the system share sheet.
/// Throws ExportError(writeFailed | shareFailed).
abstract interface class CsvShareService { Future<void> share(CsvDocument document); }
```

### 7.2 `export_transactions_csv.dart`

```dart
class ExportTransactionsCsv {
  ExportTransactionsCsv({required TransactionRepository transactions, required CategoryRepository categories, required Clock clock});
  /// Throws ExportError(emptyRange) when there is nothing to export (CA2 of F7).
  Future<CsvDocument> call(ExportRange range, {required String currencyCode});
}

/// Pure builder, tested directly.
String buildTransactionsCsv({required List<MoneyTransaction> transactions, required Map<String, Category> categoriesById,
    required String currencyCode});
```

Formato (definición F7, bitácora):
- Contenido = BOM `﻿` + cabecera `date,type,category,amount,currency,note` + filas; **cada** línea termina en `\r\n`.
- Orden: `occurredOn` asc, luego `createdAt` asc.
- `date` = `occurredOn.toIso()`; `type` = `income`/`expense`; `category` = nombre (vacío si no existe);
  `amount` = `formatMinorPlain(amountMinor, minorUnits)`; `currency` = código; `note` = nota o vacío.
- Escape RFC 4180: si el campo contiene `,`, `"`, `\r` o `\n` → se envuelve en comillas y cada `"` se duplica.
- Protección contra fórmulas (CSV injection): si un campo de texto (categoría o nota) empieza por `=`, `+`, `-` o `@`,
  se antepone `'` antes de escapar.
- Nombre de archivo: `ExportMonth` → `centavo-transactions-2026-10.csv`; `ExportAll` → `centavo-transactions-all-<hoy ISO>.csv`.

## Paso 8 · Generar código

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Paso 9 · Tests

Usa `mocktail` para los repositorios en los casos de uso con dependencias (`class MockBudgetRepository extends Mock implements BudgetRepository {}`,
y `registerFallbackValue(const YearMonth(2026, 1))` donde haga falta). Crea `test/helpers/builders.dart` con funciones
`aCategory({...})`, `aTransaction({...})`, `aBudget({...})` con valores por defecto razonables para acortar los tests.

| Archivo | Casos mínimos |
|---|---|
| `test/features/categories/domain/category_validator_test.dart` | vacío/espacios → `required`; 31 chars → `tooLong`; normaliza espacios; ícono o color fuera del set → `notAllowed`. |
| `test/features/categories/domain/default_categories_test.dart` | 10 categorías, 7 gasto + 3 ingreso, ids únicos y fijos, íconos/colores válidos. |
| `test/features/categories/domain/delete_or_archive_category_test.dart` | con movimientos → `archive` y **no** borra; sin movimientos → borra presupuestos y categoría dentro de `runInTransaction`; id inexistente → `NotFoundError`. |
| `test/features/categories/domain/seed_default_categories_test.dart` | llama `insertIfAbsent` con las 10 por defecto y la hora del reloj. |
| `test/features/transactions/domain/transaction_validator_test.dart` | monto vacío/0/negativo/demasiados decimales; CLP; categoría nula; nota 141 chars; varios errores a la vez; `normalizeNote`. |
| `test/features/budgets/domain/get_budget_progress_test.dart` | umbrales exactos: 79,99 % onTrack, 80 % warning, 100 % warning, 100,01 % exceeded; `remaining` negativo; ingresos no cuentan; gastos de otro mes no cuentan; `unbudgetedSpent`; `categoriesWithoutBudget` excluye archivadas e ingresos; orden de `lines`; presupuesto de categoría borrada ignorado. |
| `test/features/budgets/domain/copy_budgets_from_previous_month_test.dart` | copia los que faltan; no sobrescribe existentes; ignora archivadas/borradas; devuelve el número copiado; mes anterior vacío → 0. |
| `test/features/dashboard/domain/get_month_summary_test.dart` | totales exactos en centavos; balance negativo; top 5 + Others (7 categorías → 6 slices; 5 → 5 sin Others); empate por nombre; `basisPoints`; mes vacío → `isEmpty`; ignora borrados y otros meses. |
| `test/features/dashboard/domain/get_monthly_trend_test.dart` | 6 elementos del más antiguo al más reciente; meses vacíos en 0; cruza de año (endMonth 2026-02 → empieza en 2025-09); ignora datos fuera de rango. |
| `test/features/export/domain/export_transactions_csv_test.dart` | BOM y `\r\n`; cabecera exacta; orden; montos `12.50` y CLP `5000`; nota con coma, con comillas y con salto de línea; nota `=SUM(A1)` → `'=SUM(A1)`; categoría inexistente → vacío; rango vacío → `ExportError(emptyRange)`; nombres de archivo. |

## Paso 10 · Cierre

`00-guia-general.md` §3.3. Comprueba especialmente que `./tool/check_architecture.sh` pasa.

---

## Criterios de terminado

- [ ] Modelos `Category`, `MoneyTransaction`, `TransactionDraft`, `Budget` y los de resultados, con freezed.
- [ ] Interfaces `CategoryRepository`, `TransactionRepository`, `BudgetRepository`, `LocalStore`, `CsvShareService` documentadas.
- [ ] Casos de uso `SeedDefaultCategories`, `DeleteOrArchiveCategory`, `GetBudgetProgress`, `CopyBudgetsFromPreviousMonth`, `GetMonthSummary`, `GetMonthlyTrend`, `ExportTransactionsCsv` implementados.
- [ ] Validadores de formulario (categoría, movimiento, presupuesto) con errores por campo.
- [ ] Ningún `double` decide un estado ni representa un monto.
- [ ] Todos los tests de la tabla pasan; `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
