# Fase 07 · Movimientos

**Rama:** `feat/fase-07-movimientos`
**Objetivo:** lista de movimientos del mes agrupada por día con filtros por tipo y categoría, formulario de
crear/editar, borrado con confirmación y *Undo*, y botón `+` flotante en las tabs principales.
**Referencias:** definición §3.1 F2, §5.1 flujo B, §5.2, §12.1 (Transactions list, Transaction form).
**Requisitos previos:** fase 06 terminada.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · SnackBars que sobreviven a la navegación

Crea `lib/core/presentation/root_scaffold_messenger.dart` con
`final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();` y pásalo a
`MaterialApp.router(scaffoldMessengerKey: rootScaffoldMessengerKey, …)`. Todos los SnackBars de la app se muestran
con `rootScaffoldMessengerKey.currentState?.showSnackBar(...)` (así el *Undo* sigue visible tras cerrar un formulario).

## Paso 2 · Providers (`lib/features/transactions/presentation/transactions_providers.dart`)

```dart
@riverpod
Stream<List<MoneyTransaction>> monthTransactions(Ref ref, YearMonth month) =>
    ref.watch(transactionRepositoryProvider).watchBetween(month.firstDay, month.firstDayOfNextMonth);

@freezed
abstract class TransactionFilter with _$TransactionFilter {
  const factory TransactionFilter({TransactionType? type, String? categoryId}) = _TransactionFilter;
  const TransactionFilter._();
  bool get isActive => type != null || categoryId != null;
}

@Riverpod(keepAlive: true)
class TransactionFilterController extends _$TransactionFilterController {
  @override TransactionFilter build() => const TransactionFilter();
  void setType(TransactionType? type) => state = TransactionFilter(type: type);   // changing type resets category
  void setCategory(String? categoryId) => state = state.copyWith(categoryId: categoryId);
  void clear() => state = const TransactionFilter();
}

@riverpod
Future<List<TransactionDayGroup>> transactionGroups(Ref ref) async {
  final month = ref.watch(selectedMonthProvider);
  final filter = ref.watch(transactionFilterControllerProvider);
  final transactions = await ref.watch(monthTransactionsProvider(month).future);
  final categories = await ref.watch(categoriesProvider.future);
  return groupTransactionsByDay(transactions: transactions, categories: categories, filter: filter,
      currencyCode: ref.watch(settingsControllerProvider).currencyCode);
}

@riverpod
Future<MoneyTransaction?> transactionById(Ref ref, String id) => ref.watch(transactionRepositoryProvider).findById(id);
```

> Nota Riverpod: `ref.watch(provider.future)` dentro de un provider asíncrono se recalcula cada vez que el stream
> emite, así que la lista se actualiza sola tras crear/editar/borrar (CA4 de F2).

## Paso 3 · Agrupación (`transaction_grouping.dart`, función pura en `presentation/`)

```dart
@immutable
class TransactionListItem { final MoneyTransaction transaction; final Category? category; }

@immutable
class TransactionDayGroup {
  final LocalDate day;
  final List<TransactionListItem> items;   // same order as the repository (createdAt desc)
  final Money income; final Money expense;
}

List<TransactionDayGroup> groupTransactionsByDay({required List<MoneyTransaction> transactions,
    required List<Category> categories, required TransactionFilter filter, required String currencyCode});
```

Aplica el filtro (tipo y categoría), agrupa por `occurredOn` (días más recientes primero) y calcula totales del día.

## Paso 4 · Botón `+` en el shell

En `AppShell`, `floatingActionButton` visible solo en las ramas 0, 1 y 2 (Dashboard, Transactions, Budgets):
`FloatingActionButton` con `Icons.add` (key `fab-add-transaction`, `Semantics(identifier: 'fab-add-transaction')`,
tooltip "Add transaction") → `context.push('${Routes.transactionNew}?type=expense')`.

## Paso 5 · Rutas

