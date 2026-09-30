# Fase 02 · Core

**Rama:** `feat/fase-02-core`
**Objetivo:** todas las piezas compartidas que usarán las features: value objects de dinero y fechas, reloj e ids
inyectables, errores de dominio, configuración de entorno, tema claro/oscuro con fuentes propias, ajustes
persistidos, `AppMode`, router con las 4 tabs (pantallas provisionales) y widgets comunes de estado.
**Referencias:** definición §6.1 (`Money`, `AppSettings`), §6.4, §5.2, §8.1, §8.4, §11, §12.1, §15.
**Requisitos previos:** fase 01 terminada.

> Al terminar: la app abre en `/welcome` (provisional) la primera vez; tras pulsar *Start fresh* (provisional) muestra
> la barra inferior con Dashboard / Transactions / Budgets / Settings; respeta el modo oscuro del sistema.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Value objects de dominio (`lib/core/domain/`)

Todo este paso es **Dart puro** (sin Flutter). Cada clase es `@immutable` (de `package:meta`), con `==`, `hashCode`
y `toString` correctos.

### 1.1 `local_date.dart` — `LocalDate`

Día de calendario sin hora ni zona.

```dart
@immutable
class LocalDate implements Comparable<LocalDate> {
  /// Throws ArgumentError if the date does not exist (e.g. 2026-02-30).
  factory LocalDate(int year, int month, int day);
  factory LocalDate.fromDateTime(DateTime dateTime); // takes y/m/d as they are in dateTime (caller decides local/UTC)
  factory LocalDate.parse(String iso);               // 'YYYY-MM-DD'; throws FormatException otherwise
  final int year, month, day;
  String toIso();                                    // zero-padded 'YYYY-MM-DD'
  DateTime toDateTime();                             // DateTime(year, month, day) local midnight (for date pickers)
  LocalDate addDays(int days);                       // use DateTime.utc internally to avoid DST issues
  int get weekday;                                   // 1 = Monday … 7 = Sunday
  bool isBefore(LocalDate other); bool isAfter(LocalDate other);
}
```

### 1.2 `year_month.dart` — `YearMonth`

```dart
@immutable
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);            // assert 1 <= month <= 12
  factory YearMonth.fromLocalDate(LocalDate date);
  factory YearMonth.parse(String value);             // accepts 'YYYY-MM' and 'YYYY-MM-DD' (uses the first 7 chars)
  final int year, month;
  YearMonth addMonths(int months);                   // negative values allowed; 2026-01 + (-1) = 2025-12
  YearMonth get previous; YearMonth get next;
  LocalDate get firstDay;                            // YYYY-MM-01
  LocalDate get firstDayOfNextMonth;                 // exclusive upper bound for queries
  int get daysInMonth;
  bool contains(LocalDate date);
  String toIso();                                    // 'YYYY-MM'
  String toFirstDayIso();                            // 'YYYY-MM-01' (how budgets.month is persisted)
}
```

### 1.3 `clock.dart` — `Clock`

```dart
abstract interface class Clock {
  DateTime nowUtc();
  LocalDate today();
}

class SystemClock implements Clock {
  const SystemClock();
  @override DateTime nowUtc() => DateTime.now().toUtc();
  @override LocalDate today() => LocalDate.fromDateTime(DateTime.now());
}

/// Deterministic clock for tests and previews. [now] is mutable so tests can advance time.
class FixedClock implements Clock {
  FixedClock(DateTime now, {LocalDate? today}) : now = now.toUtc(), _today = today;
  DateTime now;
  final LocalDate? _today;
  @override DateTime nowUtc() => now;
  @override LocalDate today() => _today ?? LocalDate.fromDateTime(now);
}
```

### 1.4 `id_generator.dart`

```dart
abstract interface class IdGenerator {
  String newId();
}
```

La implementación real va en `lib/core/utils/uuid_id_generator.dart` (`const Uuid().v4()`, paquete `uuid`), fuera de
`domain/`. Para tests crea `test/helpers/sequential_id_generator.dart` (`id-1`, `id-2`, …).

