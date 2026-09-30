# Fase 08 · Presupuestos

**Rama:** `feat/fase-08-presupuestos`
**Objetivo:** pantalla de presupuestos del mes con gastado / límite / restante, barra y estado por categoría, gasto
sin presupuesto, formulario para fijar o quitar un límite y *Copy from previous month*.
**Referencias:** definición §3.1 F4, §5.1 flujo C, §5.2, §6.3 (`GetBudgetProgress`, `CopyBudgetsFromPreviousMonth`), §12.1 (Budgets).
**Requisitos previos:** fase 07 terminada.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Providers (`lib/features/budgets/presentation/budgets_providers.dart`)

```dart
@riverpod
Stream<List<Budget>> monthBudgets(Ref ref, YearMonth month) => ref.watch(budgetRepositoryProvider).watchMonth(month);

@riverpod
Future<BudgetProgressReport> budgetProgress(Ref ref, YearMonth month) async {
  final budgets = await ref.watch(monthBudgetsProvider(month).future);
  final transactions = await ref.watch(monthTransactionsProvider(month).future);
  final categories = await ref.watch(categoriesProvider.future);
  return const GetBudgetProgress()(month: month, budgets: budgets, transactions: transactions,
      categories: categories, currencyCode: ref.watch(settingsControllerProvider).currencyCode);
}

/// CA4 of F4: current month has no budgets and the previous one does.
@riverpod
Future<bool> canCopyPreviousBudgets(Ref ref, YearMonth month) async {
  final current = await ref.watch(monthBudgetsProvider(month).future);
  if (current.isNotEmpty) return false;
  final previous = await ref.watch(monthBudgetsProvider(month.previous).future);
  return previous.isNotEmpty;
}

@riverpod
class BudgetFormController extends _$BudgetFormController { … }   // save(categoryId, month, limitMinor), remove(budgetId)

@riverpod
class CopyBudgetsController extends _$CopyBudgetsController { … } // copy(month) → int
```

`budgetProgressProvider(month)` también lo usará el dashboard (fase 09).

## Paso 2 · Rutas

Sub-ruta de `/budgets` a pantalla completa:

```dart
GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (_, state) => BudgetFormScreen(
  categoryId: state.uri.queryParameters['category'] ?? '',
  month: YearMonth.parse(state.uri.queryParameters['month'] ?? ''),   // invalid → show "not found" state
)),
```

Construye la URL con un helper: `Routes.budgetEditFor(String categoryId, YearMonth month)` →
`/budgets/edit?category=<id>&month=2026-10`. Protege el `parse` con `try/catch` y muestra el estado "not found" si falla.

## Paso 3 · `budgets_screen.dart`

- `AppBar` "Budgets" + `MonthSelector` (`maxMonth` = mes actual **+ 1**, para planificar el siguiente).
- `AsyncStateView` sobre `budgetProgressProvider(selectedMonth)`:
  - Carga: skeleton (una tarjeta + 4 filas).
  - Error: `ErrorState` + *Retry* (invalida `monthBudgetsProvider(month)`).
  - **Con presupuestos**:
    1. Tarjeta resumen (key `budgets-summary`): "Spent $X of $Y" con barra total y "Unbudgeted spending: $Z"
       (CA3 de F4: el total solo suma categorías con presupuesto).
    2. Una tarjeta por `BudgetLine` (key `budget-line-<categoryId>`): `CategoryAvatar`, nombre, "`$spent` of `$limit`",
       `LinearProgressIndicator(value: (basisPoints / 10000).clamp(0, 1))` con el color del estado, y a la derecha
       "`$remaining` left" o "Over by `$abs(remaining)`". Debajo, la etiqueta del estado en texto (no solo color):
       *On track* / *Near limit* / *Over budget*. Tap → formulario.
    3. Sección "Not budgeted" con `categoriesWithoutBudget`: fila con avatar, nombre y botón *Set budget*
       (key `budget-set-<categoryId>`).
  - **Sin presupuestos** en el mes: `EmptyState` "No budgets for October 2026" con:
    - *Copy from previous month* (key `budgets-copy-previous`) solo si `canCopyPreviousBudgets` es `true` → copia →
      SnackBar "Copied N budgets".
    - Debajo, igualmente, la sección "Not budgeted" para fijar uno (*Set a budget*).
