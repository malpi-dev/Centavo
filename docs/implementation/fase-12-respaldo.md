# Fase 12 · Respaldo opcional en Supabase

**Rama:** `feat/fase-12-respaldo`
**Objetivo:** iniciar sesión con email + código OTP (solo para respaldo), *Back up now*, respaldo automático
(≥ 24 h), *Restore from backup* (desde ajustes y desde la bienvenida), *Delete my backup* y *Sign out* conservando los
datos locales. En demo todo se simula con repositorios mock.
**Referencias:** definición §3.1 F8, §5.1 flujos D y E, §5.2 (redirect 3), §6.3 (`RunBackup`/`RestoreBackup`), §6.4,
§7.4, §8.3 ("Estrategia de respaldo"), §12.1 (Backup, Welcome/Restore), §15 · bitácora (orden de subida, reglas de fusión).
**Requisitos previos:** fase 11 terminada. Supabase local corriendo (`supabase start`), `.env.json` local creado.

> Principio: el respaldo **nunca** bloquea la app. Sin red, sin `.env.json` o con el backend pausado, todo lo demás
> sigue funcionando y el respaldo muestra un mensaje claro (CA1 de F8).

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Cliente de Supabase (`lib/core/supabase/`)

1. En `main.dart`, antes de `runApp`:
   ```dart
   if (Env.isBackupEnabled) {
     await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabasePublishableKey);
   }
   ```
   (El parámetro puede llamarse `anonKey` o `publishableKey` según la versión de `supabase_flutter`: revisa la firma.
   Siempre se pasa la **publishable key**.) `initialize` no hace peticiones de red, así que no bloquea sin conexión.
2. `supabase_client_provider.dart`: `@Riverpod(keepAlive: true) SupabaseClient supabaseClient(Ref ref)` → si
   `!Env.isBackupEnabled` lanza `StateError('Backup is disabled')`; si no, `Supabase.instance.client`.

## Paso 2 · Dominio del respaldo (`lib/features/backup/domain/`)

### 2.1 Interfaces

```dart
abstract interface class AuthRepository {
  /// Emits the signed-in email, or null when signed out. Emits the current value first.
  Stream<String?> watchSignedInEmail();
  String? get currentEmail;
  /// AuthError(invalidEmail | rateLimited), NetworkError, BackendUnavailableError.
  Future<void> sendCode(String email);
  /// AuthError(invalidCode | codeExpired | rateLimited), NetworkError, BackendUnavailableError.
  Future<void> verifyCode({required String email, required String code});
  /// Local sign-out; never deletes local data and never fails because of the network.
  Future<void> signOut();
}

@freezed
abstract class BackupProfile with _$BackupProfile {
  const factory BackupProfile({required String currencyCode}) = _BackupProfile;
}

abstract interface class BackupRepository {
  /// All methods throw AuthError(notSignedIn) without a session.
  Future<BackupProfile> ensureProfile(String currencyCode);        // RPC centavo.ensure_profile
  Future<void> updateCurrency(String currencyCode);
  Future<BackupProfile?> fetchProfile();
  Future<void> upsertCategories(List<Category> rows);              // caller sends batches of <= 500
  Future<void> upsertBudgets(List<Budget> rows);
  Future<void> upsertTransactions(List<MoneyTransaction> rows);
  Future<List<Category>> fetchCategories();                        // every row of the user, tombstones included
  Future<List<Budget>> fetchBudgets();
  Future<List<MoneyTransaction>> fetchTransactions();
  /// "Delete my backup": transactions, budgets and categories of the user. The profile stays (implementation log).
  Future<void> deleteAll();
}

abstract interface class SyncStateRepository {
  Future<DateTime?> lastBackupAt();
  Stream<DateTime?> watchLastBackupAt();
  Future<void> setLastBackupAt(DateTime valueUtc);
  Future<void> setLastRestoreAt(DateTime valueUtc);
  Future<void> clearLastBackupAt();
}
```

`email_validator.dart`: `bool isValidEmail(String email)` (regex simple `^[^@\s]+@[^@\s]+\.[^@\s]+$`) y
`bool isValidOtpCode(String code)` (exactamente 6 dígitos).