### 1.5 `currency.dart`

```dart
@immutable
class Currency {
  const Currency({required this.code, required this.name, required this.minorUnits});
  final String code; final String name; final int minorUnits;
}

const supportedCurrencies = <Currency>[
  Currency(code: 'USD', name: 'US Dollar', minorUnits: 2),
  Currency(code: 'EUR', name: 'Euro', minorUnits: 2),
  Currency(code: 'MXN', name: 'Mexican Peso', minorUnits: 2),
  Currency(code: 'COP', name: 'Colombian Peso', minorUnits: 2),
  Currency(code: 'ARS', name: 'Argentine Peso', minorUnits: 2),
  Currency(code: 'CLP', name: 'Chilean Peso', minorUnits: 0),
  Currency(code: 'PEN', name: 'Peruvian Sol', minorUnits: 2),
  Currency(code: 'BRL', name: 'Brazilian Real', minorUnits: 2),
];

Currency currencyByCode(String code);                 // throws ArgumentError for unsupported codes
String defaultCurrencyForCountry(String? countryCode); // US→USD, MX→MXN, CO→COP, AR→ARS, CL→CLP, PE→PEN, BR→BRL,
                                                       // euro-area countries→EUR, anything else or null→USD
```

Países del euro: `AT BE CY DE EE ES FI FR GR HR IE IT LT LU LV MT NL PT SI SK`.

### 1.6 `money.dart` — `Money`

```dart
@immutable
class Money implements Comparable<Money> {
  const Money(this.amountMinor, this.currencyCode);
  const Money.zero(this.currencyCode) : amountMinor = 0;
  final int amountMinor;
  final String currencyCode;

  Money operator +(Money other);   // ArgumentError if currencies differ (programming error, not a DomainError)
  Money operator -(Money other);
  bool get isZero; bool get isNegative;
  /// Ratio of this amount to [total] in basis points (10000 = 100 %), integer math, truncated. 0 when total is 0.
  int basisPointsOf(Money total);
  /// Display-only ratio (0.0–n). Never use it to decide business states.
  double ratioOf(Money total);
  @override int compareTo(Money other);
}
```

### 1.7 `amount_parser.dart`

```dart
/// Parses user input ("12.5", "12,50", "1250") into minor units. Accepts at most one '.' or ',' as decimal
/// separator, no thousands separators, no sign, at most 12 integer digits.
/// Throws ValidationError(field, required | invalidFormat | tooManyDecimals). Zero is returned as 0
/// (the caller decides whether 0 is allowed).
int parseAmountToMinor(String input, {required int minorUnits, String field = 'amount'});

/// 1250, 2 → "12.50"; 5000, 0 → "5000". Always '.' as decimal separator (CSV and form prefill).
String formatMinorPlain(int amountMinor, {required int minorUnits});
```

### 1.8 `category_palette.dart`

Conjuntos cerrados de íconos y colores de categoría (definición F3). Los colores se guardan como el ARGB **claro**;
el tema traduce a la variante oscura (paso 5).

```dart
/// Light ARGB values. Index order matters: the theme maps each one to its dark variant by index.
const categoryColorPalette = <int>[
  0xFF2E7D32, // green
  0xFF00796B, // teal
  0xFF1565C0, // blue
  0xFF3949AB, // indigo
  0xFF7B1FA2, // purple
  0xFFC2185B, // pink
  0xFFC62828, // red
  0xFFE65100, // orange
  0xFFB7791F, // amber
  0xFF6D4C41, // brown
  0xFF546E7A, // blue grey
  0xFFB8692E, // copper
];

const categoryIconKeys = <String>[
  'food', 'groceries', 'coffee', 'transport', 'car', 'fuel', 'home', 'utilities', 'phone', 'internet',
  'health', 'pharmacy', 'fitness', 'entertainment', 'games', 'music', 'shopping', 'clothes', 'education',
  'books', 'travel', 'pets', 'gifts', 'kids', 'beauty', 'subscriptions', 'salary', 'freelance',
  'investments', 'other',
];
```

