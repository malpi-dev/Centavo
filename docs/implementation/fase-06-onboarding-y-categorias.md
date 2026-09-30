# Fase 06 · Onboarding y categorías

**Rama:** `feat/fase-06-onboarding-y-categorias`
**Objetivo:** bienvenida definitiva (*Start fresh*, *Explore demo*), selección de moneda, creación de las categorías
por defecto y gestión completa de categorías (lista, crear, editar, archivar/desarchivar, borrar).
**Referencias:** definición §3.1 F1 y F3, §5.1 flujos A y F, §5.2, §12.1 (Categories, Welcome), §11.
**Requisitos previos:** fase 05 terminada.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Patrón de formulario (se reutiliza en las fases 07, 08 y 12)

Todas las pantallas de formulario siguen el mismo patrón; respétalo para que el código sea homogéneo:

1. **Pantalla** = `ConsumerStatefulWidget` que guarda el estado de edición local (`TextEditingController`s, valores
   seleccionados) y un `Map<String, ValidationReason> _errors`.
2. Al pulsar *Save*: llama al validador de dominio (`validateXForm`). Si hay errores, `setState(() => _errors = …)` y
   cada campo muestra `validationMessage(reason, l10n)` en su `errorText`. No se llama al repositorio.
3. Si es válido: `await ref.read(xFormControllerProvider.notifier).save(...)`.
4. **Controlador** = `@riverpod class XFormController extends _$XFormController` con estado `AsyncValue<void>`;
   `save` hace `state = const AsyncLoading(); state = await AsyncValue.guard(() => repository.…);`.
5. La pantalla escucha el controlador con `ref.listen`: en `AsyncData` tras guardar → `context.pop()`; en
   `AsyncError` con `DomainError` → si es `ValidationError` lo pone en `_errors[field]`; si es `DuplicateError` lo pone en
   el campo `name`; cualquier otro → `SnackBar(messageFor(error, l10n))`.
6. El botón *Save* muestra un `CircularProgressIndicator` pequeño y se deshabilita mientras `state.isLoading`.
7. Para editar, la pantalla carga la entidad con un `FutureProvider` (`findById`) envuelto en `AsyncStateView`;
   si devuelve `null` → `EmptyState` "This item no longer exists." con botón *Back*.

## Paso 2 · Widgets de categoría compartidos (`lib/core/presentation/`)

- `category_icons.dart`: `IconData categoryIcon(String key)` con este mapa (clave desconocida → `Icons.category`):
  `food→restaurant, groceries→shopping_cart, coffee→local_cafe, transport→directions_bus, car→directions_car,
  fuel→local_gas_station, home→home, utilities→bolt, phone→smartphone, internet→wifi, health→favorite,
  pharmacy→local_pharmacy, fitness→fitness_center, entertainment→movie, games→sports_esports, music→music_note,
  shopping→shopping_bag, clothes→checkroom, education→school, books→menu_book, travel→flight, pets→pets,
  gifts→card_giftcard, kids→child_care, beauty→spa, subscriptions→subscriptions, salary→work, freelance→laptop,
  investments→trending_up, other→category`.
- `category_avatar.dart`: `CategoryAvatar({required String icon, required int color, double size = 40})` → círculo con
  el color de `context.colors.category(color)` al 18 % de opacidad y el ícono en ese color. Si `icon`/`color` son
  `null` (slice "Others" o categoría inexistente) usa `Icons.more_horiz` y `onSurfaceVariant`.

## Paso 3 · Onboarding (`lib/features/onboarding/presentation/`)

### 3.1 `welcome_screen.dart` (reemplaza la provisional)