Dentro de la rama Transactions, como sub-rutas de `/transactions`, **a pantalla completa** (sin barra inferior):

```dart
GoRoute(
  path: Routes.transactions,
  builder: (_, _) => const TransactionsScreen(),
  routes: [
    GoRoute(path: 'new', parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TransactionFormScreen(initialType: _parseType(state.uri.queryParameters['type']))),
    GoRoute(path: ':id', parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TransactionFormScreen(transactionId: state.pathParameters['id'])),
  ],
),
```

`new` va antes de `:id`. Un `type` desconocido o ausente → `expense`.

## Paso 6 · `transactions_screen.dart`

- `AppBar` "Transactions" y debajo `MonthSelector` ligado a `selectedMonthProvider`
  (`maxMonth` = mes de `clock.today()`).
- Fila de filtros:
  - `ChoiceChip`s *All* / *Expenses* / *Income* (keys `filter-type-all`, `filter-type-expense`, `filter-type-income`).
  - `ActionChip`/`InputChip` de categoría (key `filter-category`): abre un `showModalBottomSheet` con *All categories*
    y la lista de categorías (del tipo filtrado, o todas; activas y archivadas) → `setCategory`.
  - *Clear* (key `filter-clear`) visible solo si `filter.isActive`.
- Cuerpo: `AsyncStateView` sobre `transactionGroupsProvider`:
  - Carga: `SkeletonList`.
  - Error: `ErrorState` con *Retry* → `ref.invalidate(monthTransactionsProvider(month))`.
  - Vacío **sin** filtros: `EmptyState` "No transactions in October 2026" + *Add your first transaction* → formulario.
  - Vacío **con** filtros: `EmptyState` "No results" + *Clear filters*.
  - Datos: `ListView.builder` sobre una lista aplanada (cabecera de día + filas). Cabecera: fecha
    (`DateFormat('EEE, MMM d', 'en_US')`) y a la derecha el neto del día. Fila (key `tx-row-<id>`): `CategoryAvatar`,
    nombre de categoría (o "Unknown category"), nota como subtítulo, `MoneyText` con signo (`+` verde ingreso,
    `−` rojo gasto). Tap → `Routes.transactionEdit(id)`.
  - Deja espacio inferior para que el FAB no tape la última fila (`padding: EdgeInsets.only(bottom: 88)`).
- Cada fila es `Dismissible` (deslizar a la izquierda) con `confirmDismiss` → diálogo de confirmación → borrado con
  *Undo* (paso 8).

## Paso 7 · `transaction_form_screen.dart` (patrón de formulario de la fase 06)

- `AppBar`: "New transaction" / "Edit transaction"; al editar, acción *Delete* (key `tx-delete`).
- Campos:
  1. Tipo: `SegmentedButton<TransactionType>` (keys `tx-type-expense`, `tx-type-income`). Cambiar el tipo limpia la
     categoría si ya no coincide (CA2 de F2).
  2. Monto (key `tx-amount`, `Semantics(identifier: 'tx-amount')`): `TextField` con
     `keyboardType: TextInputType.numberWithOptions(decimal: true)`, `inputFormatters` que solo permiten dígitos,
     `.` y `,`, prefijo con el símbolo de la moneda, fuente grande Manrope con cifras tabulares, `autofocus` al crear.
     Al editar se prellena con `formatMinorPlain`.
  3. Categoría: `Wrap` de `ChoiceChip` con `CategoryAvatar` pequeño, solo categorías **activas del tipo**
     (`activeCategoriesOfTypeProvider`). Al editar un movimiento cuya categoría está archivada, añade también esa
     categoría. Key por chip: `tx-category-<id>`; `Semantics(identifier: 'tx-category-<nombre en minúsculas>')`.
     Si no hay categorías del tipo: texto + botón *Create category* → `Routes.categoryNew?type=…`.
  4. Fecha (key `tx-date`): `ListTile` con la fecha formateada → `showDatePicker(firstDate: DateTime(2000),
     lastDate: DateTime(today.year + 1, 12, 31))`. Por defecto `clock.today()`.
  5. Nota (key `tx-note`): `TextField` `maxLength: 140`, opcional.
