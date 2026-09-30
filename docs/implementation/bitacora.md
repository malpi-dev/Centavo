# Centavo — Bitácora de implementación

> Documento vivo. Se actualiza **al empezar** y **al terminar** cada fase (ver `00-guia-general.md` §3 y §5).
> Todo en español; el código, la UI y los commits, en inglés.

## Avance

`████████▒░░░░░` 8/14 fases terminadas (57 %)

**Fase actual:** Fase 09 · Dashboard (🚧 en progreso)
**Última actualización:** 2026-09-29
**Ventana planificada:** semana 1 (28 sep – 4 oct 2026), en paralelo con Agendo; MVP listo antes del 11 oct.

## Estado por fase

| # | Fase | Rama | Estado | Inicio | Fin |
|---|---|---|---|---|---|
| 01 | Andamiaje | `feat/fase-01-andamiaje` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 02 | Core | `feat/fase-02-core` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 03 | Dominio | `feat/fase-03-dominio` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 04 | Persistencia Drift | `feat/fase-04-persistencia-drift` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 05 | Modo demo | `feat/fase-05-modo-demo` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 06 | Onboarding y categorías | `feat/fase-06-onboarding-y-categorias` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 07 | Movimientos | `feat/fase-07-movimientos` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 08 | Presupuestos | `feat/fase-08-presupuestos` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 09 | Dashboard | `feat/fase-09-dashboard` | 🚧 En progreso | 2026-09-29 | — |
| 10 | Ajustes, bloqueo y CSV | `feat/fase-10-ajustes-bloqueo-y-csv` | ⏳ Pendiente | — | — |
| 11 | Backend Supabase | `feat/fase-11-backend-supabase` | ⏳ Pendiente | — | — |
| 12 | Respaldo | `feat/fase-12-respaldo` | ⏳ Pendiente | — | — |
| 13 | Pulido y E2E | `feat/fase-13-pulido-y-e2e` | ⏳ Pendiente | — | — |
| 14 | Lanzamiento | `feat/fase-14-lanzamiento` | ⏳ Pendiente | — | — |

Estados: ⏳ Pendiente · 🚧 En progreso · ✅ Terminada · ⛔ Bloqueada

## Versiones clave instaladas

> Se completa en la fase 01 (lee `pubspec.lock`, `flutter --version`, `supabase --version`) y se actualiza si cambia algo.

| Paquete / herramienta | Versión |
|---|---|
| Flutter / Dart | 3.44.6 (stable) / Dart 3.12.2 |
| flutter_riverpod / riverpod_generator | 3.4.3 / 4.0.9 |
| go_router | 17.5.0 |
| freezed / freezed_annotation | 4.0.0-dev.3 (prerelease) / 3.1.0 |
| drift / drift_flutter / drift_dev | 2.35.0 / 0.3.1 / 2.35.0 |
| sqlite3 (dependencia directa desde la fase 04) | 3.5.2 |
| supabase_flutter | 2.17.2 |
| fl_chart | 1.2.0 |
| local_auth | 3.0.2 |
| share_plus | 13.3.0 |
| very_good_analysis | 10.3.0 |
| Supabase CLI | 2.118.0 |
| Maestro | — (fase 13) |

## Registro

> Una entrada por fase terminada (la más reciente arriba). Plantilla:
>
> ### Fase NN · Nombre — AAAA-MM-DD
> - **Hecho:** qué se implementó (breve, en viñetas).
> - **PR:** enlace o número.
> - **Decisiones:** qué se decidió y por qué (también va a la tabla de abajo si cambia la definición).
> - **Pendientes:** lo que quedó para otra fase (con el número de fase destino).