- Ícono/ilustración simple (por ahora `Icons.savings` grande en `primary`; el logo llega en la fase 13), título
  `welcomeTitle` ("Welcome to Centavo"), subtítulo `welcomeSubtitle` ("Track your money privately. Everything stays on
  your phone — no account needed.").
- Botones en columna, ancho completo:
  - `FilledButton` *Start fresh* (key `welcome-start-fresh`) → `context.push(Routes.welcomeCurrency)`.
  - `OutlinedButton` *Explore demo* (key `welcome-explore-demo`) → `enterDemo()`.
  - *Restore from backup* **no se añade todavía** (llega en la fase 12, solo si `Env.isBackupEnabled`).
- Todos los botones con `Semantics(identifier: …)` igual a su key.

### 3.2 `currency_screen.dart` (`/welcome/currency`, sub-ruta de `/welcome`)

- Título `chooseCurrency` ("Choose your currency"), texto de ayuda `currencyHelp` ("You can change the format later.
  Amounts are never converted.").
- Lista de `supportedCurrencies` con `RadioListTile` (o `RadioGroup` si tu versión de Flutter lo exige): `name` y
  `code`. Key por fila: `currency-<code>`.
- Preselección: `defaultCurrencyForCountry(WidgetsBinding.instance.platformDispatcher.locale.countryCode)`.
- Botón *Continue* (key `currency-continue`) → `onboardingControllerProvider.notifier.completeFreshStart(code)`.

### 3.3 `onboarding_controller.dart`

```dart
@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  FutureOr<void> build() {}

  Future<void> completeFreshStart(String currencyCode) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(seedDefaultCategoriesProvider).call();
      await ref.read(settingsControllerProvider.notifier)
          .change((s) => s.copyWith(currencyCode: currencyCode, onboardingCompleted: true));
    });
  }
}
```

Primero se crean las categorías y **después** se marca el onboarding (si la creación falla, el usuario sigue en la
bienvenida y puede reintentar). El redirect del router lleva a `/dashboard` en cuanto cambia el ajuste. Si falla,
`SnackBar` con `messageFor`.

## Paso 4 · Categorías (`lib/features/categories/presentation/`)

### 4.1 Providers (`categories_providers.dart`)

```dart
@riverpod
Stream<List<Category>> categories(Ref ref) => ref.watch(categoryRepositoryProvider).watchAll();

/// Active categories of one type, for pickers (transaction form, budgets).
@riverpod
Future<List<Category>> activeCategoriesOfType(Ref ref, TransactionType type) async {
  final all = await ref.watch(categoriesProvider.future);
  return all.where((c) => c.type == type && c.isActive).toList();
}

@riverpod
Future<Category?> categoryById(Ref ref, String id) => ref.watch(categoryRepositoryProvider).findById(id);
```

### 4.2 Rutas (dentro de la rama Settings del shell)

```
/settings
  └── categories            CategoriesScreen
        ├── new             CategoryFormScreen(id: null)   ?type=expense|income
        └── :id             CategoryFormScreen(id: id)
```

Declara `new` **antes** de `:id`. Añade provisionalmente en la `SettingsScreen` un `ListTile` *Categories*
(key `settings-categories`) → `context.push(Routes.categories)`; la pantalla de ajustes completa llega en la fase 10.

### 4.3 `categories_screen.dart`

- `AppBar` "Categories" con acción `+` (key `categories-add`) que abre un menú *Expense category* / *Income category*
  → `Routes.categoryNew?type=…`.
- `AsyncStateView` sobre `categoriesProvider`: carga → `SkeletonList`; error → `ErrorState` con *Retry*
  (`ref.invalidate(categoriesProvider)`). Nunca está vacía (existen las por defecto).
- Secciones con encabezado: **Expenses**, **Income** (activas) y **Archived** (solo si hay alguna; oculta si está vacía).
- Fila: `CategoryAvatar` + nombre + chip pequeño "Default" si `isDefault`. Tap → `Routes.categoryEdit(id)`.
  Key por fila: `category-<id>`.

### 4.4 `category_form_screen.dart` (patrón del paso 1)

- Campos: nombre (`TextField`, `maxLength: 30`, key `category-name`); tipo (`SegmentedButton` Expense/Income, key
  `category-type`) — **deshabilitado al editar** con la ayuda "The type can't be changed" (CA2 de F3); rejilla de
  íconos (30, key `category-icon-<key>`); fila de colores (12 círculos, key `category-color-<index>`), con el
  seleccionado marcado con un check.
- Valores iniciales al crear: tipo del query param, ícono `other`, primer color de la paleta.
- *Save* → `CategoryFormController.save(...)` → `create` o `update`.
- Al editar, menú de acciones del `AppBar`:
  - *Archive* (si activa) / *Unarchive* (si archivada) → repositorio; `SnackBar` de confirmación.
  - *Delete* → diálogo de confirmación ("Delete category?" / "If it has transactions it will be archived instead.")
    → `deleteOrArchiveCategoryProvider`. Resultado `deleted` → `pop` + `SnackBar` "Category deleted";
    `archived` → `pop` + `SnackBar` "Category archived because it has transactions." (CA3 de F3).
- Las categorías por defecto se pueden editar, archivar y borrar como las demás.

## Paso 5 · Textos

Añade a `app_en.arb` todos los textos nuevos de esta fase (`welcomeSubtitle`, `chooseCurrency`, `currencyHelp`,
`continueLabel`, `categoriesTitle`, `expenseCategory`, `incomeCategory`, `sectionExpenses`, `sectionIncome`,
`sectionArchived`, `defaultBadge`, `categoryName`, `categoryType`, `categoryIcon`, `categoryColor`,
`typeCannotChange`, `archive`, `unarchive`, `deleteCategoryTitle`, `deleteCategoryMessage`, `categoryDeleted`,
`categoryArchivedInUse`, `categoryArchived`, `categoryUnarchived`, `expense`, `income`, `back`, `itemNotFound`, …).

## Paso 6 · Tests

Usa la app completa (`CentavoApp`) con overrides: `appDatabaseProvider` → base en memoria, `sharedPreferencesProvider`
→ `SharedPreferences` de prueba, `clockProvider` → `FixedClock`.

| Archivo | Casos mínimos |
|---|---|
| `test/features/onboarding/presentation/onboarding_flow_test.dart` | Welcome → *Start fresh* → la moneda preseleccionada es la del locale (fuerza `tester.platformDispatcher.localeTestValue = Locale('es', 'MX')` → MXN) → *Continue* → llega al Dashboard; la base tiene 10 categorías; `currencyCode` guardado. |
| `test/features/onboarding/presentation/onboarding_controller_test.dart` | Si `SeedDefaultCategories` lanza, `onboardingCompleted` sigue en `false` y el estado es `AsyncError`. |
| `test/features/categories/presentation/categories_screen_test.dart` | Secciones Expenses/Income; *Archived* oculta sin archivadas y visible con una; tap abre edición. |
| `test/features/categories/presentation/category_form_screen_test.dart` | Crear "Coffee" → aparece en la lista; nombre vacío muestra "Required"; duplicado "food" muestra error en el campo nombre; al editar el selector de tipo está deshabilitado; *Delete* sin movimientos la borra; con movimientos la archiva y muestra el SnackBar; *Unarchive* la devuelve a su sección. |

## Paso 7 · Verificación manual en Android

Desinstala la app (o borra datos) → abre → *Start fresh* → moneda → Dashboard (placeholder). Ajustes → Categories:
crea, edita, archiva, desarchiva y borra. Repite en modo oscuro. Repite en demo: las categorías del demo (Coffee, Gym,
Old car archivada) aparecen y los cambios se pierden al salir.

## Paso 8 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] F1 CA1–CA3: *Start fresh* crea las categorías por defecto con la moneda elegida; siguientes aperturas van directo al Dashboard.
- [ ] F3 CA1–CA3: sin duplicados activos por nombre+tipo; tipo inmutable; borrar vs. archivar según movimientos.
- [ ] Categorías archivadas visibles en su sección y desarchivables.
- [ ] Estados de carga y error en la lista; formulario con errores por campo.
- [ ] Todo funciona en local (Drift) y en demo (mock).
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
