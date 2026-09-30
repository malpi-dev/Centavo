# Fase 04 · Persistencia con Drift

**Rama:** `feat/fase-04-persistencia-drift`
**Objetivo:** base local SQLite con Drift (`schemaVersion = 1`), fuente de verdad de la app. Repositorios Drift de
categorías, movimientos y presupuestos que cumplen las interfaces de la fase 03, traducen errores de SQLite a
`DomainError` y exponen streams reactivos. Tests con Drift en memoria.
**Referencias:** definición §6.2, §7.6 (bloque "Drift"), §8.3, §8.4, §13 (repositorios Drift, migraciones).
**Requisitos previos:** fase 03 terminada.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Dependencia `sqlite3`

Los repositorios necesitan reconocer `SqliteException` (viene del paquete `sqlite3`, que ya es dependencia transitiva
de Drift). Para importarlo sin violar el lint `depend_on_referenced_packages`:

```bash
flutter pub add sqlite3
```

Anota en la bitácora que se añadió como dependencia directa y por qué.

## Paso 2 · Conversores (`lib/core/database/converters.dart`)

```dart
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();
  @override LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);
  @override String toSql(LocalDate value) => value.toIso();
}

/// Budgets store the first day of the month ('2026-10-01'), like Supabase's `month date`.
class YearMonthConverter extends TypeConverter<YearMonth, String> {
  const YearMonthConverter();
  @override YearMonth fromSql(String fromDb) => YearMonth.parse(fromDb);
  @override String toSql(YearMonth value) => value.toFirstDayIso();
}
```

## Paso 3 · Tablas (`lib/core/database/tables/`)

Un archivo por tabla. Los nombres SQL resultantes (snake_case) coinciden con las columnas de Supabase (§7.1) salvo
`user_id` y `synced_at`, que no existen en local.

```dart
// categories_table.dart
@DataClassName('CategoryRow')
@TableIndex.sql('CREATE UNIQUE INDEX categories_active_name_type ON categories (lower(name), type) '
    'WHERE archived_at IS NULL AND deleted_at IS NULL')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get type => textEnum<TransactionType>()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// transactions_table.dart
@DataClassName('TransactionRow')
@TableIndex.sql('CREATE INDEX transactions_occurred_on ON transactions (occurred_on) WHERE deleted_at IS NULL')
@TableIndex(name: 'transactions_category_id', columns: {#categoryId})
@TableIndex(name: 'transactions_updated_at', columns: {#updatedAt})
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<TransactionType>()();
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get occurredOn => text().map(const LocalDateConverter())();
  TextColumn get note => text().withLength(max: 140).nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// budgets_table.dart
@DataClassName('BudgetRow')
@TableIndex.sql('CREATE UNIQUE INDEX budgets_active_category_month ON budgets (category_id, month) '
    'WHERE deleted_at IS NULL')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get month => text().map(const YearMonthConverter())();
  IntColumn get limitMinor => integer().check(limitMinor.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// sync_state_table.dart — key/value used by backup (phase 12): 'lastBackupAt', 'lastRestoreAt'
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override Set<Column> get primaryKey => {key};
}
```

Notas:
- `@TableIndex.sql` existe en las versiones recientes de Drift. Si la versión instalada no lo soporta, quita esas
  anotaciones y crea los índices con `customStatement` dentro de `onCreate` (después de `m.createAll()`); anótalo en
  la bitácora.
- `sync_state` se crea ya en la v1 para no necesitar una migración en la fase 12.
- Los `DateTime` se guardan como texto ISO-8601 (opción `store_date_time_values_as_text` de `build.yaml`).
  **Escribe siempre valores UTC** y al leer aplica `.toUtc()` en el mapper.

## Paso 4 · Base de datos (`lib/core/database/app_database.dart`)

```dart
@DriftDatabase(tables: [Categories, Transactions, Budgets, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Production database file `centavo.sqlite` in the app documents directory.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'centavo'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        // onUpgrade: add step-by-step migrations here when schemaVersion goes up (see "Futuras migraciones").
      );
}
```

Genera el código y guarda el snapshot del esquema v1:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev make-migrations
```

`make-migrations` crea `drift_schemas/centavo/drift_schema_v1.json` (se commitea). Con una sola versión no genera
tests de migración; eso ocurrirá cuando exista la v2.

**Futuras migraciones** (documéntalo como comentario en `app_database.dart`): subir `schemaVersion`, ejecutar
`dart run drift_dev make-migrations`, implementar el paso en `onUpgrade` con los helpers generados (`stepByStep`) y
dejar pasar los tests generados en `test/drift/`.

## Paso 5 · Traducción de errores (`lib/core/database/storage_guard.dart`)

```dart
/// Runs a database operation and translates low-level failures into DomainError.
Future<T> guardStorage<T>(Future<T> Function() body, {required String entity}) async {
  try {
    return await body();
  } on DomainError {
    rethrow;
  } on Object catch (error) {
    throw mapStorageError(error, entity: entity);
  }
}