### Fase 08 · Presupuestos — 2026-09-29
- **Hecho:** `budgets_providers` (`monthBudgets`, `budgetProgress`, `canCopyPreviousBudgets`, `activeBudget`, `BudgetFormController`, `CopyBudgetsController`), `BudgetsScreen` (selector con máximo mes actual + 1, tarjeta resumen con "Unbudgeted spending", tarjetas por categoría con barra, color y etiqueta de estado, sección "Not budgeted", estado vacío con *Copy from previous month*, skeleton y error con *Retry*), `BudgetFormScreen` (fijar, editar, quitar con confirmación, "Spent so far", estado "not found"), ruta `/budgets/edit` y `Routes.budgetEditFor`; textos l10n. Tests de pantalla, formulario, demo y reactividad (`./tool/check.sh` pasa, 288 tests). Verificado en emulador Android (emulator-5554, modo oscuro): Food = 600 -> gasto 450 (*On track*) -> +100 (*Near limit*) -> mes siguiente -> *Copy from previous month* ("Copied 1 budget"); en demo, Transport y Coffee *Over budget* y Entertainment *Near limit*.
- **PR:** ver historial de GitHub (`feat: phase 08 - budgets`).
- **Decisiones:** ver tabla de desviaciones.
- **Pendientes:** *Remove budget* y errores de validación se cubrieron con tests de widgets, no a mano; repetir a mano en la fase 13.

### Fase 07 · Movimientos — 2026-09-29
- **Hecho:** `rootScaffoldMessengerKey` (todos los SnackBars pasan por él); `transactions_providers` (`monthTransactions`, `TransactionFilter`/controlador, `transactionGroups`, `transactionById`), `groupTransactionsByDay`, `TransactionsScreen` (selector de mes, filtros por tipo/categoría, lista por día con neto, `Dismissible`, estados de carga/vacío/vacío filtrado/error), `TransactionFormScreen` (crear/editar/borrar, categorías archivadas al editar), `TransactionFormController`, `confirmAndDeleteTransaction` (diálogo + *Undo* 4 s); FAB `+` en Dashboard/Transactions/Budgets; rutas `/transactions/new` y `/transactions/:id` a pantalla completa; `MoneyText.signed`; textos l10n. Tests de agrupación, pantalla, formulario, borrado y modo demo (`./tool/check.sh` pasa). Verificado en emulador Android (emulator-5554, modo oscuro, modo avión activado): FAB desde Dashboard, crear gasto 12.50 en Food, lista con `−$12.50` y neto del día, deslizar -> diálogo -> borrado -> SnackBar con *Undo* -> estado vacío.
- **PR:** ver historial de GitHub (`feat: phase 07 - transactions`).
- **Decisiones:** ver tabla de desviaciones.
- **Pendientes:** editar, filtros, *Undo* al tocar, CLP y demo se cubrieron con tests de widgets, no a mano en el emulador; repetir a mano en la fase 13.

### Fase 06 · Onboarding y categorías — 2026-09-29
- **Hecho:** `WelcomeScreen` definitiva, `CurrencyScreen` (preselección por locale, `RadioGroup`), `OnboardingController.completeFreshStart` (categorías primero, ajuste después); `category_icons`, `CategoryAvatar`; `categoriesProvider`/`activeCategoriesOfType`/`categoryById`, `CategoryFormController`, `CategoriesScreen` (Expenses/Income/Archived) y `CategoryFormScreen` (crear, editar, archivar, desarchivar, borrar); rutas `/welcome/currency` y `/settings/categories[/new|/:id]`; tile provisional en Ajustes; textos l10n. Tests: flujo de onboarding, controlador, pantalla de categorías y formulario (251 tests). `./tool/check.sh` pasa. Verificado en emulador Android (emulator-5554, modo oscuro): Welcome -> moneda -> Ajustes -> Categories -> formulario nuevo.
- **PR:** ver historial de GitHub (`feat: phase 06 - onboarding and categories`).
- **Decisiones:** ver tabla de desviaciones.
- **Pendientes:** la verificación manual completa (guardar/editar/archivar/borrar en el emulador y demo) se cubrió con tests de widgets; repetir a mano en la fase 13. Las rutas de categorías viven dentro del shell, así que la barra de tabs es visible en el formulario.