### 2.2 Métodos nuevos en los repositorios locales

Añade a `CategoryRepository`, `BudgetRepository` y `TransactionRepository` (interfaz, Drift y mock):

```dart
/// Rows with updatedAt > sinceUtc (all rows when null), INCLUDING archived and deleted ones, ordered by updatedAt.
Future<List<T>> changedSince(DateTime? sinceUtc);
/// Merges rows downloaded from the backup (last-write-wins by id). Never deletes local rows that are not in [incoming].
Future<void> mergeFromBackup(List<T> incoming);
```

Reglas de `mergeFromBackup` (idénticas en Drift y mock):
1. Por cada fila entrante busca la local con el mismo `id` **incluyendo borradas**.
2. No existe → se inserta tal cual (con sus fechas). Existe y `local.updatedAt < incoming.updatedAt` → se reemplaza
   entera. Si no → se conserva la local.
3. **Categorías — choque de nombre:** si la fila a escribir está activa y existe **otra** categoría activa local con el
   mismo nombre (sin distinguir mayúsculas) y tipo, se escribe con el nombre `"<nombre> 2"` (recortando el original a
   28 caracteres); si también choca, `" 3"`, etc.
4. **Presupuestos — choque de (categoría, mes):** si la fila a escribir está activa y existe **otro** presupuesto
   activo local para la misma categoría y mes, gana el de `updatedAt` más reciente; el otro se guarda/queda con
   `deletedAt = updatedAt = clock.nowUtc()`.
5. Escribir **sin** actualizar `updatedAt` (se conserva el del respaldo), salvo en el caso 4 para el perdedor.

Implementación Drift de la sincronización: `DriftSyncStateRepository` sobre la tabla `sync_state` (claves `lastBackupAt`,
`lastRestoreAt`, valor ISO UTC). Mock: `MockSyncStateRepository` sobre `MockDataStore.syncState` (+ un
`StreamController` para `watchLastBackupAt`).

### 2.3 `run_backup.dart`

```dart
enum BackupStep { preparing, uploadingCategories, uploadingBudgets, uploadingTransactions }

@freezed
abstract class BackupResult with _$BackupResult {
  const factory BackupResult({required int categories, required int budgets, required int transactions,
      required DateTime startedAt}) = _BackupResult;
}

class RunBackup {
  RunBackup({required BackupRepository backup, required CategoryRepository categories, required BudgetRepository budgets,
      required TransactionRepository transactions, required SyncStateRepository syncState, required Clock clock,
      this.batchSize = 500});
  final int batchSize;
  Future<BackupResult> call({required String currencyCode, void Function(BackupStep step)? onStep});
}
```

Algoritmo (definición §8.3):
1. `startedAt = clock.nowUtc()`; `since = await syncState.lastBackupAt()`.
2. `onStep(preparing)`; `ensureProfile(currencyCode)`; `updateCurrency(currencyCode)`.
3. Para cada tabla **en este orden**: categorías → presupuestos → movimientos:
   `rows = changedSince(since)`; ordena con **tombstones primero** (`deletedAt != null`) y luego el resto
   (bitácora); `onStep(…)`; sube en lotes de `batchSize`.
4. Solo si todo terminó bien: `syncState.setLastBackupAt(startedAt)` (hora de **inicio**, para no perder cambios
   hechos durante la subida). Si algo lanza, se propaga y `lastBackupAt` no cambia.

### 2.4 `restore_backup.dart`

```dart
@freezed
abstract class RestoreResult with _$RestoreResult {
  const factory RestoreResult({required String? currencyCode, required int categories, required int budgets,
      required int transactions}) = _RestoreResult;
}

class RestoreBackup {
  RestoreBackup({required BackupRepository backup, required CategoryRepository categories, required BudgetRepository budgets,
      required TransactionRepository transactions, required SyncStateRepository syncState, required LocalStore localStore,
      required Clock clock});
  /// NotFoundError('backup') when there is no profile and no categories in the cloud ("No backup found").
  Future<RestoreResult> call();
}
```