- *Save* (key `tx-save`, `Semantics(identifier: 'tx-save')`): `validateTransactionForm` → `TransactionFormController.save`.
  Crear → `create(TransactionDraft)`; editar → `update(existing.copyWith(...))`. Al terminar, `pop`.
- Estados: al editar, carga con `AsyncStateView` sobre `transactionByIdProvider(id)`; `null` → "This item no longer exists".
  Durante el guardado, botón en progreso. `StorageError` → SnackBar.

## Paso 8 · Borrar con *Undo* (CA3 de F2)

`lib/features/transactions/presentation/delete_transaction.dart`:

```dart
/// Asks for confirmation, soft-deletes and shows a 4 s SnackBar with Undo. Returns true if deleted.
Future<bool> confirmAndDeleteTransaction(BuildContext context, WidgetRef ref, String id);
```

- Diálogo: "Delete transaction?" / *Cancel* / *Delete* (key `tx-delete-confirm`).
- `softDelete(id)` → SnackBar "Transaction deleted" con `SnackBarAction` *Undo* (`duration: 4 s`) → `restore(id)`.
- Lo usan el `Dismissible` de la lista y la acción *Delete* del formulario (que además hace `pop`).

## Paso 9 · Textos

Añade a `app_en.arb`: `transactionsTitle`, `newTransaction`, `editTransaction`, `amount`, `category`, `date`, `note`,
`noteHint` ("Optional"), `filterAll`, `filterExpenses`, `filterIncome`, `allCategories`, `clearFilters`,
`noTransactionsInMonth` (con placeholder `{month}`), `addFirstTransaction`, `noResults`, `unknownCategory`,
`noCategoriesOfType`, `createCategory`, `deleteTransactionTitle`, `transactionDeleted`, `addTransaction`.

## Paso 10 · Tests

| Archivo | Casos mínimos |
|---|---|
| `test/features/transactions/presentation/transaction_grouping_test.dart` | Agrupa por día desc; totales por día; filtro por tipo; filtro por categoría; categoría inexistente → `category: null`. |
| `test/features/transactions/presentation/transactions_screen_test.dart` | Vacío sin filtros muestra *Add your first transaction*; con filtros muestra *Clear filters*; cambiar de mes con `MonthSelector` cambia la lista; *Next* deshabilitado en el mes actual; error del stream muestra *Retry*. |
| `test/features/transactions/presentation/transaction_form_screen_test.dart` | Crear gasto de `12.50` en Food → aparece en la lista con `−$12.50`; monto vacío/`0`/`1.234` muestra el error correcto; cambiar a *Income* quita la categoría de gasto seleccionada; editar prellena y guarda; moneda CLP rechaza decimales. |
| `test/features/transactions/presentation/delete_transaction_test.dart` | Deslizar → confirmar → desaparece → *Undo* → vuelve; cancelar el diálogo no borra. |
| `test/features/transactions/presentation/demo_add_expense_test.dart` | En demo: FAB → gasto de 12.50 en Coffee → aparece en la lista del mes actual. |

## Paso 11 · Verificación manual en Android

En local y en demo: crear, editar, filtrar, borrar con *Undo*. Activa **modo avión** y repite (CA4 de F2).
Prueba con la moneda CLP (ajusta en `SharedPreferences` borrando datos y eligiendo CLP en el onboarding).

## Paso 12 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] F2 CA1–CA4 cumplidos (monto > 0 con decimales según moneda; categoría del mismo tipo; borrar con confirmación y *Undo* ~4 s; funciona sin red y se refleja al instante).
- [ ] Lista agrupada por día, filtrada por mes, tipo y categoría; estados de carga, vacío (con y sin filtros) y error.
- [ ] FAB `+` en Dashboard, Transactions y Budgets.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