### 1.9 `app_mode.dart`

```dart
enum AppMode { local, demo }
```

## Paso 2 · Errores de dominio (`lib/core/errors/domain_error.dart`)

Clases Dart normales (no freezed), `sealed` para que el `switch` de la UI sea exhaustivo:

```dart
/// Typed errors thrown by repositories and use cases. Presentation switches over them exhaustively.
/// Mapping to the portfolio-wide codes: ValidationError=validation, NotFoundError=notFound,
/// DuplicateError/CategoryInUseError/CategoryTypeMismatchError=conflict, NetworkError/BackendUnavailableError=network,
/// AuthError(notSignedIn)=unauthorized, UnknownError/StorageError=unknown.
sealed class DomainError implements Exception { const DomainError(); }

enum ValidationReason { required, mustBePositive, tooManyDecimals, tooLong, invalidFormat, notAllowed }
final class ValidationError extends DomainError { const ValidationError(this.field, this.reason); final String field; final ValidationReason reason; }
final class NotFoundError extends DomainError { const NotFoundError(this.entity, [this.id]); final String entity; final String? id; }
final class DuplicateError extends DomainError { const DuplicateError(this.entity); final String entity; }
final class CategoryTypeMismatchError extends DomainError { const CategoryTypeMismatchError(); }
final class CategoryInUseError extends DomainError { const CategoryInUseError(); }
final class StorageError extends DomainError { const StorageError([this.cause]); final Object? cause; }
final class NetworkError extends DomainError { const NetworkError([this.cause]); final Object? cause; }
final class BackendUnavailableError extends DomainError { const BackendUnavailableError([this.cause]); final Object? cause; }
enum AuthErrorKind { invalidEmail, invalidCode, codeExpired, rateLimited, notSignedIn }
final class AuthError extends DomainError { const AuthError(this.kind); final AuthErrorKind kind; }
enum BiometricErrorKind { notAvailable, notEnrolled, lockedOut, cancelled }
final class BiometricError extends DomainError { const BiometricError(this.kind); final BiometricErrorKind kind; }
enum ExportErrorReason { emptyRange, writeFailed, shareFailed }
final class ExportError extends DomainError { const ExportError(this.reason); final ExportErrorReason reason; }
final class UnknownError extends DomainError { const UnknownError([this.cause]); final Object? cause; }
```

Añade `toString()` útil en cada una (ayuda en los tests).

## Paso 3 · Configuración de entorno (`lib/core/config/env.dart`)

```dart
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _backupFlag = String.fromEnvironment('BACKUP_ENABLED', defaultValue: 'true');

  /// Backup is available only when both values exist and the flag is not 'false' (definition §15).
  static bool get isBackupEnabled =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty && _backupFlag != 'false';
}
```

Nunca lanza. Sin `.env.json` la app funciona (modo local y demo).

## Paso 4 · Fuentes

1. Descarga los TTF estáticos (subset latino) a `assets/fonts/`:
   ```bash
   cd assets/fonts
   for w in 500 600 700 800; do curl -fL -o "Manrope-$w.ttf" "https://cdn.jsdelivr.net/fontsource/fonts/manrope@latest/latin-$w-normal.ttf"; done
   for w in 400 500 600; do curl -fL -o "Inter-$w.ttf" "https://cdn.jsdelivr.net/fontsource/fonts/inter@latest/latin-$w-normal.ttf"; done
   file *.ttf      # each one must say "TrueType Font data"
   cd ../..
   ```
   Si la descarga falla o `file` no dice TrueType: **🙋 Acción del autor** → descargar Manrope (500, 600, 700, 800) e
   Inter (400, 500, 600) estáticas desde fonts.google.com y guardarlas con esos nombres.