### Fase 05 · Modo demo — 2026-09-29
- **Hecho:** `MockDataStore` (con streams que emulan a Drift), `MockCategoryRepository`, `MockTransactionRepository`, `MockBudgetRepository`, `MockLocalStore`; `DemoDataset` (patrón 4.1); providers de repositorios y ajustes que cambian según `AppMode` (`demoDataStore` y `demoSettingsRepository` se invalidan al entrar y salir del demo); `DemoBanner` en `MaterialApp.builder`; botón *Explore demo* en la bienvenida provisional; textos l10n. Suites de contrato compartidas (categorías, movimientos, presupuestos, `LocalStore`) ejecutadas contra Drift y mock; tests del dataset (4 "hoy"), providers y banner (238 tests). `./tool/check.sh` pasa. Verificado en el emulador Android (emulator-5554) sin `.env.json`: Welcome -> *Explore demo* -> banner en las 4 tabs -> *Exit demo* -> Welcome.
- **PR:** ver historial de GitHub (`feat: phase 05 - demo mode`).
- **Decisiones:** ver tabla de desviaciones.
- **Pendientes:** la prueba con modo avión no se hizo (el demo no usa red: solo mocks en memoria); repetirla en la verificación manual de la fase 13.

### Fase 04 · Persistencia Drift — 2026-09-29
- **Hecho:** `AppDatabase` v1 (`categories`, `transactions`, `budgets`, `sync_state`) con índices únicos parciales, FKs activas y conversores `LocalDate`/`YearMonth`; `storage_guard.dart` (`guardStorage`, `guardStorageStream`, `mapStorageError`); mappers y repositorios `DriftCategoryRepository`, `DriftTransactionRepository`, `DriftBudgetRepository`, `DriftLocalStore`; providers de repositorios, `appDatabase` y casos de uso (`use_case_providers.dart`); snapshot `drift_schemas/centavo/drift_schema_v1.json`; tests con Drift en memoria (167 tests en total). `./tool/check.sh` pasa.
- **PR:** ver historial de GitHub (`feat: phase 04 - drift persistence`).
- **Decisiones:** `sqlite3` añadido como dependencia directa (`^3.5.2`) para reconocer `SqliteException` sin violar `depend_on_referenced_packages`. Más en la tabla de desviaciones.
- **Pendientes:** ninguno. `use_case_providers.dart` y los providers Drift aún no se consumen desde la UI (fases 05+).

### Fase 03 · Dominio — 2026-09-29
- **Hecho:** `TransactionType` y `LocalStore` en `core/domain`; modelos freezed (`Category`, `MoneyTransaction`, `TransactionDraft`, `Budget`, `BudgetLine`, `BudgetProgressReport`, `CategorySlice`, `MonthSummary`, `MonthTotals`); interfaces `CategoryRepository`, `TransactionRepository`, `BudgetRepository`, `CsvShareService`; categorías por defecto con UUID fijos; validadores de categoría, movimiento y presupuesto; casos de uso `SeedDefaultCategories`, `DeleteOrArchiveCategory`, `GetBudgetProgress` (estados con enteros), `CopyBudgetsFromPreviousMonth`, `GetMonthSummary`, `GetMonthlyTrend`, `ExportTransactionsCsv` + `buildTransactionsCsv`; `test/helpers/builders.dart` y tests de todos los archivos de la tabla (116 tests en total). `./tool/check.sh` pasa.
- **PR:** ver historial de GitHub (`feat: phase 03 - domain`).
- **Decisiones:** ver tabla de desviaciones.
- **Pendientes:** ninguno.

### Fase 02 · Core — 2026-09-29
- **Hecho:** value objects (`LocalDate`, `YearMonth`, `Money`, `Currency`, `Clock`/`FixedClock`, `IdGenerator`, `parseAmountToMinor`, paleta de categorías, `AppMode`), `DomainError` sellado, `Env`, fuentes Manrope + Inter con licencias OFL, tema claro/oscuro con `CentavoColors`, `AppSettings` con repos `prefs` e `in_memory`, providers base (composition root, `AppModeController`, `SettingsController`, `SelectedMonth`), textos l10n y `errorMessage` exhaustivo, widgets comunes (`AsyncStateView`, `EmptyState`, `ErrorState`, `SkeletonList`, `MonthSelector`, `MoneyText`), router con redirect puro y shell de 4 tabs, pantallas provisionales, helpers y tests (47). `./tool/check.sh` pasa.
- **PR:** ver historial de GitHub (`feat: phase 02 - core`).
- **Decisiones:** ver tabla de desviaciones.
- **Pendientes:** ninguno. Verificación manual hecha en el emulador Android (emulator-5554): Welcome -> Start fresh -> tabs, modo oscuro del sistema aplicado, y tras cerrar y reabrir entra directo a Dashboard.

