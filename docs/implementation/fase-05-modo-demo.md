# Fase 05 · Modo demo y repositorios mock

**Rama:** `feat/fase-05-modo-demo`
**Objetivo:** repositorios mock en memoria **igual de estrictos** que los de Drift, dataset de demo determinista de
~3 meses, cambio automático de todos los repositorios según `AppMode` y banner persistente de demo.
**Referencias:** definición §2 (modo Demo), §3.1 F9, §5.1 flujo F, §8.3 ("Modo demo"), §12.2 · `CLAUDE.md` reglas 4 y 5.
**Requisitos previos:** fase 04 terminada.

> Al terminar: desde la bienvenida provisional, *Explore demo* activa el modo demo (banner visible en todas las
> pantallas); *Exit demo* vuelve a la bienvenida sin haber tocado la base Drift real. Las pantallas con datos llegan
> en las fases 06–09; aquí se comprueba con tests.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Almacén en memoria (`lib/features/demo/data/mock_data_store.dart`)

```dart
enum MockTable { categories, transactions, budgets }

/// In-memory tables shared by all mock repositories, with change notifications that mimic Drift streams.
class MockDataStore {
  MockDataStore({List<Category>? categories, List<MoneyTransaction>? transactions, List<Budget>? budgets})
      : categories = [...?categories], transactions = [...?transactions], budgets = [...?budgets];

  final List<Category> categories;
  final List<MoneyTransaction> transactions;
  final List<Budget> budgets;
  final Map<String, String> syncState = {};
  final _changes = StreamController<MockTable>.broadcast();

  void notify(MockTable table) => _changes.add(table);

  /// Emits the current value immediately and again after every change of [table].
  Stream<T> watch<T>(MockTable table, T Function() read) async* {
    yield read();
    yield* _changes.stream.where((t) => t == table).map((_) => read());
  }

  Future<void> dispose() => _changes.close();
}
```

Los repositorios mock devuelven **copias** (`List.unmodifiable`) para que la UI nunca mute el almacén.

## Paso 2 · Repositorios mock

Uno por feature, en su carpeta `data/`: `mock_category_repository.dart`, `mock_transaction_repository.dart`,
`mock_budget_repository.dart`, y `lib/features/demo/data/mock_local_store.dart`.

- Reciben `MockDataStore`, `Clock` e `IdGenerator`.
- Implementan **exactamente las mismas reglas** que los de Drift (validación, duplicados insensibles a mayúsculas,
  tipo de categoría, `NotFoundError`, tombstones, orden de resultados, `updatedAt = clock.nowUtc()`). Reutiliza los
  validadores de dominio; no copies lógica de validación.
- Tras cada escritura llaman a `store.notify(<tabla>)`. Crear/editar/borrar un movimiento también afecta a
  presupuestos y dashboard porque esas pantallas observan la tabla `transactions`.
- `MockLocalStore.runInTransaction`: guarda una copia de las tres listas, ejecuta la acción y, si lanza, restaura la
  copia (y notifica las tres tablas) antes de relanzar. `eraseAll`: vacía todo y notifica.

## Paso 3 · Tests de contrato (misma suite para Drift y mock)

Convierte los tests de repositorio de la fase 04 en **suites de contrato** que se ejecutan contra ambas implementaciones:

```dart
// test/features/categories/data/category_repository_contract.dart
typedef CategoryRepositoryFactory = Future<CategoryRepositoryHarness> Function(FixedClock clock);

class CategoryRepositoryHarness {
  CategoryRepositoryHarness({required this.repository, required this.dispose, this.transactions});
  final CategoryRepository repository;
  final TransactionRepository? transactions;
  final Future<void> Function() dispose;
}

void runCategoryRepositoryContract(String implementationName, CategoryRepositoryFactory create) {
  group('$implementationName CategoryRepository', () {
    // the cases from phase 04 go here
  });
}
```

- `drift_category_repository_test.dart` → `runCategoryRepositoryContract('Drift', …)` con `createTestDatabase()`.
- `mock_category_repository_test.dart` → `runCategoryRepositoryContract('Mock', …)` con `MockDataStore()`.
- Igual para movimientos, presupuestos y `LocalStore`. Los casos exclusivos de Drift (FKs, `PRAGMA`, `storage_guard`)
  se quedan en sus archivos propios.

## Paso 4 · Dataset de demo (`lib/features/demo/data/demo_dataset.dart`)

```dart
@immutable
class DemoData {
  const DemoData({required this.categories, required this.transactions, required this.budgets});
  final List<Category> categories; final List<MoneyTransaction> transactions; final List<Budget> budgets;
}

abstract final class DemoDataset {
  static const currencyCode = 'USD';
  static DemoData build(Clock clock);
}
```

### 4.1 Patrón del dataset (determinista; la fase 11 lo replica en `seed.sql`)

Sean `today = clock.today()`, **M0** = mes de `today`, **M1** = M0 − 1, **M2** = M0 − 2.