DomainError mapStorageError(Object error, {required String entity}) {
  // drift_flutter runs SQLite in a background isolate: errors arrive wrapped in DriftRemoteException.
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  if (cause is SqliteException) {
    return switch (cause.extendedResultCode) {
      2067 || 1555 => DuplicateError(entity),        // SQLITE_CONSTRAINT_UNIQUE / PRIMARYKEY
      787 => NotFoundError(entity),                  // SQLITE_CONSTRAINT_FOREIGNKEY
      _ => StorageError(cause),
    };
  }
  return StorageError(cause);
}
```

Para streams (`watch…`) usa `stream.handleError((Object e, StackTrace s) => throw mapStorageError(e, entity: …))`
o equivalente, de modo que el `StreamProvider` reciba un `DomainError`.

## Paso 6 · Mappers

Uno por feature, en `data/`: `category_row_mapper.dart`, `transaction_row_mapper.dart`, `budget_row_mapper.dart`.

- `extension CategoryRowX on CategoryRow { Category toDomain() }` (aplica `.toUtc()` a todas las fechas).
- `extension CategoryToCompanion on Category { CategoriesCompanion toCompanion() }` (o `toInsertable()`).
- Igual para `MoneyTransaction` ↔ `TransactionRow` y `Budget` ↔ `BudgetRow`.

## Paso 7 · Repositorios Drift

Todos reciben `AppDatabase`, `Clock` e `IdGenerator` por constructor y envuelven cada operación en `guardStorage`.

### 7.1 `features/categories/data/drift_category_repository.dart`

- `watchAll`/`getAll`: `deletedAt IS NULL`, orden `type` asc (así `expense` va antes que `income`), luego `lower(name)` asc
  (`OrderingTerm(expression: c.name.lower())`).
- `create`: `validateCategoryForm` → si hay errores lanza `ValidationError` del primer campo; normaliza el nombre;
  comprueba duplicado activo (`lower(name) = lower(?) AND type = ? AND archived_at IS NULL AND deleted_at IS NULL`)
  → `DuplicateError('category')`; inserta con `id = ids.newId()`, `isDefault: false`, `createdAt = updatedAt = now`.
  El índice único es la segunda barrera (se traduce a `DuplicateError` en `guardStorage`).
- `update`: carga la actual (si no existe o está borrada → `NotFoundError`); si cambia `type` →
  `ValidationError('type', notAllowed)`; valida; comprueba duplicado excluyendo su propio id; guarda con `updatedAt = now`.
- `archive` / `unarchive` / `softDelete`: actualizan `archivedAt`/`deletedAt` y `updatedAt`. `unarchive` comprueba
  duplicado activo antes.
- `insertIfAbsent`: `into(categories).insert(companion, mode: InsertMode.insertOrIgnore)` dentro de un `batch`.

### 7.2 `features/transactions/data/drift_transaction_repository.dart`

- `watchBetween(from, to)`: `deletedAt IS NULL AND occurred_on >= from AND occurred_on < to`, orden `occurred_on desc,
  created_at desc`. Con columnas con conversor, compara contra el valor SQL: `t.occurredOn.isBiggerOrEqualValue(from.toIso())`.
- `getBetween(from?, to?)`: igual con límites opcionales.
- `create`: `assertValidDraft`; busca la categoría no borrada (`NotFoundError('category', id)` si no); si
  `category.type != draft.type` → `CategoryTypeMismatchError`; inserta con `note: normalizeNote(draft.note)`.
- `update`: la transacción debe existir y no estar borrada; mismas comprobaciones; `updatedAt = now` (conserva `createdAt`).
- `softDelete` / `restore`: ponen/quitan `deletedAt` y actualizan `updatedAt`.
- `countByCategory`:
  ```dart
  final count = transactions.id.count();
  final query = selectOnly(transactions)
    ..addColumns([count])
    ..where(transactions.categoryId.equals(categoryId) & transactions.deletedAt.isNull());
  return (await query.getSingle()).read(count) ?? 0;
  ```

### 7.3 `features/budgets/data/drift_budget_repository.dart`

- `watchMonth` / `getMonth`: `month = ?` (valor SQL `month.toFirstDayIso()`) y `deletedAt IS NULL`.
- `setLimit`: `limitMinor <= 0` → `ValidationError('limit', mustBePositive)`; categoría no borrada (si no, `NotFoundError`);
  categoría de ingreso → `CategoryTypeMismatchError`; dentro de `transaction(...)`: si existe presupuesto activo
  para (categoría, mes) actualiza `limitMinor` y `updatedAt`; si no, inserta uno nuevo.
- `softDelete`, `softDeleteByCategory`: tombstone + `updatedAt`.

### 7.4 `lib/core/database/drift_local_store.dart`

`DriftLocalStore implements LocalStore`: `runInTransaction` → `db.transaction(action)`; `eraseAll` → dentro de una
transacción borra `transactions`, `budgets`, `categories` y `sync_state` (en ese orden por las FKs).

## Paso 8 · Providers (`lib/core/di/repository_providers.dart`)

Añade (de momento siempre Drift; la fase 05 añade el cambio a mock según `AppMode`):

```dart
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) => DriftCategoryRepository(
      ref.watch(appDatabaseProvider), clock: ref.watch(clockProvider), ids: ref.watch(idGeneratorProvider));