1. Descarga perfil, categorías, presupuestos y movimientos (fuera de la transacción local).
2. Sin perfil y sin categorías → `NotFoundError('backup')`.
3. `localStore.runInTransaction`: `mergeFromBackup` de categorías → presupuestos → movimientos (en ese orden por las FKs).
4. `setLastRestoreAt(now)`. **No** toca `lastBackupAt` (bitácora).

## Paso 3 · Datos del respaldo (`lib/features/backup/data/`)

### 3.1 DTOs (`dtos/`)

`CategoryDto`, `BudgetDto`, `TransactionDto`, `ProfileDto` con `@JsonSerializable()` (el `build.yaml` ya pone
`field_rename: snake`). Cada uno con `fromDomain(x, {required String userId})` y `toDomain()`.

- Fechas: `DateTime` → ISO-8601 **UTC** (`toUtc().toIso8601String()`); al leer, `DateTime.parse(...).toUtc()`.
- `occurred_on`: `'YYYY-MM-DD'`; `month`: `'YYYY-MM-01'` (usa `JsonConverter`s propios para `LocalDate` y `YearMonth`).
- `type`: nombre del enum. `color`: `int` (en Postgres es `bigint`, cabe sin problema en un `int` de Dart).
- Se envía `user_id` (el de la sesión); `synced_at` se ignora al leer y no se envía.

### 3.2 `supabase_error_mapper.dart`

```dart
DomainError mapSupabaseError(Object error) { … }
```

| Excepción | `DomainError` |
|---|---|
| `SocketException`, `TimeoutException`, `http.ClientException`, `AuthRetryableFetchException` | `NetworkError` |
| `PostgrestException` con `code` numérico ≥ 500 (incluye 540 = proyecto pausado) o `AuthException` con `statusCode` ≥ 500 | `BackendUnavailableError` |
| `PostgrestException` con `code` `PGRST301`/`PGRST302` o JWT inválido/expirado, `AuthException` 401 | `AuthError(notSignedIn)` |
| `AuthException` con `statusCode == '429'` o `code` `over_email_send_rate_limit`/`over_request_rate_limit` | `AuthError(rateLimited)` |
| `AuthException` con `code` `otp_expired` | `AuthError(invalidCode)` (GoTrue usa el mismo código para incorrecto y caducado) |
| `AuthException` con `code` `email_address_invalid` o `validation_failed` | `AuthError(invalidEmail)` |
| `PostgrestException` `23505` | `DuplicateError('backup')` |
| cualquier otro | `UnknownError(error)` |

Revisa en el código de `supabase_flutter`/`gotrue` instalado los nombres exactos de las clases y de los campos
(`code`, `statusCode`) y ajusta la tabla si difieren (anótalo).

### 3.3 `supabase_auth_repository.dart`

- `sendCode`: `isValidEmail` (si no, `AuthError(invalidEmail)`) → `auth.signInWithOtp(email: email, shouldCreateUser: true)`.
- `verifyCode`: `isValidOtpCode` (si no, `AuthError(invalidCode)`) → `auth.verifyOTP(type: OtpType.email, email: email, token: code)`.
- `watchSignedInEmail`: valor actual y luego `auth.onAuthStateChange.map((s) => s.session?.user.email)`, sin duplicados consecutivos.
- `signOut`: `auth.signOut(scope: SignOutScope.local)`; ignora errores de red.
- Todo envuelto en `try/catch` → `mapSupabaseError`, con `.timeout(const Duration(seconds: 20))`.

### 3.4 `supabase_backup_repository.dart`

- `final db = client.schema('centavo');` — sin sesión (`client.auth.currentUser == null`) → `AuthError(notSignedIn)`.
- `ensureProfile`: `db.rpc('ensure_profile', params: {'p_currency_code': code})`.
- `updateCurrency`: `db.from('profiles').update({'currency_code': code}).eq('id', userId)`.
- `fetchProfile`: `db.from('profiles').select().eq('id', userId).maybeSingle()`.
- Upserts: `db.from('categories').upsert(rows, onConflict: 'user_id,id')`; `transactions` y `budgets` con
  `onConflict: 'id'`. Sin `.select()` (no necesitamos la respuesta).
