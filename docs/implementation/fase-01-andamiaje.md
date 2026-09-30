# Fase 01 · Andamiaje

**Rama:** `feat/fase-01-andamiaje`
**Objetivo:** proyecto Flutter creado con la CLI oficial, dependencias instaladas, lints `very_good_analysis`,
l10n, configuración Android para `local_auth`, estructura de carpetas, scripts de verificación y CI en verde.
**Referencias:** definición §8.2, §9, §10, §14, §15 · `CLAUDE.md` del portafolio (Stack, Seguridad).
**Requisitos previos:** Flutter stable (≥ 3.44), Android SDK + un emulador (o teléfono) Android, `gh` autenticado,
Docker **no** es necesario todavía.

> Esta fase no contiene lógica de negocio. Al terminarla, la app abre una pantalla con el texto "Centavo",
> `./tool/check.sh` pasa y el CI del PR está en verde.

---

## Paso 0 · Inicio de fase

Sigue `00-guia-general.md` §3.1. Además:

- El repo ya existe (`origin = git@github.com:malpi-dev/Centavo.git`, rama `main` con solo `docs/`).
- Si hay cambios sin commitear en `docs/` (por ejemplo `docs/definicion.md` o este plan), commitéalos como primer
  commit de la rama: `git add docs && git commit -m "docs: add product definition and implementation plan"`.
- En `../CLAUDE.md` y `../README.md` (carpeta del portafolio, **no** es un repo, no se commitea) cambia el estado de
  Centavo a `🚧 En progreso`.

## Paso 1 · Crear el proyecto Flutter

`flutter create` funciona sobre una carpeta que ya tiene `.git` y `docs/` (no los toca):

```bash
cd ~/Developer/MobilePorfolio/Centavo
flutter --version                     # anota la versión en la bitácora
flutter create --org com.malpidev --project-name centavo --platforms android,ios --empty .
```

- `--empty` genera un `main.dart` mínimo sin el contador de ejemplo.
- Verifica: `android/app/build.gradle.kts` tiene `applicationId = "com.malpidev.centavo"` y
  `namespace = "com.malpidev.centavo"`. En iOS el bundle id es `com.malpidev.centavo`.
- Borra `test/widget_test.dart` si se generó (se crea uno propio en el paso 10).
- En `pubspec.yaml`: `description: "Offline-first personal finance app."` y `version: 0.1.0+1`.
- Deja `publish_to: 'none'`.

## Paso 2 · Dependencias

```bash
flutter pub add flutter_riverpod riverpod_annotation go_router freezed_annotation json_annotation \
  drift drift_flutter supabase_flutter fl_chart local_auth shared_preferences share_plus \
  path_provider uuid collection meta
flutter pub add intl:any                         # 'any' para que coincida con la versión que fija flutter_localizations
flutter pub add flutter_localizations --sdk=flutter
flutter pub add --dev build_runner riverpod_generator freezed json_serializable drift_dev \
  very_good_analysis mocktail flutter_launcher_icons flutter_native_splash
flutter pub get
```

- **No** se instala `csv` (ver bitácora: el escape se implementa a mano).
- Si `flutter pub add` informa un conflicto de versiones (típico entre `riverpod_generator`, `freezed` y
  `build_runner` por la versión de `analyzer`), deja que pub resuelva con la versión compatible más reciente
  (`flutter pub add <paquete>` sin versión) y anota el resultado en la bitácora. **No** fijes versiones a mano salvo
  que sea imprescindible.
- Si usas `riverpod_lint`/`custom_lint`: **no** los añadas en esta fase (no están en la definición).

## Paso 3 · Lints (`analysis_options.yaml`)

Reemplaza el contenido completo:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/l10n/app_localizations*.dart"
    - "build/**"
  errors:
    invalid_annotation_target: ignore   # needed by freezed + json_serializable on constructor params

linter:
  rules:
    public_member_api_docs: false       # app, not a published package (see implementation log)
```

## Paso 4 · Generación de código (`build.yaml`)

Crea `build.yaml` en la raíz:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          # ISO-8601 text keeps millisecond precision (needed for last-write-wins) and sorts correctly in UTC.
          store_date_time_values_as_text: true
          databases:
            centavo: lib/core/database/app_database.dart
          schema_dir: drift_schemas/
          test_dir: test/drift/
      json_serializable:
        options:
          field_rename: snake
          explicit_to_json: true
```

(`lib/core/database/app_database.dart` se crea en la fase 04; mientras no exista, `build_runner` no falla por esto.)

## Paso 5 · Localización