2. Añade las licencias: `assets/fonts/OFL-Manrope.txt` y `assets/fonts/OFL-Inter.txt` (SIL Open Font License; el texto
   está en el repo de cada fuente en GitHub). Regístralas en `main.dart` con `LicenseRegistry.addLicense` en la fase 10
   (pantalla *About*); por ahora solo guarda los archivos.
3. `pubspec.yaml` → `flutter:`:
   ```yaml
   fonts:
     - family: Manrope
       fonts:
         - { asset: assets/fonts/Manrope-500.ttf, weight: 500 }
         - { asset: assets/fonts/Manrope-600.ttf, weight: 600 }
         - { asset: assets/fonts/Manrope-700.ttf, weight: 700 }
         - { asset: assets/fonts/Manrope-800.ttf, weight: 800 }
     - family: Inter
       fonts:
         - { asset: assets/fonts/Inter-400.ttf, weight: 400 }
         - { asset: assets/fonts/Inter-500.ttf, weight: 500 }
         - { asset: assets/fonts/Inter-600.ttf, weight: 600 }
   ```

## Paso 5 · Tema (`lib/core/theme/`)

### 5.1 `app_colors.dart`

Constantes de la definición §11 (única carpeta donde se permiten `Color(0x…)`):

| Token | Claro | Oscuro |
|---|---|---|
| primary | `0xFF1F6F5C` | `0xFF6FD3B5` |
| secondary | `0xFFB8692E` | `0xFFE9A56B` |
| background | `0xFFF7F6F2` | `0xFF0F1412` |
| surface | `0xFFFFFFFF` | `0xFF18201D` |
| onSurface | `0xFF1B1F1D` | `0xFFE6EAE7` |
| income | `0xFF2E8B57` | `0xFF7BD69A` |
| expense | `0xFFC8453B` | `0xFFFF8A7F` |
| warning | `0xFFD99A1E` | `0xFFF2C055` |
| error | `0xFFB3261E` | `0xFFF2B8B5` |

Variantes **oscuras** de la paleta de categorías, en el mismo orden que `categoryColorPalette`:
`0xFF81C784, 0xFF4DB6AC, 0xFF64B5F6, 0xFF9FA8DA, 0xFFCE93D8, 0xFFF48FB1, 0xFFEF9A9A, 0xFFFFB74D, 0xFFFFD54F,
0xFFBCAAA4, 0xFFB0BEC5, 0xFFE9A56B`.

### 5.2 `centavo_colors.dart` — `ThemeExtension<CentavoColors>`

Campos: `income`, `expense`, `warning`, `onTrack` (= income), `exceeded` (= error), `chartGrid`, y el método
`Color category(int storedArgb)` que devuelve el color claro tal cual en tema claro y, en oscuro, la variante del mismo
índice (si el valor no está en la paleta, devuelve `Color(storedArgb)`). Implementa `copyWith` y `lerp`.
Acceso: `extension CentavoColorsX on BuildContext { CentavoColors get colors => Theme.of(this).extension<CentavoColors>()!; }`.

### 5.3 `app_theme.dart`

```dart
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) { … }
}
```

- `ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(primary:, secondary:, surface:, onSurface:, error:)`
  con los valores de la tabla según el brillo.
- `scaffoldBackgroundColor` = background. `useMaterial3: true`.
- `textTheme`: `display*`, `headline*`, `title*` con `fontFamily: 'Manrope'` (pesos 700/800 en display/headline, 600 en
  title); `body*` y `label*` con `fontFamily: 'Inter'`. Parte de `Typography.material2021().black/white` según el brillo
  y aplica `.apply(bodyColor: onSurface, displayColor: onSurface)`.
- `extensions: [CentavoColors(...)]`.
- Estilos comunes: `CardTheme` (sin elevación, borde redondeado 16, color surface), `InputDecorationTheme` (outline,
  radio 12), `NavigationBarTheme`, `FloatingActionButtonThemeData` (primary).

## Paso 6 · Ajustes (`lib/features/settings/`)

### 6.1 Dominio (`domain/`)