**Categorías:** las 10 por defecto (`buildDefaultCategories`) + 3 propias:

| id | name | type | icon | color | Notas |
|---|---|---|---|---|---|
| `00000000-0000-4000-8000-0000000000c1` | Coffee | expense | `coffee` | `0xFFB8692E` | |
| `00000000-0000-4000-8000-0000000000c2` | Gym | expense | `fitness` | `0xFFB7791F` | |
| `00000000-0000-4000-8000-0000000000c3` | Old car | expense | `car` | `0xFF546E7A` | `archivedAt` = día 1 de M1, 12:00 UTC |

`createdAt = updatedAt` = día 1 de M2 a las 09:00 UTC para todas.

**Movimientos:** para cada mes (M2, M1, M0) y cada día `d` desde 1 hasta el último día del mes — en **M0 solo hasta
`today.day`** (nunca hay movimientos futuros) — se generan, en este orden:

| Regla | Días | Categoría | Tipo | Monto (minor) | Nota |
|---|---|---|---|---|---|
| Salario | 1 | Salary | income | 320000 | Monthly salary |
| Renta | 1 | Home | expense | 95000 | Rent |
| Ancla (solo M0) | 1 | Coffee | expense | 450 | Latte |
| Ancla (solo M0) | 1 | Entertainment | expense | 1599 | Streaming subscription |
| Transporte | 2, 9, 16, 23, 30 | Transport | expense | 3500 | Transit card top-up |
| Supermercado | 3, 10, 17, 24 | Food | expense | 6240, 4815, 7190, 5530 (por orden) | Groceries |
| Salud | 5 | Health | expense | 3000 | Pharmacy |
| Combustible | 6, 20 | Transport | expense | 4200 | Fuel |
| Ocio | 7 | Entertainment | expense | 2400 | Cinema |
| Gimnasio | 8 | Gym | expense | 4500 | Gym membership |
| Auto (solo M2) | 11 | Old car | expense | 18000 | Car service |
| Compras | 12 | Shopping | expense | 3999 | Clothes |
| Freelance | 15 | Freelance | income | 45000 | Freelance project |
| Otros | 18 | Other | expense | 1500 | Haircut |
| Ocio | 21 | Entertainment | expense | 5500 | Concert |
| Compras | 26 | Shopping | expense | 2450 | Home goods |
| Freelance (solo M1) | 27 | Freelance | income | 28000 | Logo design |
| Café | días de lunes a viernes | Coffee | expense | 420 si `d` es impar, 375 si es par | Morning coffee |

- ids: `demo-tx-<YYYYMM>-<nnn>` con `nnn` secuencial dentro del mes (001, 002…).
- `createdAt = updatedAt` = el día del movimiento a las 12:00 UTC más `nnn` segundos (orden estable).

**Presupuestos** (ids `demo-budget-<YYYYMM>-<categoría en minúsculas>`):

| Categoría | M2 y M1 | M0 |
|---|---|---|
| Food | 60000 | 60000 |
| Transport | 15000 | 15000 |
| Shopping | 20000 | 20000 |
| Entertainment | 12000 | `ceil(gastoEntretenimientoM0 × 100 / 90)` → ~90 % → **warning** |
| Coffee | 8000 | `max(100, gastoCaféM0 × 80 ~/ 100)` → ~125 % → **exceeded** |

(Los "gastos M0" se calculan sumando los movimientos generados para M0. Gracias a los anclas del día 1 siempre son > 0.)

## Paso 5 · Providers según `AppMode` (`lib/core/di/`)

1. En `repository_providers.dart`:

   ```dart
   @Riverpod(keepAlive: true)
   MockDataStore demoDataStore(Ref ref) {
     final data = DemoDataset.build(ref.watch(clockProvider));
     final store = MockDataStore(categories: data.categories, transactions: data.transactions, budgets: data.budgets);
     ref.onDispose(store.dispose);
     return store;
   }

   @Riverpod(keepAlive: true)
   SettingsRepository demoSettingsRepository(Ref ref) => InMemorySettingsRepository(
         const AppSettings(currencyCode: DemoDataset.currencyCode, onboardingCompleted: true),
       );

   @Riverpod(keepAlive: true)
   CategoryRepository categoryRepository(Ref ref) => switch (ref.watch(appModeControllerProvider)) {
         AppMode.local => DriftCategoryRepository(ref.watch(appDatabaseProvider), clock: …, ids: …),
         AppMode.demo => MockCategoryRepository(ref.watch(demoDataStoreProvider), clock: …, ids: …),
       };
   // Same switch for transactionRepository, budgetRepository, localStore and settingsRepository.
   ```

