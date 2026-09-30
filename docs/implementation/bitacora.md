# Centavo — Bitácora de implementación

> Documento vivo. Se actualiza **al empezar** y **al terminar** cada fase (ver `00-guia-general.md` §3 y §5).
> Todo en español; el código, la UI y los commits, en inglés.

## Avance

`██░░░░░░░░░░░░` 2/14 fases terminadas (14 %)

**Fase actual:** ninguna — la siguiente es la Fase 03 · Dominio
**Última actualización:** 2026-09-29
**Ventana planificada:** semana 1 (28 sep – 4 oct 2026), en paralelo con Agendo; MVP listo antes del 11 oct.

## Estado por fase

| # | Fase | Rama | Estado | Inicio | Fin |
|---|---|---|---|---|---|
| 01 | Andamiaje | `feat/fase-01-andamiaje` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 02 | Core | `feat/fase-02-core` | ✅ Terminada | 2026-09-29 | 2026-09-29 |
| 03 | Dominio | `feat/fase-03-dominio` | ⏳ Pendiente | — | — |
| 04 | Persistencia Drift | `feat/fase-04-persistencia-drift` | ⏳ Pendiente | — | — |
| 05 | Modo demo | `feat/fase-05-modo-demo` | ⏳ Pendiente | — | — |
| 06 | Onboarding y categorías | `feat/fase-06-onboarding-y-categorias` | ⏳ Pendiente | — | — |
| 07 | Movimientos | `feat/fase-07-movimientos` | ⏳ Pendiente | — | — |
| 08 | Presupuestos | `feat/fase-08-presupuestos` | ⏳ Pendiente | — | — |
| 09 | Dashboard | `feat/fase-09-dashboard` | ⏳ Pendiente | — | — |
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

## Bloqueos

_Ninguno._

## Ideas para el roadmap (fuera del MVP)

_Anotar aquí; luego pasan a la sección "Roadmap" del README._