1. En `pubspec.yaml`, dentro de `flutter:` añade `generate: true` (mantén `uses-material-design: true`).
2. Crea `l10n.yaml`:
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   output-class: AppLocalizations
   nullable-getter: false
   ```
3. Crea `lib/l10n/app_en.arb`:
   ```json
   {
     "@@locale": "en",
     "appTitle": "Centavo"
   }
   ```
4. Ejecuta `flutter gen-l10n`. Debe generar `lib/l10n/app_localizations.dart` y `app_localizations_en.dart`
   (si tu versión de Flutter los genera en otra carpeta, ajusta `output-dir`/imports y anótalo en la bitácora).

## Paso 6 · Android e iOS para `local_auth` y desarrollo local

1. `android/app/src/main/kotlin/com/malpidev/centavo/MainActivity.kt`:
   ```kotlin
   package com.malpidev.centavo

   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity : FlutterFragmentActivity()
   ```
   (`local_auth` exige `FlutterFragmentActivity`. En la fase 10 se añade aquí el canal de `FLAG_SECURE`.)
2. `android/app/src/main/AndroidManifest.xml`:
   - Antes de `<application>`: `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`.
   - `android:label="Centavo"` en `<application>`.
3. `android/app/src/debug/AndroidManifest.xml`: añade `android:usesCleartextTraffic="true"` a un elemento
   `<application>` (créalo si no existe dentro de `<manifest>`). Solo en **debug**: permite hablar con Supabase local
   por HTTP desde el emulador (`http://10.0.2.2:54321`).
4. En `android/app/build.gradle.kts`, confirma que `minSdk` es ≥ 23 (si usa `flutter.minSdkVersion` y este es menor,
   pon `minSdk = 23`).
5. iOS (no se verifica, pero se deja compatible): en `ios/Runner/Info.plist` añade
   `NSFaceIDUsageDescription` = `Centavo uses Face ID to keep your finances private.` y `CFBundleDisplayName` = `Centavo`.

## Paso 7 · Estructura de carpetas

Crea (con un `.gitkeep` en las vacías):

```
lib/core/{config,database,di,domain,errors,presentation,router,supabase,theme,utils}
lib/features/{onboarding,transactions,categories,budgets,dashboard,export,security,backup,settings}/{domain,data,presentation}
lib/features/demo/{data,presentation}
test/core/  test/features/
assets/fonts/  assets/icon/
drift_schemas/
tool/
.maestro/
.github/workflows/
```

## Paso 8 · Entorno y `.gitignore`

1. `.env.example.json` (se commitea; valores de ejemplo, definición §15):
   ```json
   {
     "SUPABASE_URL": "http://10.0.2.2:54321",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxxxxxxxxxxxxxxxxxxx",
     "BACKUP_ENABLED": "true"
   }
   ```
   `10.0.2.2` es el `localhost` de la máquina visto desde el emulador de Android. En un teléfono físico se usa la IP
   de la máquina en la red local. En remoto, la URL del proyecto (`https://<ref>.supabase.co`).
2. Añade al `.gitignore` (al final, con un comentario `# Centavo`):
   ```
   .env.json
   *.g.dart
   *.freezed.dart
   lib/l10n/app_localizations*.dart
   coverage/
   supabase/.temp/
   supabase/.branches/
   android/key.properties
   *.jks
   *.keystore
   *.apk
   *.aab
   ```
   Verifica con `git check-ignore -v .env.example.json` que el ejemplo **no** queda ignorado.

## Paso 9 · Scripts de verificación

`tool/check_architecture.sh`:

```bash
#!/usr/bin/env bash
# Fails when a layer imports something it must not (docs/implementation/00-guia-general.md §4.1).
set -uo pipefail
cd "$(dirname "$0")/.."
status=0

domain_dirs=$(find lib -type d -name domain)
domain_forbidden="^import '(package:flutter/|package:flutter_riverpod|package:riverpod|package:drift|package:supabase|package:supabase_flutter|package:shared_preferences|package:local_auth|package:share_plus|package:path_provider|package:intl|package:uuid|dart:io|dart:ui)|^import '.*(/|^)(data|presentation)/"
if [ -n "$domain_dirs" ] && grep -rEn --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' "$domain_forbidden" $domain_dirs; then
  echo "ERROR: domain/ must not import frameworks, backend libraries, data/ or presentation/."
  status=1
fi

presentation_dirs=$(find lib -type d -name presentation)
presentation_forbidden="^import '(package:drift|package:supabase|package:supabase_flutter|package:centavo/core/database/|package:centavo/features/[a-z_]+/data/)|^import '(\.\./)+data/"
if [ -n "$presentation_dirs" ] && grep -rEn --include='*.dart' --exclude='*.g.dart' "$presentation_forbidden" $presentation_dirs; then
  echo "ERROR: presentation/ must not import Drift, Supabase or data/ (use lib/core/di/repository_providers.dart)."
  status=1
fi

[ $status -eq 0 ] && echo "Architecture check passed."
exit $status
```

