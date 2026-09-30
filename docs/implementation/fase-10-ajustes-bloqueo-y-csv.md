# Fase 10 · Ajustes, bloqueo biométrico y exportar CSV

**Rama:** `feat/fase-10-ajustes-bloqueo-y-csv`
**Objetivo:** pantalla de ajustes completa (tema, moneda, bloqueo, categorías, exportar, borrar datos, about),
bloqueo con biometría/PIN del dispositivo al abrir y al volver tras ≥ 30 s, contenido oculto en recientes
(`FLAG_SECURE`) y exportación de movimientos a CSV con la hoja de compartir del sistema.
**Referencias:** definición §3.1 F6, F7 y F10, §5.1 flujo G, §5.2 (redirect 2), §6.4 (`BiometricError`, `ExportError`), §12.1.
**Requisitos previos:** fase 09 terminada. Emulador Android con **bloqueo de pantalla (PIN) y huella configurados**
(Settings del emulador → Security). Si no se puede: **🙋 Acción del autor**.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Dependencia `package_info_plus`

```bash
flutter pub add package_info_plus
```

Para mostrar la versión en *About*. Anótala en la bitácora como dependencia añadida (no estaba en §9).
El enlace al repo se copia al portapapeles (`Clipboard.setData`), así que **no** se añade `url_launcher`.

## Paso 2 · Seguridad: dominio y datos (`lib/features/security/`)

### 2.1 `domain/`

```dart
abstract interface class BiometricRepository {
  /// True when the device has a screen lock (PIN/pattern/password) or biometrics configured.
  Future<bool> isDeviceSecure();
  /// Shows the system prompt (biometrics with device-credential fallback).
  /// Throws BiometricError(cancelled | notAvailable | notEnrolled | lockedOut).
  Future<void> authenticate({required String reason});
}

abstract interface class SecureWindowService {
  /// Android FLAG_SECURE: hides the app content in the recents screen and blocks screenshots.
  Future<void> setSecure({required bool secure});
}
```

### 2.2 `data/`

- `local_auth_biometric_repository.dart`:
  - `isDeviceSecure()` → `LocalAuthentication().isDeviceSupported()`.
  - `authenticate` → `authenticate(localizedReason: reason, …)` con **`biometricOnly: false`** (permite PIN/patrón,
    definición F6) y la opción de mantener la autenticación si la app pasa a segundo plano (`stickyAuth` o su
    equivalente). **Revisa la API de la versión instalada** (en `local_auth` 3.x cambiaron los parámetros y las
    excepciones pasaron a `LocalAuthException` con un enum de códigos).
  - Resultado `false` → `BiometricError(cancelled)`. Traduce los códigos de error: no disponible / sin credencial
    → `notAvailable`; sin huellas → `notEnrolled`; bloqueado (temporal o permanente) → `lockedOut`; cualquier otro →
    `cancelled`. Nunca deja escapar `PlatformException`.
- `mock_biometric_repository.dart`: configurable (`deviceSecure = true`, `nextResult`), por defecto siempre OK.
- `method_channel_secure_window_service.dart`: `MethodChannel('com.malpidev.centavo/secure_window')`, método
  `setSecure` con argumento `{'secure': bool}`. Solo en Android (`defaultTargetPlatform == TargetPlatform.android`);
  en otras plataformas no hace nada. Captura `MissingPluginException`/`PlatformException` y las ignora (no es crítico).
- `noop_secure_window_service.dart` (tests y demo).

### 2.3 Android (`MainActivity.kt`)

```kotlin
package com.malpidev.centavo

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.malpidev.centavo/secure_window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.argument<Boolean>("secure") == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

### 2.4 Providers

En `repository_providers.dart`: `biometricRepositoryProvider` (switch por `AppMode`: local → `LocalAuth…`,
demo → `MockBiometricRepository()`), `secureWindowServiceProvider` (local → method channel, demo → noop).

## Paso 3 · Control del bloqueo (`lib/features/security/presentation/lock_controller.dart`)

Estado: `bool` (`true` = bloqueada). Reglas (definición F6 y flujo G):

```dart
@Riverpod(keepAlive: true)
class LockController extends _$LockController {
  static const relockAfter = Duration(seconds: 30);
  DateTime? _backgroundedAt;
  bool _authenticating = false;