- Fetch **paginado** (PostgREST devuelve máx. 1000 filas por petición):
  ```dart
  Future<List<Map<String, dynamic>>> _fetchAll(String table) async {
    const page = 1000;
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += page) {
      final chunk = await db.from(table).select().eq('user_id', userId)
          .order('updated_at').order('id').range(from, from + page - 1);
      rows.addAll(chunk);
      if (chunk.length < page) return rows;
    }
  }
  ```
- `deleteAll`: `delete().eq('user_id', userId)` en `transactions`, `budgets` y `categories`, en ese orden.
- Todo con `timeout` de 20 s y `mapSupabaseError`.

### 3.5 Mocks (demo y tests)

- `MockAuthRepository`: acepta cualquier email válido; el código correcto es **`123456`** (otro → `invalidCode`);
  latencia de 600 ms (0 en tests); `failNextWith(DomainError)` para tests.
- `MockBackupRepository`: listas en memoria, latencia de 400 ms por llamada (0 en tests), `failNextWith`.
- En demo, la pantalla de verificación muestra la ayuda "Demo code: 123456".

### 3.6 Providers

- `authRepositoryProvider`, `backupRepositoryProvider`: demo → mocks (keepAlive, invalidados al salir del demo como el
  `MockDataStore`); local → implementaciones Supabase **solo si** `Env.isBackupEnabled`; si no, `StateError`
  (la UI nunca los lee en ese caso; lo garantiza `isBackupAvailableProvider`).
- `syncStateRepositoryProvider`: local → Drift; demo → mock.
- `isBackupAvailableProvider` (`bool`): `mode == demo || Env.isBackupEnabled`.
- Casos de uso: `runBackupProvider`, `restoreBackupProvider`.

## Paso 4 · Presentación (`lib/features/backup/presentation/`)

### 4.1 Estado

- `signedInEmailProvider` (StreamProvider de `watchSignedInEmail`).
- `lastBackupAtProvider` (StreamProvider de `watchLastBackupAt`).
- `BackupController` (`@Riverpod(keepAlive: true)`, estado `AsyncValue<void>`) con:
  - `backUpNow()` → `runBackup(currencyCode: settings.currencyCode, onStep: …)`; el paso actual se publica en
    `backupStepProvider` (`Notifier<BackupStep?>`) para mostrar "Uploading transactions…".
  - `restore({required bool fromWelcome})` → `restoreBackup()`; si trae `currencyCode`, lo guarda en ajustes; si
    `fromWelcome`, además `onboardingCompleted: true` (el redirect lleva al Dashboard).
  - `deleteBackup()` → `backup.deleteAll()` + `syncState.clearLastBackupAt()`.
  - `signOut()` → `auth.signOut()` (no toca datos locales).
  - Una operación a la vez: si `state.isLoading`, ignora nuevas llamadas.
- `AutoBackupController` (`keepAlive`, se activa con `ref.watch` en `CentavoApp`): al construirse y en cada
  `AppLifecycleListener.onResume`, si `mode == local` && `Env.isBackupEnabled` && hay sesión && `autoBackupEnabled`
  && (`lastBackupAt == null` o pasaron ≥ 24 h) && no hay otra operación → `backUpNow()` en silencio (sin SnackBar;
  el error queda visible en la pantalla de Backup). Nunca con la app cerrada.

### 4.2 Rutas y redirect

- En la rama Settings: `backup`, `backup/sign-in`, `backup/verify` (`/settings/backup/...`). `sign-in` y `verify`
  aceptan `?from=welcome`; `verify` recibe además `?email=`.
- Redirect 3 (§5.2): si `!isBackupAvailable` y la ruta empieza por `/settings/backup` → `/settings`
  (o `/welcome` si no hay onboarding). Añade el parámetro a `appRedirect` y sus tests.

### 4.3 `backup_screen.dart` (`/settings/backup`)

- **Sin sesión**: `EmptyState` "Not signed in" con tres beneficios en lista ("Keep your data when you change phones",
  "Your data stays on this device — backup is optional", "Only you can access your backup") y botón
  *Sign in to back up* (key `backup-sign-in`).