`app_settings.dart` (freezed):

```dart
enum AppThemePreference { system, light, dark }

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default('USD') String currencyCode,
    @Default(AppThemePreference.system) AppThemePreference themePreference,
    @Default(false) bool biometricLockEnabled,
    @Default(false) bool onboardingCompleted,
    @Default(true) bool autoBackupEnabled,
  }) = _AppSettings;
}
```

`settings_repository.dart`:

```dart
abstract interface class SettingsRepository {
  AppSettings load();                       // synchronous: the router needs it before the first frame
  Future<void> save(AppSettings settings);
  Future<void> clear();                     // back to defaults (used by "Erase all local data")
}
```

### 6.2 Datos (`data/`)

- `prefs_settings_repository.dart`: usa `SharedPreferences` (API clásica, lecturas síncronas tras `getInstance()`).
  Claves: `settings.currencyCode`, `settings.themePreference` (nombre del enum), `settings.biometricLockEnabled`,
  `settings.onboardingCompleted`, `settings.autoBackupEnabled`. Valores ausentes → default del modelo.
  Un valor de enum desconocido → default (no lanzar).
- `in_memory_settings_repository.dart`: guarda un `AppSettings` en memoria; constructor con valor inicial opcional.

## Paso 7 · Providers base (`lib/core/di/`)

`repository_providers.dart` — **composition root** (el único archivo, junto con `main.dart`, que importa `data/` de
varias features):

```dart
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidIdGenerator();

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => PrefsSettingsRepository(ref.watch(sharedPreferencesProvider));
```

`app_mode_provider.dart`:

```dart
@Riverpod(keepAlive: true)
class AppModeController extends _$AppModeController {
  @override
  AppMode build() => AppMode.local;   // never persisted (definition §8.3)
  void enterDemo() => state = AppMode.demo;
  void exitDemo() => state = AppMode.local;
}
```

`lib/features/settings/presentation/settings_controller.dart`:

```dart
@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> change(AppSettings Function(AppSettings current) update) async {
    final next = update(state);
    await ref.read(settingsRepositoryProvider).save(next);
    state = next;
  }
}
```

`lib/core/presentation/selected_month_provider.dart`: `@Riverpod(keepAlive: true) class SelectedMonth` con estado
`YearMonth` (inicial: mes de `clock.today()`), métodos `previous()`, `next()`, `set(YearMonth)`.

> Los nombres generados serán `clockProvider`, `settingsControllerProvider`, `appModeControllerProvider`,
> `selectedMonthProvider`, etc. Comprueba los nombres reales en los `.g.dart`.

## Paso 8 · Localización y textos

1. `lib/core/presentation/l10n_extension.dart`:
   `extension L10nX on BuildContext { AppLocalizations get l10n => AppLocalizations.of(this); }`