2. En `AppModeController` (fase 02) invalida el estado del demo al entrar y al salir, para que cada sesión de demo
   empiece con datos frescos y nada persista:

   ```dart
   void enterDemo() {
     ref..invalidate(demoDataStoreProvider)..invalidate(demoSettingsRepositoryProvider);
     state = AppMode.demo;
   }
   void exitDemo() {
     state = AppMode.local;
     ref..invalidate(demoDataStoreProvider)..invalidate(demoSettingsRepositoryProvider);
   }
   ```

   (Si el generador no permite referenciar esos providers desde `app_mode_provider.dart` por dependencias circulares
   de imports, mueve `AppModeController` a `repository_providers.dart`.)

3. Reglas que deben cumplirse (definición §8.3):
   - En modo demo **nunca** se construye `appDatabaseProvider` (solo se observa en la rama `local`).
   - `settingsControllerProvider` observa `settingsRepositoryProvider`, así que al cambiar de modo se reconstruye y el
     router se refresca solo.

## Paso 6 · Banner de demo (`lib/features/demo/presentation/demo_banner.dart`)

- Franja con fondo `colorScheme.tertiaryContainer` (o `secondaryContainer`), ícono `science_outlined`, texto
  `demoBannerMessage` ("Demo mode — changes aren't saved") y `TextButton` `exitDemo` ("Exit demo").
- Keys: `demo-banner`, `demo-exit`; y `Semantics(identifier: 'demo-exit')` en el botón (Maestro).
- Se muestra en **todas** las pantallas con `MaterialApp.router(builder: …)`:

  ```dart
  builder: (context, child) {
    final isDemo = ref.watch(appModeControllerProvider) == AppMode.demo;
    if (!isDemo) return child!;
    return Column(children: [
      const DemoBanner(),   // wraps itself in SafeArea(bottom: false)
      Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child!)),
    ]);
  },
  ```

- *Exit demo* → `ref.read(appModeControllerProvider.notifier).exitDemo()`. El redirect del router lleva a `/welcome`
  si no hay onboarding real, o se queda en la app con los datos reales si ya lo había.

## Paso 7 · Botón *Explore demo* en la bienvenida provisional

Añade a `WelcomeScreen` un `OutlinedButton` `exploreDemo` (key `welcome-explore-demo`, `Semantics(identifier: 'welcome-explore-demo')`)
que llama a `enterDemo()`. El redirect lleva a `/dashboard` (en demo `onboarded` es verdadero).

Textos nuevos en `app_en.arb`: `exploreDemo` "Explore demo", `exitDemo` "Exit demo",
`demoBannerMessage` "Demo mode — changes aren't saved".

## Paso 8 · Tests

| Archivo | Casos mínimos |
|---|---|
| `test/features/demo/data/demo_dataset_test.dart` | Con `FixedClock` en varios "hoy" (2026-10-01, 2026-10-15, 2026-10-31, 2027-02-28): 13 categorías (1 archivada); ninguna fecha futura; todos los movimientos apuntan a una categoría existente del mismo tipo; meses completos (M1, M2) con 35–60 movimientos; en M0 `GetBudgetProgress` da al menos un `exceeded` (Coffee) y un `warning` (Entertainment); presupuestos solo en categorías de gasto; ids únicos. |
| `test/features/*/data/mock_*_repository_test.dart` | Suites de contrato del paso 3 contra la implementación mock. |
| `test/features/demo/data/mock_local_store_test.dart` | Rollback de las tres listas si la acción lanza; `eraseAll`. |
| `test/core/di/repository_providers_test.dart` | Con `ProviderContainer` (override de `appDatabaseProvider` con base en memoria y de `sharedPreferencesProvider`): en `local` los repos son Drift; tras `enterDemo()` son mock y `container.exists(appDatabaseProvider)` sigue en `false` si no se usó antes; un movimiento creado en demo desaparece tras `exitDemo()` + `enterDemo()`; en demo `settingsControllerProvider` tiene `onboardingCompleted: true` y moneda USD. |
| `test/features/demo/presentation/demo_banner_test.dart` | App completa con overrides: *Explore demo* muestra el banner; *Exit demo* lo oculta y vuelve a *Welcome*. |

## Paso 9 · Verificación manual

`flutter run` **sin** `.env.json` (CA1 de F9: el demo funciona sin configuración): Welcome → *Explore demo* → banner
visible en las 4 tabs → *Exit demo* → Welcome. Repite con el modo avión activado.

## Paso 10 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] Repositorios mock de categorías, movimientos, presupuestos y `MockLocalStore`, validados por las mismas suites de contrato que Drift.
- [ ] `DemoDataset` sigue el patrón exacto del paso 4.1 y sus tests pasan con varios "hoy".
- [ ] Todos los providers de repositorio y de ajustes cambian según `AppMode`; el demo no abre la base real.
- [ ] Salir y volver a entrar al demo reinicia los datos (nada persiste).
- [ ] Banner "Demo mode — changes aren't saved" con *Exit demo* en todas las pantallas.
- [ ] Funciona sin `.env.json` y sin red.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