- **Con sesión**:
  - Email y "Last backup: Oct 5, 2026, 10:32" / "Last backup: never" (CA3).
  - *Back up now* (key `backup-now`): durante la operación, `LinearProgressIndicator` + texto del paso.
  - `SwitchListTile` *Automatic backup* ("When you open the app, at most once a day") → `autoBackupEnabled`.
  - *Restore from backup* (key `backup-restore`): confirmación "Restore merges your backup into this device. Nothing
    on this device is deleted." → `restore(fromWelcome: false)` → SnackBar con los totales.
  - *Delete my backup* (key `backup-delete`): doble confirmación → `deleteBackup()`.
  - *Sign out* (key `backup-sign-out`): confirmación "Your data stays on this device." → `signOut()`.
- **Errores** (CA1): banner con `messageFor(error)` y *Retry*. `NetworkError` → "You're offline…",
  `BackendUnavailableError` → "The backup service is unavailable right now. Your data is safe on this device."

### 4.4 `sign_in_screen.dart` (`/settings/backup/sign-in`)

- Campo email (key `backup-email`, teclado email, autofill email), *Send code* (key `backup-send-code`) →
  `authRepository.sendCode` → `context.push('/settings/backup/verify?email=…&from=…')`.
- Botón secundario *Explore demo* (key `sign-in-explore-demo`, definición §5.2) → `enterDemo()`.
- Errores por `messageFor` bajo el campo o en SnackBar.

### 4.5 `verify_screen.dart` (`/settings/backup/verify`)

- Texto "We sent a 6-digit code to <email>". Campo de 6 dígitos (key `backup-code`, `keyboardType: number`,
  `maxLength: 6`, autofill `oneTimeCode`). *Verify* (key `backup-verify`).
- *Resend code* con cuenta atrás de 60 s (usa un `Timer` que se cancela en `dispose`).
- Al verificar:
  - `from=settings` (defecto, flujo D): `ensureProfile(currency)` → `backUpNow()` (primer respaldo completo) →
    `context.go(Routes.backup)` → se ve "Last backup: just now".
  - `from=welcome` (flujo E): `restore(fromWelcome: true)`. `NotFoundError('backup')` → diálogo "No backup found"
    con *Start fresh* (→ `/welcome/currency`) y *Cancel* (se queda con la sesión iniciada). Error de red → mensaje + *Retry*.
- Durante la restauración, pantalla de progreso "Restoring your data…" (no se puede volver atrás).

### 4.6 Integración con otras pantallas

- `WelcomeScreen`: añade *Restore from backup* (key `welcome-restore`) **solo si** `Env.isBackupEnabled` →
  `/settings/backup/sign-in?from=welcome`.
- `SettingsScreen`: fila *Backup* (key `settings-backup`) si `isBackupAvailable`, con subtítulo del último respaldo o
  "Not signed in".
- *Erase all local data* (fase 10): si hay sesión, además `authRepository.signOut()` (sin borrar el respaldo).

## Paso 5 · Textos

Todos los de esta fase en `app_en.arb` (beneficios, estados, pasos "Preparing…", "Uploading categories…",
"Uploading budgets…", "Uploading transactions…", diálogos, "No backup found", "Demo code: 123456", "Last backup: {date}",
"Last backup: never", "Resend code in {seconds}s"…).

## Paso 6 · Tests