2. Añade a `app_en.arb` (en inglés, con descripciones `@key` solo si aportan):
   - Tabs: `tabDashboard` "Dashboard", `tabTransactions` "Transactions", `tabBudgets` "Budgets", `tabSettings` "Settings".
   - Comunes: `retry` "Retry", `cancel` "Cancel", `save` "Save", `delete` "Delete", `undo` "Undo", `loading` "Loading…".
   - Errores (uno por caso de `DomainError`):
     `errorNotFound` "This item no longer exists." · `errorDuplicate` "An item with that name already exists." ·
     `errorCategoryTypeMismatch` "The category doesn't match the transaction type." ·
     `errorCategoryInUse` "This category has transactions, so it can only be archived." ·
     `errorStorage` "Something went wrong saving on this device. Please try again." ·
     `errorNetwork` "You're offline. Check your connection and try again." ·
     `errorBackendUnavailable` "The backup service is unavailable right now. Your data is safe on this device." ·
     `errorAuthInvalidEmail` "Enter a valid email address." · `errorAuthInvalidCode` "The code is invalid or has expired." ·
     `errorAuthCodeExpired` "The code has expired. Request a new one." ·
     `errorAuthRateLimited` "Too many attempts. Wait a few minutes and try again." ·
     `errorAuthNotSignedIn` "Sign in to use backup." ·
     `errorBiometricNotAvailable` "Set up a screen lock on this device to use app lock." ·
     `errorBiometricNotEnrolled` "No fingerprint or face is enrolled on this device." ·
     `errorBiometricLockedOut` "Too many attempts. Unlock your device and try again." ·
     `errorBiometricCancelled` "Authentication cancelled." ·
     `errorExportEmptyRange` "Nothing to export for this range." · `errorExportWriteFailed` "Couldn't create the file." ·
     `errorExportShareFailed` "Couldn't open the share sheet." · `errorValidation` "Please check the highlighted fields." ·
     `errorUnknown` "Something went wrong. Please try again."
   - Validación por campo: `validationRequired` "Required", `validationMustBePositive` "Must be greater than 0",
     `validationTooManyDecimals` "Too many decimal places", `validationTooLong` "Too long",
     `validationInvalidFormat` "Invalid value", `validationNotAllowed` "Not allowed".
   - Provisionales: `welcomeTitle` "Welcome to Centavo", `startFresh` "Start fresh", `comingSoon` "Coming soon".
3. `lib/core/presentation/error_messages.dart`:
   - `String errorMessage(DomainError error, AppLocalizations l10n)` con `switch` **exhaustivo** sobre el tipo
     (y sobre `kind`/`reason` donde aplique). **Sin** `default`: si mañana se añade un error, el analyzer avisa.
   - `String validationMessage(ValidationReason reason, AppLocalizations l10n)`.
   - `String messageFor(Object error, AppLocalizations l10n)` → `errorMessage` si es `DomainError`, si no `errorUnknown`.

## Paso 9 · Widgets comunes (`lib/core/presentation/`)

| Archivo | Widget / función | Detalle |
|---|---|---|
| `money_format.dart` | `String formatMoney(Money money, {bool signed = false})` | `NumberFormat.simpleCurrency(locale: 'en_US', name: code, decimalDigits: minorUnits)`. La conversión a `double` es **solo para mostrar**. `signed` antepone `+`/`−`. |
| `money_text.dart` | `MoneyText(money, {type, style})` | `type: MoneyTone.income/expense/neutral` → color de `CentavoColors`; `fontFeatures: [FontFeature.tabularFigures()]`. |
| `skeleton.dart` | `SkeletonBox(width, height, radius)`, `SkeletonList(itemCount)` | Cajas con `colorScheme.surfaceContainerHighest`; sin animación (evita timers en tests). |
| `empty_state.dart` | `EmptyState(icon, title, message?, actionLabel?, onAction?)` | Centrado, ícono grande `onSurfaceVariant`. |
| `error_state.dart` | `ErrorState(message, onRetry?)` | Ícono de error + mensaje + botón `retry` (key `error-retry`). |
| `async_state_view.dart` | `AsyncStateView<T>` | Ver abajo. |
| `month_selector.dart` | `MonthSelector(month, onChanged, {maxMonth})` | Flechas prev/next (keys `month-prev`, `month-next`) y etiqueta `DateFormat.yMMMM('en_US')` (key `month-label`). *Next* deshabilitado si `month >= maxMonth`. |

```dart
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.value, required this.data, this.isEmpty, this.empty, this.loading, this.onRetry, super.key,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;        // default: SkeletonList(itemCount: 6)
  final VoidCallback? onRetry;
  // value.when(data: empty-or-data, loading: loading, error: ErrorState(messageFor(error, l10n), onRetry))
}
```

## Paso 10 · Router (`lib/core/router/`)

### 10.1 `routes.dart`

Constantes de ruta de la definición §5.2 (todas, aunque se registren en fases posteriores):