### Fase 01 · Andamiaje — 2026-09-29
- **Hecho:** `flutter create` (`com.malpidev.centavo`), dependencias de §9 (sin `csv`), `very_good_analysis`, `build.yaml`, l10n (`app_en.arb`), `MainActivity` con `FlutterFragmentActivity`, `USE_BIOMETRIC`, cleartext solo en debug, estructura de carpetas, `.env.example.json`, `.gitignore`, `tool/check.sh` y `tool/check_architecture.sh`, app mínima + test de humo, `CLAUDE.md` y `README.md`, CI. `./tool/check.sh` pasa; la app abre en el emulador Android (Pixel_10_Pro) mostrando "Centavo"; `flutter build apk --debug` OK.
- **PR:** ver historial de GitHub (`feat: phase 01 - project scaffolding`).
- **Decisiones:** ver tabla de desviaciones (freezed 4 prerelease, `flutter_lints` eliminado, build_runner sin `--delete-conflicting-outputs`, checkout@v7).
- **Pendientes:** ninguno.

## Decisiones y desviaciones respecto a la definición

| Fecha | Fase | Decisión / desviación | Motivo |
|---|---|---|---|
| 2026-09-25 | Plan | Los errores viven en `lib/core/errors/domain_error.dart` (`sealed class DomainError`); no se crean `centavo_failure.dart` ni `core/domain/result.dart` que aparecen en el árbol de §8.2. | §6.4 y la regla 6 del `CLAUDE.md`: los repositorios lanzan, no devuelven `Result`. |
| 2026-09-25 | Plan | Se añade `UnknownError` a `DomainError`. | Código común `unknown` del `CLAUDE.md`. |
| 2026-09-25 | Plan | Los días de calendario usan el value object `LocalDate` (año, mes, día; ISO `YYYY-MM-DD`) en lugar de `DateTime` sin hora. | Evita errores de zona horaria y de medianoche; se persiste igual como texto ISO. |
| 2026-09-25 | Plan | Las categorías por defecto tienen **UUID fijos** (constantes en `default_categories.dart`). | Al restaurar en un teléfono que ya hizo *Start fresh*, las categorías por defecto se fusionan por `id` en vez de duplicarse (y chocar con el índice único por nombre). |
| 2026-09-25 | Plan | En Supabase, `centavo.categories` usa **PK compuesta `(user_id, id)`** y las FKs son `(user_id, category_id) → categories(user_id, id)`. `transactions` y `budgets` mantienen `id` como PK. | Con UUID fijos para las categorías por defecto, dos usuarios distintos tendrían el mismo `id`; con PK compuesta no chocan. |
| 2026-09-25 | Plan | La columna `color` de `centavo.categories` es `bigint` (check `between 0 and 4294967295`), no `integer`. | Un ARGB opaco (`0xFF……`) no cabe en un `integer` con signo de Postgres. |
| 2026-09-25 | Plan | `centavo.ensure_profile(p_currency_code text default 'USD')` recibe la moneda. | `profiles.currency_code` es `not null`; el cliente conoce la moneda y la envía. Sigue siendo idempotente y usa `auth.uid()`. |
| 2026-09-25 | Plan | *Delete my backup* borra filas de `transactions`, `budgets` y `categories`; el perfil (solo moneda) se conserva. | §7.2 no da política `delete` a `profiles`; no aporta borrarlo y evita otra RPC. |
| 2026-09-25 | Plan | Al subir un respaldo, dentro de cada tabla se envían primero las filas con `deletedAt != null` y después las activas. | Evita violar el índice único parcial de presupuestos cuando un presupuesto se reemplazó por otro del mismo mes. |
| 2026-09-25 | Plan | Al restaurar, si una categoría entrante choca por (nombre, tipo) con una categoría local activa de **otro** `id`, la entrante se guarda con el sufijo `" 2"` (recortando el nombre a 30 caracteres). Si un presupuesto entrante choca por (categoría, mes) con uno local activo de otro `id`, gana el de `updatedAt` más reciente y el otro se marca como borrado. | Regla determinista y simple para fusionar sin romper los índices únicos locales. |
| 2026-09-25 | Plan | La restauración **no** modifica `lastBackupAt`. | El siguiente respaldo vuelve a subir todo; es inofensivo gracias a last-write-wins y evita perder filas locales anteriores a la restauración. |
| 2026-09-25 | Plan | No se usa el paquete `csv`: el escape RFC 4180 se implementa en `ExportTransactionsCsv` (dominio puro, ~20 líneas, probado). El archivo lleva BOM UTF-8 y fin de línea `\r\n`. | Menos dependencias y sin riesgo de cambios de API; el BOM hace que Excel lea bien los acentos (CA1 de F7). |
| 2026-09-25 | Plan | `FLAG_SECURE` se activa con un `MethodChannel` propio (`com.malpidev.centavo/secure_window`) en `MainActivity.kt`, sin paquete extra. | Son 10 líneas de Kotlin; los paquetes existentes para esto están poco mantenidos. |
| 2026-09-25 | Plan | El mes seleccionado es estado compartido (`selectedMonthProvider`) entre Dashboard, Movimientos y Presupuestos, no un parámetro `?month=` de la URL. Solo `/transactions/new?type=` y `/budgets/edit?category=&month=` usan query params. | Menos código; el usuario ve el mismo mes al cambiar de tab. |
| 2026-09-25 | Plan | Las rutas `/settings/backup/sign-in` y `/settings/backup/verify` se permiten sin onboarding completado (flujo *Restore from backup* desde la bienvenida, con `?from=welcome`). | El redirect 1 de §5.2 las bloquearía. |
| 2026-09-25 | Plan | Las categorías archivadas se pueden desarchivar (*Unarchive*) desde la sección *Archived*. | La sección existe (§12.1) y sin esta acción archivar sería irreversible. |
| 2026-09-25 | Plan | *Erase all local data* también cierra la sesión de respaldo (sin borrar el respaldo en la nube). | Deja la app como recién instalada. |
| 2026-09-25 | Plan | Dependencias añadidas a §9: `sqlite3` (fase 04, para reconocer `SqliteException`; ya era transitiva de Drift) y `package_info_plus` (fase 10, versión en *About*). No se añade `url_launcher`: el enlace al repo se copia al portapapeles. | Mínimo necesario; el lint `depend_on_referenced_packages` exige declarar lo que se importa. |
| 2026-09-25 | Plan | `csvShareServiceProvider` usa la implementación real también en demo (exportar los datos de ejemplo es inofensivo); el mock solo se usa en tests. En demo, biometría y respaldo sí usan mocks. | Demuestra la función real sin tocar datos reales. |
| 2026-09-25 | Plan | El módulo de respaldo es visible en demo aunque no exista `.env.json` (simulado con mocks; código `123456`). En modo local solo aparece si `Env.isBackupEnabled`. | Quien revisa la app puede ver el flujo completo sin backend (F9). |
| 2026-09-25 | Plan | Se desactiva `public_member_api_docs` en `analysis_options.yaml`. | Es una app, no un paquete publicado; documentar cada miembro público no aporta. |
| 2026-09-25 | Plan | Fuentes Manrope + Inter en TTF estáticos (subset latino) descargados de Fontsource. | Decisión abierta de §17 resuelta a favor de la definición; los TTF estáticos evitan problemas de pesos con fuentes variables. |
| 2026-09-25 | Plan | Datos de demo: patrón determinista definido en la fase 05 (§ "Patrón del dataset") y replicado en `seed.sql` (fase 11). En el mes actual los límites de *Coffee* y *Entertainment* se calculan a partir del gasto real para garantizar un estado `exceeded` y uno `warning` cualquier día del mes. | §12.2 exige esos estados en el mes actual, que depende del día en que se abra la app. |
| 2026-09-25 | Plan | Decisiones abiertas de §17 resueltas: código generado **no** se commitea; Maestro **no** corre en CI (se ejecuta en local antes del tag); `backup_batch` RPC **no** se crea salvo que el upsert por lotes se mida lento. | Propuestas de la propia definición. |
| 2026-09-29 | 01 | `freezed` queda en `^4.0.0-dev.3` (prerelease). | La estable 4.0.x exige Dart ≥ 3.13 (hay 3.12.2) y la 3.x exige `analyzer` <13, incompatible con `drift_dev`/`riverpod_generator` actuales. Revisar al actualizar Flutter. |
| 2026-09-29 | 01 | Se elimina `flutter_lints` del `pubspec.yaml` generado. | Lo reemplaza `very_good_analysis`. |
| 2026-09-29 | 01 | `dart run build_runner build` avisa que `--delete-conflicting-outputs` ya no existe (se ignora). Se deja el flag en `check.sh` según la guía. | Inofensivo; quitarlo en una fase futura. |
| 2026-09-29 | 01 | En CI se usa `actions/checkout@v7` y `flutter-version: 3.44.6`. | Última versión mayor disponible; misma versión que local. |
| 2026-09-29 | 01 | Dependencias de desarrollo ordenadas alfabéticamente. | Lint `sort_pub_dependencies`. |
| 2026-09-29 | 02 | `FixedClock` usa el parámetro nombrado privado `{this._today}` (Dart 3.12) en vez de `today` + campo `_today`. | Evita el lint `prefer_initializing_formals`; la API pública (`today:`) es idéntica. |
| 2026-09-29 | 02 | `LocalDate.parse` valida con un helper privado `_exists` en vez de capturar `ArgumentError`. | Lint `avoid_catching_errors`. |
| 2026-09-29 | 02 | `IdGenerator` lleva `// ignore: one_member_abstracts` con justificación. | Es un seam de inyección para tests (id secuenciales). |
| 2026-09-29 | 02 | Licencia OFL de Manrope tomada de `google/fonts` (el repo original no expone `OFL.txt`); la de Inter, de `rsms/inter` (`LICENSE.txt`). | Fuente oficial más estable. |
| 2026-09-29 | 02 | `MonthSelector` añadió operadores `<`, `<=`, `>`, `>=` a `YearMonth`. | Comparar `month >= maxMonth` de forma legible; sin dependencia nueva. |
| 2026-09-29 | 03 | Los constructores de casos de uso usan parámetros nombrados privados (`required this._x`, Dart 3.12). | Evita el lint `prefer_initializing_formals`; API pública idéntica. |
| 2026-09-29 | 03 | `Category`, `Budget`, `MoneyTransaction`, etc. sitúan los parámetros requeridos antes de los opcionales; `CategorySlice` pone `amount`/`basisPoints` primero. | Lint `always_put_required_named_parameters_first`; el orden no afecta a la API. |
| 2026-09-29 | 03 | Se añadió `budget_validator_test.dart` (no estaba en la tabla de tests). | Cubre `validateBudgetForm`. |
| 2026-09-29 | 03 | `CsvShareService` lleva `// ignore: one_member_abstracts` con justificación. | Puerto con un único método, implementado por el adaptador de plataforma. |
| 2026-09-29 | 04 | Los constructores de los repositorios Drift usan `required this._clock, required this._ids`. | Lint `prefer_initializing_formals`; API pública idéntica. |
| 2026-09-29 | 04 | `AppDatabase(super.e)`: el parámetro del constructor se llama `e` (nombre del super). `DriftRemoteException` se importa de `package:drift/isolate.dart` (`remote.dart` está marcado experimental). | Lints `matching_super_parameters` y `experimental_member_use`. |
| 2026-09-29 | 04 | Las tablas con `check(amountMinor.isBiggerThanValue(0))` llevan `// ignore: recursive_getters` justificado. | Patrón documentado de Drift; el lint es un falso positivo. |
| 2026-09-29 | 04 | Se añade `guardStorageStream` (paso 5 sugería `handleError` inline). Los `DomainError` que pasen por el stream se relanzan tal cual. | Reutilizado por los tres repositorios en `watch…`. |
| 2026-09-29 | 04 | `DriftCategoryRepository.update` solo comprueba duplicado si la categoría está activa (no archivada); persiste solo nombre, icono, color y `updatedAt`. | Coherente con el índice único parcial (solo activas) y con que el tipo no puede cambiar. |
| 2026-09-29 | 04 | `softDelete`/`archive` de categoría lanzan `NotFoundError` si no existe o ya está borrada; `softDelete`/`restore` de movimientos son idempotentes y no fallan si el id no existe. | La interfaz de dominio solo exige `NotFoundError` en `update`; en movimientos el *Undo* debe ser tolerante. |
| 2026-09-29 | 04 | Test de `DriftRemoteException` real mediante `DriftIsolate.spawn(NativeDatabase.memory)` en vez de construir la excepción. | Su constructor es privado. |
| 2026-09-29 | 05 | `demoSettingsRepository` usa `AppSettings(onboardingCompleted: true)` sin pasar `currencyCode`; un test comprueba que la moneda sea `DemoDataset.currencyCode`. | Lint `avoid_redundant_argument_values` (el valor por defecto ya es USD). |
| 2026-09-29 | 05 | `app_mode_provider.dart` y `repository_providers.dart` se importan mutuamente (import circular); `AppModeController` no se movió. | Dart lo permite y el generador funciona; evita mover el controlador. |
| 2026-09-29 | 05 | `MockDataStore.watch` usa un `StreamController` con `onListen` en vez de `async*`. | Evita perder cambios entre el primer valor y la suscripción. |
| 2026-09-29 | 05 | `MockTransactionRepository` desempata por inserción más reciente primero. | Coincide con el orden observado en Drift cuando `createdAt` es igual (contrato compartido). |
| 2026-09-29 | 05 | Los tests de solo-Drift (índice único parcial, `eraseAll` de las 4 tablas) quedan en sus archivos; el resto vive en `*_contract.dart`. | Paso 3 de la fase. |
| 2026-09-29 | 06 | El método del controlador del formulario se llama `edit` (no `update`). | `update` choca con `AsyncNotifier.update`. |
| 2026-09-29 | 06 | El formulario guarda con `await` + comprobar `hasError` para hacer `pop`, y `ref.listen` solo gestiona errores. | Equivalente al patrón del paso 1 y evita dobles pops. |
| 2026-09-29 | 06 | Tests de widgets con Drift usan `testCentavo`/`runRepo` (desmontan la app y esperan los streams) y `pumpCentavo` fija una pantalla 800x1600. | Los timers de cancelación de streams de Drift fallan la verificación de timers pendientes. `app_smoke_test` ahora también usa base en memoria. |
| 2026-09-29 | 07 | `ProviderScope(retry: noAutomaticRetry)` (main y tests). | Riverpod 3 reintenta providers fallidos con backoff y la pantalla se quedaba en "loading" en vez de mostrar el error con *Retry*. |
| 2026-09-29 | 07 | `SnackBar` de *Undo* con `persist: false` y sin `duration` explícito. | Con `action` el SnackBar persiste por defecto; `persist: false` lo cierra tras los 4 s por defecto (el lint rechaza pasar 4 s explícitos). |
| 2026-09-29 | 07 | `Dismissible.confirmDismiss` siempre devuelve `false` tras borrar. | La fila desaparece por el stream; evita el error de Dismissible "still in the tree". |
| 2026-09-29 | 07 | Las keys `tx-type-*` van en el `Text` de cada `ButtonSegment` (no tiene `key`); chips de categoría sin checkmark. | `ButtonSegment` no acepta key; el checkmark tapaba el avatar. |
| 2026-09-29 | 07 | `pumpCentavo` acepta `overrides`; `MoneyText` gana `signed`. | Test del error del stream y signo `+` en ingresos. |
| 2026-09-29 | 08 | `BudgetFormScreen.month` es `YearMonth?` (null = mes malformado en la URL); el parseo con `try/catch` vive en el router. | Permite mostrar el estado "not found" sin lanzar en el builder. |
| 2026-09-29 | 08 | `app_smoke_test` pasa a `testCentavo` y comprueba la pantalla de Budgets en vez de "Coming soon". | El placeholder desapareció; la pantalla real usa streams de Drift (timers pendientes). |

## Bloqueos

_Ninguno._

## Ideas para el roadmap (fuera del MVP)

_Anotar aquí; luego pasan a la sección "Roadmap" del README._
