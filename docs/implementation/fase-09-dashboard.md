# Fase 09 · Dashboard

**Rama:** `feat/fase-09-dashboard`
**Objetivo:** dashboard del mes con tarjetas de Ingresos / Gastos / Balance, dona de gastos por categoría (top 5 +
Others), barras de ingreso vs. gasto de los últimos 6 meses y resumen de los 3 presupuestos más cerca de su límite.
**Referencias:** definición §3.1 F5, §6.3 (`GetMonthSummary`, `GetMonthlyTrend`), §11 (gráficas en modo oscuro), §12.1 (Dashboard).
**Requisitos previos:** fase 08 terminada.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Revisa la API de `fl_chart` instalada

La API de `fl_chart` cambia entre versiones (por ejemplo `SideTitleWidget(meta: …)` vs. `axisSide:`, o
`swapAnimationDuration` vs. `duration`). Antes de escribir código, abre los ejemplos de la versión instalada
(`~/.pub-cache/hosted/pub.dev/fl_chart-<versión>/example/`) y usa esa sintaxis. Anota la versión en la bitácora.

## Paso 2 · Providers (`lib/features/dashboard/presentation/dashboard_providers.dart`)

```dart
@riverpod
Future<MonthSummary> monthSummary(Ref ref, YearMonth month) async {
  final transactions = await ref.watch(monthTransactionsProvider(month).future);
  final categories = await ref.watch(categoriesProvider.future);
  return const GetMonthSummary()(month: month, transactions: transactions, categories: categories,
      currencyCode: ref.watch(settingsControllerProvider).currencyCode);
}

@riverpod
Stream<List<MoneyTransaction>> rangeTransactions(Ref ref, LocalDate from, LocalDate toExclusive) =>
    ref.watch(transactionRepositoryProvider).watchBetween(from, toExclusive);

@riverpod
Future<List<MonthTotals>> monthlyTrend(Ref ref, YearMonth endMonth) async {
  final start = endMonth.addMonths(-5);
  final transactions = await ref.watch(rangeTransactionsProvider(start.firstDay, endMonth.firstDayOfNextMonth).future);
  return const GetMonthlyTrend()(endMonth: endMonth, transactions: transactions,
      currencyCode: ref.watch(settingsControllerProvider).currencyCode);
}
```

El resumen de presupuestos reutiliza `budgetProgressProvider(month)` (fase 08) y toma `lines.take(3)` (ya vienen
ordenadas por porcentaje descendente).

## Paso 3 · `dashboard_screen.dart`

`AppBar` "Dashboard" + `MonthSelector` (`maxMonth` = mes actual). Cuerpo en `CustomScrollView`/`ListView` con cuatro
secciones independientes, cada una con su propio `AsyncStateView` (si una falla, las demás se siguen viendo).
Padding inferior para el FAB. `RefreshIndicator` no es necesario (los datos son reactivos).

### 3.1 Tarjetas del mes (`summary_cards.dart`)

- Tres tarjetas: *Income* (color `income`), *Expenses* (color `expense`), *Balance* (verde si ≥ 0, rojo si < 0).
  Montos con `MoneyText` grande (Manrope, cifras tabulares).
- Keys y `Semantics(identifier:)`: `dashboard-income`, `dashboard-expense`, `dashboard-balance` (Maestro lee el total de gastos).
- Carga: tres `SkeletonBox`. Error: `ErrorState` + *Retry*.
- **Mes sin movimientos** (`summary.isEmpty`, CA2 de F5): en lugar de tarjetas y dona se muestra `EmptyState`
  "No transactions in October 2026" + *Add transaction* (key `dashboard-add-first`) → formulario de nuevo movimiento.

### 3.2 Dona de gastos por categoría (`expense_donut.dart`)

- `PieChart` con una sección por `CategorySlice`: color `context.colors.category(slice.color)`; el slice "Others"
  (o categoría inexistente) usa `colorScheme.outline`. `centerSpaceRadius` ≈ 56, `sectionsSpace` 2, sin títulos dentro
  de las secciones.
- En el centro: "Spent" y el total de gastos.
- Leyenda debajo: por slice, `CategoryAvatar` pequeño, nombre ("Others" / "Unknown category"), monto y porcentaje
  (`basisPoints / 100` con 0 decimales, p. ej. "34 %").