  @override
  bool build() {
    // Cold start: locked if the lock is enabled. read (not watch) so settings changes don't re-lock.
    final enabled = ref.read(settingsControllerProvider).biometricLockEnabled;
    ref.listen(settingsControllerProvider.select((s) => s.biometricLockEnabled), (_, isEnabled) {
      if (!isEnabled) state = false;
    });
    ref.listen(appModeControllerProvider, (_, _) => state = false);   // entering/leaving demo never locks
    final listener = AppLifecycleListener(onHide: onBackgrounded, onShow: onForegrounded);
    ref.onDispose(listener.dispose);
    return enabled;
  }

  @visibleForTesting
  void onBackgrounded() { if (!_authenticating) _backgroundedAt = ref.read(clockProvider).nowUtc(); }

  @visibleForTesting
  void onForegrounded() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (_authenticating || since == null) return;
    final enabled = ref.read(settingsControllerProvider).biometricLockEnabled;
    if (enabled && ref.read(clockProvider).nowUtc().difference(since) >= relockAfter) state = true;
  }

  /// Throws BiometricError on failure; the lock screen shows the message.
  Future<void> unlock(String reason) async {
    _authenticating = true;
    try {
      await ref.read(biometricRepositoryProvider).authenticate(reason: reason);
      state = false;
    } finally {
      _authenticating = false;
    }
  }
}
```

- `_authenticating` evita que el propio diálogo del sistema (que pausa la app) vuelva a bloquearla.
- Si `onHide`/`onShow` no existen en tu versión de Flutter, usa `onPause`/`onResume`.
- Sincroniza `FLAG_SECURE` (CA3 de F6): en `CentavoApp`, `ref.listen(settingsControllerProvider.select((s) => s.biometricLockEnabled), …)`
  con `fireImmediately: true` → `secureWindowService.setSecure(secure: enabled)`.

## Paso 4 · Router: redirect de bloqueo y rutas nuevas

1. `appRedirect` recibe `required bool isLocked` y añade, **después** de la regla de onboarding:
   ```dart
   final atLock = location == Routes.lock;
   if (onboarded && isLocked && !atLock) return '${Routes.lock}?from=${Uri.encodeComponent(location)}';
   if (atLock && !isLocked) return /* from query param, if it starts with '/' */ ?? Routes.dashboard;
   ```
   Para leer `from`, pasa también `state.uri` (o el query param) a `appRedirect`. Actualiza sus tests.
2. El router escucha `lockControllerProvider` (como ya hace con ajustes y modo).
3. Rutas nuevas: `/lock` (raíz, fuera del shell) y, en la rama Settings, `export` y `about`
   (`/settings/export`, `/settings/about`).

## Paso 5 · Pantalla de bloqueo (`lock_screen.dart`)

- Fondo `primary` (claro) / `background` (oscuro), ícono de candado o de la app, "Centavo is locked", botón *Unlock*
  (key `lock-unlock`).
- Al mostrarse, lanza `unlock` automáticamente una vez (`addPostFrameCallback`).
- Error `BiometricError` → mensaje bajo el botón (`errorMessage`); `cancelled` → se queda en la pantalla (flujo G).
- `PopScope(canPop: false)`: el botón atrás no la salta.

## Paso 6 · Pantalla de ajustes (`lib/features/settings/presentation/settings_screen.dart`)

Lista con secciones (keys entre paréntesis):

| Sección | Elemento | Comportamiento |
|---|---|---|
| Appearance | *Theme* (`settings-theme`) | Diálogo *System / Light / Dark* → `themePreference`. |
| Appearance | *Currency* (`settings-currency`) | Diálogo con `supportedCurrencies` → si cambia, confirmación "Changing the currency only changes how amounts are displayed. Amounts are not converted." → guardar. |
| Security | *App lock* (`settings-app-lock`) | `SwitchListTile`. Si `isDeviceSecure()` es `false`: deshabilitado con subtítulo "Set up a screen lock on this device first" (CA1). Al activar: `authenticate(reason: 'Confirm to turn on app lock')` → si OK guarda `true` (CA2); si falla, SnackBar y queda en `false`. Al desactivar: guarda `false`. |
| Data | *Categories* (`settings-categories`) | → `/settings/categories`. |
| Data | *Export CSV* (`settings-export`) | → `/settings/export`. |
| Data | *Backup* | **No se añade todavía** (fase 12, solo si `Env.isBackupEnabled`). |
| Data | *Erase all local data* (`settings-erase`) | Solo en modo local. Doble confirmación (paso 8). |
| Demo | *Exit demo* | Solo en modo demo (en lugar de *Erase*). |
| About | *About Centavo* (`settings-about`) | → `/settings/about`. |

`isDeviceSecure` se obtiene con un `FutureProvider` (`deviceSecureProvider`) con estado de carga en el switch.

## Paso 7 · Exportar CSV (`lib/features/export/`)

### 7.1 `data/file_share_csv_service.dart` (implementa `CsvShareService`)

1. `final dir = await getTemporaryDirectory();` → `File('${dir.path}/${document.fileName}')` →
   `writeAsString(document.content, encoding: utf8, flush: true)` (el BOM ya viene en el contenido).
   `FileSystemException` → `ExportError(writeFailed)`.
2. Compartir con `share_plus` con `XFile(path, mimeType: 'text/csv')` y `subject: fileName`. **Revisa la API de la
   versión instalada** (en versiones recientes es `SharePlus.instance.share(ShareParams(files: […]))`; en antiguas,
   `Share.shareXFiles`). Cualquier excepción → `ExportError(shareFailed)`.
3. `mock_csv_share_service.dart`: guarda el último documento recibido (para tests).

Provider `csvShareServiceProvider`: siempre la implementación real (también en demo: exportar los datos de ejemplo es
inofensivo y demuestra la función); los tests lo sobreescriben con el mock.

### 7.2 `presentation/export_screen.dart`

- Opciones (`RadioListTile`, keys `export-range-current`, `export-range-month`, `export-range-all`): *This month*,
  *Choose a month* (muestra un `MonthSelector` con `maxMonth` = mes actual) y *All time*.
- Botón *Export CSV* (key `export-run`) → `ExportController.export(range)`: `exportTransactionsCsvProvider` →
  `csvShareServiceProvider.share(doc)`. Botón en progreso durante la operación.
- `ExportError(emptyRange)` → mensaje en línea "Nothing to export for this range" (CA2: no se genera archivo).
  Otros errores → SnackBar.
- Pie informativo: "Columns: date, type, category, amount, currency, note".

## Paso 8 · Borrar todos los datos locales

`lib/features/settings/presentation/erase_data.dart`:
1. Diálogo 1: "Erase all data?" / "This deletes all transactions, categories and budgets on this device."
2. Diálogo 2: "This can't be undone" con botón destructivo *Erase everything* (key `erase-confirm`).
3. Acciones: `localStore.eraseAll()` → `settingsRepository.clear()` → `ref.invalidate(settingsControllerProvider)`.
   (La fase 12 añade aquí el cierre de sesión del respaldo.) El redirect lleva a `/welcome`.

## Paso 9 · About (`about_screen.dart`)

Nombre, tagline, versión (`PackageInfo.fromPlatform()` → `version+buildNumber`), fila "Source code" con la URL
`https://github.com/malpi-dev/Centavo` que al tocar la copia al portapapeles (SnackBar "Link copied"), y *Open-source
licenses* → `showLicensePage`. En `main.dart` registra las licencias de las fuentes:

```dart
LicenseRegistry.addLicense(() async* {
  for (final font in ['Manrope', 'Inter']) {
    final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
    yield LicenseEntryWithLineBreaks([font], text);
  }
});
```

(Declara los `.txt` como assets en `pubspec.yaml`.)

## Paso 10 · Textos

Todos los de esta fase en `app_en.arb` (títulos de sección, opciones de tema, diálogos, mensajes de bloqueo y exportación, about).

## Paso 11 · Tests

| Archivo | Casos mínimos |
|---|---|
| `test/features/security/presentation/lock_controller_test.dart` | Arranque con lock activo → bloqueada; background 29 s → sigue desbloqueada; 30 s → bloqueada; `unlock` con mock OK → desbloqueada; mock `cancelled` → sigue bloqueada y lanza; desactivar el ajuste desbloquea; durante `unlock` el ciclo de vida no re-bloquea; cambiar de modo desbloquea. Usa `FixedClock` y llama a `onBackgrounded`/`onForegrounded` directamente. |
| `test/core/router/app_redirect_test.dart` (ampliar) | Bloqueada en `/transactions` → `/lock?from=%2Ftransactions`; desbloqueada en `/lock?from=/budgets` → `/budgets`; `from` inválido → `/dashboard`; sin onboarding la regla de bloqueo no aplica. |
| `test/features/security/data/local_auth_biometric_repository_test.dart` | Con `LocalAuthentication` mockeado (mocktail; inyéctalo por constructor): `false` → `cancelled`; cada código de error → su `BiometricErrorKind`. |
| `test/features/settings/presentation/settings_screen_test.dart` | Tema *Dark* cambia `themeMode`; cambiar moneda muestra la advertencia y guarda; *App lock* deshabilitado si el dispositivo no es seguro; activarlo llama a `authenticate` y a `setSecure(true)`; en demo aparece *Exit demo* y no *Erase*. |
| `test/features/export/presentation/export_screen_test.dart` | Mes vacío → "Nothing to export…" y el mock no recibe nada; *This month* con datos → el mock recibe `centavo-transactions-2026-10.csv` con cabecera correcta; *All time* → nombre `…-all-<fecha>.csv`. |
| `test/features/export/data/file_share_csv_service_test.dart` | Escribe el archivo con BOM en un directorio temporal (inyecta el directorio y la función de compartir por constructor para poder probarlo). |
| `test/features/settings/presentation/erase_data_test.dart` | Cancelar en cualquiera de los dos diálogos no borra; confirmar ambos vacía la base, resetea ajustes y lleva a Welcome. |