```dart
abstract final class Routes {
  static const welcome = '/welcome';
  static const welcomeCurrency = '/welcome/currency';
  static const lock = '/lock';
  static const dashboard = '/dashboard';
  static const transactions = '/transactions';
  static const transactionNew = '/transactions/new';
  static String transactionEdit(String id) => '/transactions/$id';
  static const budgets = '/budgets';
  static const budgetEdit = '/budgets/edit';
  static const settings = '/settings';
  static const categories = '/settings/categories';
  static const categoryNew = '/settings/categories/new';
  static String categoryEdit(String id) => '/settings/categories/$id';
  static const export = '/settings/export';
  static const backup = '/settings/backup';
  static const backupSignIn = '/settings/backup/sign-in';
  static const backupVerify = '/settings/backup/verify';
  static const about = '/settings/about';
}
```

### 10.2 `app_redirect.dart` — función **pura** (testeable sin widgets)

```dart
String? appRedirect({required String location, required AppSettings settings, required AppMode mode}) {
  final onboarded = mode == AppMode.demo || settings.onboardingCompleted;
  final inWelcome = location.startsWith(Routes.welcome);
  final inRestoreAuth = location.startsWith(Routes.backupSignIn) || location.startsWith(Routes.backupVerify);
  if (!onboarded && !inWelcome && !inRestoreAuth) return Routes.welcome;
  if (onboarded && inWelcome) return Routes.dashboard;
  return null;
}
```

(La regla de bloqueo se añade en la fase 10 y la de respaldo deshabilitado en la fase 12.)

### 10.3 `app_router.dart`

```dart
final rootNavigatorKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(settingsControllerProvider, (_, _) => refresh.value++)
    ..listen(appModeControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      location: state.uri.path,
      settings: ref.read(settingsControllerProvider),
      mode: ref.read(appModeControllerProvider),
    ),
    routes: [
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.dashboard, builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.transactions, builder: (_, _) => const TransactionsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.budgets, builder: (_, _) => const BudgetsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen())]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
```

- El router importa pantallas de `features/*/presentation`: es parte del composition root, está permitido.
- Si tu versión de Dart no acepta `(_, _)` (wildcards), usa `(_, __)`.

### 10.4 Shell y pantallas provisionales

- `lib/core/router/app_shell.dart`: `Scaffold` con `body: navigationShell` y `NavigationBar` de 4 destinos
  (íconos `space_dashboard`, `receipt_long`, `savings`, `settings`; etiquetas de l10n; keys `tab-dashboard`,
  `tab-transactions`, `tab-budgets`, `tab-settings`). `onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex)`.
- Pantallas provisionales (se reemplazan en sus fases), cada una en su feature:
  `dashboard/presentation/dashboard_screen.dart`, `transactions/presentation/transactions_screen.dart`,
  `budgets/presentation/budgets_screen.dart`, `settings/presentation/settings_screen.dart` → `Scaffold` con `AppBar`
  (título de la tab) y `EmptyState` con `comingSoon`.
- `onboarding/presentation/welcome_screen.dart` provisional: título `welcomeTitle` y un `FilledButton` `startFresh`
  (key `welcome-start-fresh`) que hace
  `ref.read(settingsControllerProvider.notifier).change((s) => s.copyWith(onboardingCompleted: true))`.
  La fase 06 lo reemplaza por el flujo real.

## Paso 11 · `app.dart` y `main.dart`

`CentavoApp` pasa a `ConsumerWidget`:

```dart
return MaterialApp.router(
  onGenerateTitle: (context) => context.l10n.appTitle,
  routerConfig: ref.watch(appRouterProvider),
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: switch (ref.watch(settingsControllerProvider.select((s) => s.themePreference))) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  },
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  debugShowCheckedModeBanner: false,
);
```

`main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CentavoApp(),
    ),
  );
}
```

## Paso 12 · Helpers de test

- `test/helpers/sequential_id_generator.dart`.
- `test/helpers/pump_app.dart`:
  `Future<void> pumpApp(WidgetTester tester, Widget child, {List overrides = const []})` → envuelve en
  `ProviderScope(overrides: …)` + `MaterialApp` con `AppTheme.light()`, delegados de l10n y `home: child`.
  (Ajusta el tipo de `overrides` al que exponga tu versión de Riverpod.)