`tool/check.sh`:

```bash
#!/usr/bin/env bash
# Full local verification. Same steps as CI.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
# Only tracked + new (non-ignored) files: generated code is ignored by git and is not formatted.
dart format --output=none --set-exit-if-changed $(git ls-files --cached --others --exclude-standard '*.dart')
./tool/check_architecture.sh
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
```

```bash
chmod +x tool/check.sh tool/check_architecture.sh
```

## Paso 10 · App mínima y test de humo

`lib/main.dart`:

```dart
import 'package:centavo/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: CentavoApp()));
}
```

`lib/app.dart`:

```dart
import 'package:centavo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CentavoApp extends StatelessWidget {
  const CentavoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: Text(AppLocalizations.of(context).appTitle)),
        ),
      ),
    );
  }
}
```

`test/app_smoke_test.dart`:

```dart
import 'package:centavo/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the app name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CentavoApp()));
    await tester.pumpAndSettle();
    expect(find.text('Centavo'), findsOneWidget);
  });
}
```

(Este test se reemplaza en la fase 02.) Ejecuta `./tool/check.sh`: debe pasar completo.

## Paso 11 · `CLAUDE.md` y `README.md` del repo

1. `CLAUDE.md` en la raíz del repo (**en inglés**). Contenido mínimo:
   - Una línea: qué es Centavo y que las reglas globales están en `../CLAUDE.md` (portfolio) y el plan en
     `docs/implementation/` (leer primero `00-guia-general.md` y `bitacora.md`).
   - **Documented exception to portfolio rule 4** (copia la idea de la definición §8.3): business data repositories
     (`TransactionRepository`, `CategoryRepository`, `BudgetRepository`) have `drift_*` + `mock_*` implementations,
     not `supabase_*`, because Drift is the source of truth (offline-first). Supabase is only a backup target, used
     exclusively by `BackupRepository` and `AuthRepository`, which do have `supabase_*` + `mock_*` implementations.
   - Comandos: `./tool/check.sh`, `dart run build_runner watch -d`, `flutter run --dart-define-from-file=.env.json`.
   - Reglas cortas: money is always `int` minor units; timestamps UTC via `Clock`; UI strings in `app_en.arb`;
     generated files are not committed.
2. `README.md`: reemplaza el que generó Flutter por un borrador en inglés con el título, la tagline
   (*Your money, on your phone. No account needed.*) y la línea "🚧 Work in progress". El README completo es de la fase 14.

## Paso 12 · CI (`.github/workflows/ci.yaml`)

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  flutter:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: <VERSIÓN LOCAL, p. ej. 3.44.6>
          cache: true
      - name: Install SQLite (Drift tests use NativeDatabase)
        run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
      - run: ./tool/check.sh
```

- Fija `flutter-version` a la misma versión que tienes en local (así `dart format` y el analyzer se comportan igual).
- Usa la versión mayor más reciente de cada action si hay otra disponible.

## Paso 13 · Probar en Android

```bash
flutter devices                      # confirma que hay un emulador/teléfono Android
flutter run -d <id-android>
```

- Debe verse "Centavo" en el centro. Si no hay emulador ni teléfono disponible: **🙋 Acción del autor** → pedir que
  abra uno y confirme.
- Opcional para comprobarlo tú: `adb exec-out screencap -p > /tmp/centavo-shot.png` y revisa la imagen.

## Paso 14 · Bitácora y cierre

- Rellena la tabla "Versiones clave instaladas" de `bitacora.md` (lee `pubspec.lock`, `flutter --version`,
  `supabase --version`).
- Cierra la fase según `00-guia-general.md` §3.3. El CI del PR debe pasar.

---

## Criterios de terminado

- [ ] Proyecto creado con `flutter create` (`com.malpidev.centavo`), `pubspec.yaml` con `version: 0.1.0+1`.
- [ ] Todas las dependencias de la definición §9 instaladas (salvo `csv`, ver bitácora).
- [ ] `analysis_options.yaml`, `build.yaml`, `l10n.yaml` y `app_en.arb` creados; `flutter gen-l10n` funciona.
- [ ] `MainActivity` extiende `FlutterFragmentActivity`; permiso `USE_BIOMETRIC`; cleartext solo en debug.
- [ ] Estructura de carpetas creada; `.env.example.json` commiteado; `.env.json` y código generado ignorados.
- [ ] `./tool/check.sh` pasa en local (incluido el chequeo de arquitectura).
- [ ] La app abre en Android mostrando "Centavo".
- [ ] `CLAUDE.md` del repo documenta la excepción drift/supabase/mock.
- [ ] CI en verde en el PR; PR mergeado con squash; bitácora actualizada (versiones incluidas).