- Colores por estado (de `CentavoColors`): `onTrack` → `onTrack`, `warning` → `warning`, `exceeded` → `exceeded`.
- Respeta el padding inferior para el FAB.

## Paso 4 · `budget_form_screen.dart` (patrón de formulario de la fase 06)

- Carga la categoría con `categoryByIdProvider(categoryId)` y el presupuesto activo con
  `budgetRepository.findActive(categoryId, month)` (un `FutureProvider` propio). Categoría inexistente, borrada o de
  ingreso → estado "not found".
- Cabecera: `CategoryAvatar` + nombre + mes (`October 2026`).
- Campo *Monthly limit* (key `budget-limit`), mismo estilo y formateadores que el monto del movimiento; prellenado
  con el límite actual si existe.
- Informativo debajo: "Spent so far: $X" (del `budgetProgressProvider` o sumando `monthTransactions`).
- *Save* (key `budget-save`) → `validateBudgetForm` → `setLimit` → `pop`.
- Si ya existe presupuesto, acción *Remove budget* (key `budget-remove`) con confirmación → `softDelete` → `pop`
  + SnackBar "Budget removed".

## Paso 5 · Textos

`budgetsTitle`, `spentOfLimit` (placeholders `{spent}`, `{limit}`), `leftAmount` (`{amount}`), `overBy` (`{amount}`),
`statusOnTrack` "On track", `statusWarning` "Near limit", `statusExceeded` "Over budget", `unbudgetedSpending`
(`{amount}`), `notBudgeted`, `setBudget`, `setABudget`, `noBudgetsInMonth` (`{month}`), `copyFromPreviousMonth`,
`copiedBudgets` (plural `{count}`), `monthlyLimit`, `spentSoFar` (`{amount}`), `removeBudget`, `removeBudgetTitle`,
`budgetRemoved`.

## Paso 6 · Tests

| Archivo | Casos mínimos |
|---|---|
| `test/features/budgets/presentation/budgets_screen_test.dart` | Mes vacío sin presupuestos previos: no aparece *Copy*; con presupuestos en el mes anterior: aparece y al pulsarlo se crean y se muestra el SnackBar; líneas con las etiquetas *On track* / *Near limit* / *Over budget* según los montos; "Unbudgeted spending" correcto; categorías de ingreso nunca aparecen; *Next* permite ir al mes siguiente pero no al de después. |
| `test/features/budgets/presentation/budget_form_screen_test.dart` | *Set budget* en Food → guardar 600 → la línea aparece; editar cambia el límite (mismo id); límite vacío/0 → error; *Remove budget* la quita y Food vuelve a "Not budgeted"; `month` inválido en la URL → estado "not found". |
| `test/features/budgets/presentation/budgets_demo_test.dart` | En demo, mes actual: Coffee aparece *Over budget* y Entertainment *Near limit*. |
| `test/features/budgets/presentation/budget_reactivity_test.dart` | Registrar un gasto en Food desde el formulario de movimientos actualiza el "spent" de su línea sin recargar. |

## Paso 7 · Verificación manual en Android

Flujo C completo en local: fijar Food = 600 → registrar gastos → ver cómo cambia la barra y el estado → ir al mes
siguiente → *Copy from previous month*. En demo, comprobar los estados de Coffee y Entertainment. Modo oscuro.

## Paso 8 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] F4 CA1–CA4: un presupuesto por categoría y mes; estados `onTrack`/`warning`/`exceeded` con color **y** texto; total solo de categorías con presupuesto + "Unbudgeted"; *Copy from previous month* cuando corresponde.
- [ ] Formulario para fijar, editar y quitar un límite; estados de carga, vacío y error.
- [ ] La pantalla reacciona sola a nuevos movimientos.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