// transactionRepository, budgetRepository y localStore igual.
```

Y en `lib/core/di/use_case_providers.dart` providers (`keepAlive`) para los casos de uso con dependencias:
`seedDefaultCategories`, `deleteOrArchiveCategory`, `copyBudgetsFromPreviousMonth`, `exportTransactionsCsv`.
Los casos de uso puros sin dependencias (`GetMonthSummary`, `GetMonthlyTrend`, `GetBudgetProgress`) se instancian
con `const` donde se usen.

## Paso 9 · Tests (Drift en memoria)

`test/helpers/test_database.dart`:

```dart
AppDatabase createTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
}
```

(Si el constructor de `DatabaseConnection` difiere en tu versión, usa `AppDatabase(NativeDatabase.memory())`.)
Cada test crea su base en `setUp` y la cierra en `tearDown`. Usa `FixedClock` y `SequentialIdGenerator`, y avanza
el reloj (`clock.now = clock.now.add(...)`) para comprobar `updatedAt`.

| Archivo | Casos mínimos |
|---|---|
| `test/core/database/storage_guard_test.dart` | `SqliteException` 2067 → `DuplicateError`; 787 → `NotFoundError`; otro → `StorageError`; envuelta en `DriftRemoteException` también; `DomainError` se relanza tal cual. |
| `test/core/database/app_database_test.dart` | `PRAGMA foreign_keys` devuelve 1; insertar un movimiento con categoría inexistente falla; los 4 tablas existen. |
| `test/features/categories/data/drift_category_repository_test.dart` | `create` + `watchAll` emite la nueva; duplicado con distinto casing → `DuplicateError`; duplicado de una **archivada** sí se permite; `unarchive` con conflicto → `DuplicateError`; cambiar tipo → `ValidationError`; `softDelete` la saca de `watchAll`; `insertIfAbsent` dos veces no duplica y respeta ids/fechas; `updatedAt` cambia con el reloj. |
| `test/features/transactions/data/drift_transaction_repository_test.dart` | categoría de otro tipo → `CategoryTypeMismatchError`; categoría borrada → `NotFoundError`; monto 0 → `ValidationError`; nota `"  "` → `null`; `watchBetween` incluye `from`, excluye `toExclusive`, orden correcto, excluye borrados; `softDelete` + `restore`; `countByCategory` ignora borrados; `getBetween(null, null)` devuelve todo; el stream emite tras `create`/`update`/`softDelete`. |
| `test/features/budgets/data/drift_budget_repository_test.dart` | `setLimit` crea y luego actualiza **el mismo id**; categoría de ingreso → `CategoryTypeMismatchError`; límite 0 → `ValidationError`; `softDeleteByCategory`; `watchMonth` solo del mes pedido; tras borrar, `setLimit` crea uno nuevo sin chocar con el índice parcial. |
| `test/core/database/drift_local_store_test.dart` | `runInTransaction` hace rollback si la acción lanza; `eraseAll` deja las 4 tablas vacías. |
| `test/features/categories/domain/…` (integración) | `DeleteOrArchiveCategory` con repos Drift reales: con movimientos archiva; sin movimientos borra categoría y sus presupuestos. |

## Paso 10 · Cierre

- Verifica que `drift_schemas/centavo/drift_schema_v1.json` está commiteado.
- `00-guia-general.md` §3.3 (el CI instala `libsqlite3-dev`; si los tests de Drift fallan solo en CI por la librería
  nativa, revisa ese paso).

---

## Criterios de terminado

- [ ] `AppDatabase` v1 con `categories`, `transactions`, `budgets`, `sync_state`, índices únicos parciales y FKs activas.
- [ ] Fechas guardadas como texto ISO en UTC; `LocalDate`/`YearMonth` como texto ISO.
- [ ] Repositorios Drift de categorías, movimientos y presupuestos + `DriftLocalStore`, todos con `guardStorage`.
- [ ] Ninguna excepción de SQLite/Drift sale de `data/` sin traducir.
- [ ] Snapshot `drift_schema_v1.json` generado y commiteado.
- [ ] Tests de repositorio con Drift en memoria en verde; `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