## Paso 12 · Verificación manual en Android

1. Activar *App lock* (pide huella/PIN) → cerrar la app → reabrir → pantalla de bloqueo → desbloquear.
2. Ir a Inicio 10 s y volver → no bloquea. Esperar 35 s → bloquea.
3. Con el lock activo, abrir *recientes*: la miniatura de Centavo está en negro/oculta (CA3).
4. En un emulador sin bloqueo de pantalla, el switch está deshabilitado con la explicación (CA1).
5. Exportar *This month* → compartir a Drive/Gmail o guardar en archivos → abrir en Google Sheets: columnas y acentos
   correctos (CA1 de F7). **🙋 Acción del autor** si no hay una cuenta de Google en el emulador para comprobarlo.
6. *Erase all local data* → vuelve a Welcome.

## Paso 13 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] F6 CA1–CA3: switch deshabilitado sin bloqueo de pantalla; confirmación al activar; contenido oculto en recientes con el lock activo; bloqueo al abrir y tras ≥ 30 s en segundo plano.
- [ ] F7 CA1–CA2: CSV correcto (BOM, `\r\n`, RFC 4180) compartido con la hoja del sistema; rango vacío avisa sin generar archivo.
- [ ] F10 (salvo *Backup*, fase 12): tema, moneda con advertencia, categorías, exportar, borrar datos con doble confirmación, about con versión y licencias; modo oscuro en todas las pantallas.
- [ ] `BiometricError` y `ExportError` traducidos; ninguna excepción de plataforma llega a la UI.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