| Archivo | Casos mínimos |
|---|---|
| `test/features/backup/domain/run_backup_test.dart` | Primera vez sube todo; la segunda solo lo cambiado desde `lastBackupAt`; orden categorías → presupuestos → movimientos; tombstones antes que activas; 1201 movimientos → 3 lotes (500, 500, 201); `ensureProfile` con la moneda; si falla la subida de movimientos, `lastBackupAt` **no** cambia; `lastBackupAt` = hora de inicio (avanza el `FixedClock` durante la subida con un mock que lo haga). |
| `test/features/backup/domain/restore_backup_test.dart` | Sin perfil ni categorías → `NotFoundError`; restaura en base vacía (CA2: mismos datos); LWW (local más nueva se conserva, entrante más nueva gana); no borra filas locales ausentes en la nube; rollback si falla a mitad; no modifica `lastBackupAt`. |
| `test/features/*/data/…_contract.dart` (ampliar) | `changedSince` (null = todo; incluye archivadas y borradas; precisión de milisegundos) y `mergeFromBackup` (inserción, LWW, choque de nombre → "Food 2", choque de presupuesto) en Drift **y** mock. |
| `test/features/backup/data/dtos_test.dart` | `toJson` usa snake_case, fechas UTC ISO, `occurred_on` `YYYY-MM-DD`, `month` `YYYY-MM-01`; ida y vuelta dominio → DTO → dominio sin pérdidas. |
| `test/features/backup/data/supabase_error_mapper_test.dart` | Cada fila de la tabla del paso 3.2. |
| `test/features/backup/presentation/backup_flow_test.dart` | En demo (mocks sin latencia): Settings → Backup → Sign in → email → código `000000` muestra error → `123456` → "Last backup: just now"; *Sign out* conserva los movimientos; *Delete my backup* con doble confirmación. |
| `test/features/backup/presentation/auto_backup_controller_test.dart` | Respalda si pasaron ≥ 24 h; no si < 24 h, sin sesión, con el ajuste apagado o en demo. |
| `test/features/backup/presentation/welcome_restore_test.dart` | Con `Env` simulado habilitado (inyecta `isBackupAvailableProvider`/un flag), *Restore from backup* → verify → restaura y llega al Dashboard; sin respaldo → diálogo "No backup found". |
| `test/integration/backup_roundtrip_test.dart` *(opcional, tag `supabase`)* | Contra Supabase local: genera el OTP de un usuario de prueba con `auth.admin.generateLink(type: magiclink)` usando la secret key leída de `Platform.environment['SUPABASE_SECRET_KEY']` (nunca en el repo), verifica, respalda desde una base en memoria A y restaura en otra B vacía: mismos datos. Se salta si faltan las variables. Configura el tag en `dart_test.yaml` y exclúyelo por defecto. |

## Paso 7 · Verificación manual contra Supabase local

```bash
supabase start && supabase db reset
flutter run --dart-define-from-file=.env.json
```

1. **Flujo D:** en una instalación con datos → Settings → Backup → Sign in con tu email → el código llega a Mailpit
   (`http://127.0.0.1:54324`) → Verify → "Last backup: just now". Comprueba en Studio (`http://127.0.0.1:54323`,
   schema `centavo`) que las filas están y que `synced_at` tiene valor.
2. **Flujo E / CA2:** borra los datos de la app (o usa otro emulador) → Welcome → *Restore from backup* → mismo email
   → los mismos movimientos, categorías y presupuestos. Repite con `demo@centavo.test` (el usuario del seed): debe
   restaurar el dataset de demo.
3. **CA1:** modo avión → *Back up now* → mensaje de "offline" y la app sigue funcionando. `supabase stop` → *Back up now*
   → mensaje de servicio no disponible.
4. **LWW:** edita un movimiento en el dispositivo A y respalda; en B (restaurado antes) edita el mismo movimiento más
   tarde y respalda; restaura en A → gana la edición de B.
5. En demo: todo el flujo con el código `123456`.
6. `flutter run` **sin** `.env.json`: no aparece *Restore from backup* ni *Backup* en local; en demo sí aparece (simulado).

## Paso 8 · Cierre

`00-guia-general.md` §3.3 (con `supabase db reset` y `supabase test db`).

---

## Criterios de terminado

- [ ] F8 CA1–CA4: fallos claros sin romper la app; restaurar en un dispositivo limpio reproduce los datos; fecha del último respaldo visible; RLS verificado (fase 11).
- [ ] Respaldo manual y automático (≥ 24 h, desactivable), restaurar (ajustes y bienvenida), borrar respaldo, cerrar sesión conservando datos.
- [ ] `RunBackup`/`RestoreBackup` con los tests de la tabla; fusión LWW idéntica en Drift y mock.
- [ ] Ninguna excepción de Supabase llega a la UI; ninguna pantalla depende de Supabase para pintarse.
- [ ] Sin `.env.json` el módulo se oculta; en demo se simula.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