- `test/helpers/test_overrides.dart`: lista base de overrides para tests de app completa:
  `settingsRepositoryProvider` → `InMemorySettingsRepository(...)`, `clockProvider` → `FixedClock(DateTime.utc(2026, 10, 15, 12))`.

## Paso 13 · Tests

| Archivo | Qué comprueba |
|---|---|
| `test/core/domain/local_date_test.dart` | `parse`/`toIso` ida y vuelta; fecha inválida lanza; `addDays` cruzando mes, año y cambio de horario; `weekday`. |
| `test/core/domain/year_month_test.dart` | `addMonths(±n)` cruzando años; `previous`/`next`; `daysInMonth` (feb bisiesto 2028 = 29); `contains`; `toFirstDayIso`; `parse` de ambos formatos. |
| `test/core/domain/money_test.dart` | suma/resta; monedas distintas lanzan `ArgumentError`; `basisPointsOf` (1/3 → 3333, total 0 → 0); `compareTo`. |
| `test/core/domain/amount_parser_test.dart` | `"12.5"`→1250, `"12,50"`→1250, `"1250"`→125000, `"0"`→0; CLP: `"5000"`→5000 y `"50.5"` → `tooManyDecimals`; `""` → `required`; `"1.2.3"`, `"-5"`, `"1,000.00"`, `"abc"` → `invalidFormat`; `formatMinorPlain` (1250,2 → "12.50"; 5,2 → "0.05"; 5000,0 → "5000"). |
| `test/core/domain/currency_test.dart` | `currencyByCode` (CLP 0 decimales, desconocida lanza); `defaultCurrencyForCountry` (ES→EUR, MX→MXN, JP→USD, null→USD). |
| `test/core/router/app_redirect_test.dart` | sin onboarding → `/welcome`; sin onboarding en `/settings/backup/sign-in` → `null`; onboarded en `/welcome` → `/dashboard`; demo sin onboarding en `/dashboard` → `null`. |
| `test/features/settings/prefs_settings_repository_test.dart` | con `SharedPreferences.setMockInitialValues({})`: defaults; `save` + `load` ida y vuelta; enum desconocido → default; `clear`. |
| `test/core/presentation/async_state_view_test.dart` | loading muestra skeleton; data vacía muestra `empty`; error `NetworkError` muestra su mensaje y *Retry* llama al callback. |
| `test/app_smoke_test.dart` (reemplaza el de la fase 01) | con overrides de test y `onboardingCompleted: false` aparece *Start fresh*; al pulsarlo aparece la `NavigationBar` con las 4 tabs. |

## Paso 14 · Verificación manual

`flutter run`: primera apertura en *Welcome*; *Start fresh* → tabs; cambiar entre tabs; activar modo oscuro del sistema
y comprobar que fondo, textos y barra cambian. Cierra y reabre la app: debe entrar directo a Dashboard (ajuste persistido).

## Paso 15 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] `LocalDate`, `YearMonth`, `Money`, `Currency`, `Clock`, `IdGenerator`, `parseAmountToMinor` implementados en `core/domain` sin imports de Flutter, con tests.
- [ ] `DomainError` sellado con todos los casos; `errorMessage` exhaustivo sin `default`.
- [ ] Tema claro y oscuro con los tokens de §11, `CentavoColors` y fuentes Manrope + Inter empaquetadas.
- [ ] Ajustes persistidos en `SharedPreferences`; `InMemorySettingsRepository` disponible para tests/demo.
- [ ] Router con redirect puro y testeado; shell con 4 tabs; bienvenida provisional.
- [ ] `AsyncStateView`, `EmptyState`, `ErrorState`, `SkeletonList`, `MonthSelector`, `MoneyText` creados.
- [ ] Ningún texto de UI literal fuera de `app_en.arb`.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