- Si el mes tiene ingresos pero **ningún** gasto: texto "No expenses this month" en lugar de la dona.
- `Semantics(label: …)` en el gráfico con un resumen textual ("Expenses by category: Food 34 %, …") para lectores de pantalla.

### 3.3 Barras de 6 meses (`trend_bar_chart.dart`)

- `BarChart` con 6 grupos (uno por `MonthTotals`), dos barras por grupo: ingreso (`income`) y gasto (`expense`),
  esquinas redondeadas, ancho ~8.
- Eje X: mes abreviado (`DateFormat.MMM('en_US')`); el mes seleccionado en negrita.
- Eje Y: 3–4 marcas con `NumberFormat.compactSimpleCurrency(locale: 'en_US', name: currencyCode)`.
  Los valores del gráfico se pasan en unidades mayores (`amountMinor / 10^minorUnits`) — `double` **solo para dibujar**.
- Líneas de cuadrícula horizontales con `CentavoColors.chartGrid`; textos con `onSurfaceVariant`.
- Tooltip al tocar: "Oct · Income $3,650.00 · Expenses $1,820.35".
- Si los 6 meses son cero: texto "Not enough data yet".

### 3.4 Resumen de presupuestos (`budget_summary_card.dart`)

- Título "Budgets" + acción *See all* (key `dashboard-see-budgets`) → `StatefulNavigationShell.of(context).goBranch(2)`
  (o `context.go(Routes.budgets)`).
- Hasta 3 filas: avatar, nombre, barra fina con el color del estado y "`$spent` / `$limit`".
- Sin presupuestos en el mes: texto "No budgets this month" + *Set up budgets* → tab Budgets.

## Paso 4 · Gráficas y tema

- Ningún color fijo: todo sale de `Theme.of(context).colorScheme` y `context.colors` (CA1 de F10: las gráficas
  cambian con el modo oscuro).
- Envuelve cada gráfico en un `SizedBox` de alto fijo (dona ~200, barras ~220) para evitar saltos de layout.

## Paso 5 · Textos

`dashboardTitle`, `incomeLabel`, `expensesLabel`, `balanceLabel`, `spentLabel`, `others`, `noExpensesThisMonth`,
`lastSixMonths`, `notEnoughData`, `budgetsCardTitle`, `seeAll`, `noBudgetsThisMonth`, `setUpBudgets`, `addTransaction`,
`chartTooltip` (placeholders), `expensesByCategorySemantics`.

## Paso 6 · Tests

| Archivo | Casos mínimos |
|---|---|
| `test/features/dashboard/presentation/dashboard_providers_test.dart` | `monthSummaryProvider` y `monthlyTrendProvider` con repos mock: totales exactos; la tendencia cambia tras crear un movimiento en un mes anterior. |
| `test/features/dashboard/presentation/dashboard_screen_test.dart` | Mes vacío → CTA *Add transaction*; con datos, las tarjetas muestran exactamente la suma (CA1): crea `12.50` + `7.25` de gasto → "$19.75"; balance negativo en rojo; solo ingresos → "No expenses this month"; *See all* navega a Budgets. |
| `test/features/dashboard/presentation/dashboard_demo_test.dart` | En demo: la leyenda tiene 6 entradas (top 5 + Others) si hay más de 5 categorías con gasto; el gráfico de barras recibe 6 grupos; el resumen de presupuestos muestra Coffee primero (*Over budget*). |
| `test/features/dashboard/presentation/dashboard_dark_mode_test.dart` | Con `ThemeMode.dark` el dashboard se construye sin excepciones y los colores de las secciones de la dona son los de la variante oscura. |

## Paso 7 · Verificación manual en Android

En demo y en local: revisar las cuatro secciones, cambiar de mes (el mes vacío muestra el CTA), tocar las barras
(tooltip), alternar claro/oscuro. Toma una captura de cada modo (`adb exec-out screencap -p > …`) y revísala: textos
legibles, sin desbordes (`RenderFlex overflowed`) en un emulador pequeño (p. ej. 360×640 dp).

## Paso 8 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] F5 CA1–CA2: totales exactos en centavos; mes sin datos con estado vacío y CTA.
- [ ] Dona top 5 + Others con leyenda; barras de 6 meses con meses vacíos en cero; resumen de 3 presupuestos con enlace.
- [ ] Gráficas con colores del tema, correctas en modo oscuro; sin overflows en pantallas pequeñas.
- [ ] Cada sección con carga, vacío y error propios.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
