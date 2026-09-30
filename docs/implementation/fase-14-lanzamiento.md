# Fase 14 · Lanzamiento

**Rama:** `feat/fase-14-lanzamiento`
**Objetivo:** migración aplicada en el Supabase remoto compartido, APK de release firmado y publicado en GitHub
Releases por el workflow de tags, README completo con GIF y capturas, versión `1.0.0` y tag `v1.0.0`.
**Referencias:** definición §7.6 (remoto), §14, §15, §16 · `CLAUDE.md` del portafolio (Backend, Seguridad, Definición
de terminado, Plantilla de README).
**Requisitos previos:** fase 13 terminada; flujos de Maestro en verde.

> Esta fase tiene varias **🙋 Acciones del autor** (credenciales, keystore, secretos, visibilidad del repo).
> Detente en cada una y espera confirmación. Nunca pidas que te pegue contraseñas o la secret key en el chat:
> pídele que ejecute él los comandos con el prefijo `!` o en su terminal.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Supabase remoto (proyecto compartido del portafolio)

1. **🙋 Acción del autor:** confirmar que las convenciones globales del proyecto compartido ya están configuradas
   (probablemente las dejó Agendo): Auth por email con "Confirm email" activado, OTP de 6 dígitos, plantilla genérica
   "Your verification code: {{ .Token }}" para *Confirm signup* y *Magic link*, SMTP por defecto. Si no, que las
   configure en el Dashboard siguiendo el `CLAUDE.md` del portafolio.
2. **🙋 Acción del autor:** exportar en su terminal `SUPABASE_DB_URL` (cadena de conexión de Postgres, **nunca** en el repo).
3. Comprobar que el schema no existe todavía y aplicar la migración (**nunca** `supabase db push`):
   ```bash
   psql "$SUPABASE_DB_URL" -c "select to_regclass('centavo.categories');"     # debe devolver vacío
   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/20260928000000_centavo_init.sql
   ```
   Si ya existe (se aplicó antes), **no** la vuelvas a aplicar: compara con `\d centavo.*` y avisa al autor.
   **No** se aplica `seed.sql` en remoto.
4. Verificación:
   ```bash
   psql "$SUPABASE_DB_URL" -c "select tablename, rowsecurity from pg_tables where schemaname = 'centavo';"   # 4 filas, todas true
   psql "$SUPABASE_DB_URL" -c "select tablename, policyname from pg_policies where schemaname = 'centavo' order by 1, 2;"  # 14 políticas
   ```
5. **🙋 Acción del autor:** en *Project Settings → Data API → Exposed schemas*, añadir `centavo` (sin quitar los de
   las otras apps).
6. **🙋 Acción del autor:** facilitar la URL del proyecto y la **publishable key** (`sb_publishable_…`) para crear el
   `.env.json` de producción local (no se commitea).
7. Prueba real: `flutter run --release --dart-define-from-file=.env.json` → Backup → iniciar sesión con el email del
   autor (el SMTP por defecto solo entrega a miembros del equipo) → respaldar → restaurar en otro emulador/instalación
   limpia (CA2 de F8 en remoto). En *Table Editor* comprobar que las filas tienen el `user_id` correcto.

## Paso 2 · Firma de release

1. **🙋 Acción del autor:** crear el keystore **fuera del repo** y guardar las contraseñas en su gestor:
   ```bash
   keytool -genkey -v -keystore ~/keys/centavo-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias centavo
   ```
2. **🙋 Acción del autor:** crear `android/key.properties` (ignorado por git; verifícalo con `git check-ignore`):
   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=centavo
   storeFile=/Users/<usuario>/keys/centavo-release.jks
   ```
3. `android/app/build.gradle.kts` — firma con el keystore si existe `key.properties`; si no, con la clave de debug
   (así los builds locales y el CI de PRs siguen funcionando):
   ```kotlin
   import java.io.FileInputStream
   import java.util.Properties

   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }

   android {
       // … existing config …
       signingConfigs {
           create("release") {
               if (keystorePropertiesFile.exists()) {
                   keyAlias = keystoreProperties["keyAlias"] as String
                   keyPassword = keystoreProperties["keyPassword"] as String
                   storeFile = file(keystoreProperties["storeFile"] as String)
                   storePassword = keystoreProperties["storePassword"] as String
               }
           }
       }
       buildTypes {
           release {
               signingConfig = if (keystorePropertiesFile.exists()) {
                   signingConfigs.getByName("release")
               } else {
                   signingConfigs.getByName("debug")
               }
           }
       }
   }
   ```
4. `flutter build apk --release --dart-define-from-file=.env.json` y comprueba la firma:
   `$ANDROID_HOME/build-tools/<versión>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`
   (el certificado debe ser el del keystore, no "Android Debug").

## Paso 3 · Secretos de GitHub

**🙋 Acción del autor** (en su terminal; valores que tú no debes ver):

```bash
gh secret set ANDROID_KEYSTORE_BASE64 --repo malpi-dev/Centavo < <(base64 -i ~/keys/centavo-release.jks)
gh secret set ANDROID_KEYSTORE_PASSWORD --repo malpi-dev/Centavo
gh secret set ANDROID_KEY_PASSWORD --repo malpi-dev/Centavo
gh secret set ANDROID_KEY_ALIAS --repo malpi-dev/Centavo --body centavo
gh secret set SUPABASE_URL --repo malpi-dev/Centavo
gh secret set SUPABASE_PUBLISHABLE_KEY --repo malpi-dev/Centavo
```

Después verifica con `gh secret list --repo malpi-dev/Centavo` que existen los seis.

## Paso 4 · Workflow de release (`.github/workflows/release.yaml`)

```yaml
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  apk:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: <misma versión que ci.yaml>
          cache: true
      - run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
      - run: ./tool/check.sh
      - name: Write .env.json
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}
        run: |
          jq -n --arg url "$SUPABASE_URL" --arg key "$SUPABASE_PUBLISHABLE_KEY" \
            '{SUPABASE_URL: $url, SUPABASE_PUBLISHABLE_KEY: $key, BACKUP_ENABLED: "true"}' > .env.json
      - name: Write signing config
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 --decode > android/app/release.jks
          {
            echo "storePassword=$KEYSTORE_PASSWORD"
            echo "keyPassword=$KEY_PASSWORD"
            echo "keyAlias=$KEY_ALIAS"
            echo "storeFile=release.jks"
          } > android/key.properties
      - run: flutter build apk --release --dart-define-from-file=.env.json
      - run: mv build/app/outputs/flutter-apk/app-release.apk "centavo-${GITHUB_REF_NAME}.apk"
      - uses: softprops/action-gh-release@v2
        with:
          files: centavo-${{ github.ref_name }}.apk
          generate_release_notes: true
          prerelease: ${{ contains(github.ref_name, '-') }}
```

(`storeFile=release.jks` es relativo a `android/app/`, donde lo resuelve `file(...)`.)

**Prueba antes de mergear:** desde la rama, `git tag v1.0.0-rc.1 && git push origin v1.0.0-rc.1`. El workflow debe
crear un *pre-release* con `centavo-v1.0.0-rc.1.apk`. Descárgalo (`gh release download v1.0.0-rc.1`), instálalo en el
emulador y haz una prueba de humo (demo + respaldo remoto). Luego borra el pre-release y el tag:
`gh release delete v1.0.0-rc.1 --cleanup-tag --yes`.

## Paso 5 · Versión

`pubspec.yaml` → `version: 1.0.0+1`. Comprueba que *About* muestra `1.0.0 (1)`.

## Paso 6 · GIF y capturas

1. Capturas (claro y oscuro) de: Dashboard, Transactions, Budgets, Transaction form — en demo, en un emulador tipo
   Pixel. `adb exec-out screencap -p > docs/media/<nombre>.png`. Guarda 4 en `docs/media/` (p. ej.
   `dashboard-light.png`, `transactions-light.png`, `budgets-dark.png`, `form-dark.png`).
2. GIF de 15–30 s (definición §16): demo → añadir gasto → dashboard actualizado → presupuestos → cambiar a oscuro.
   ```bash
   adb shell screenrecord --time-limit 30 /sdcard/centavo-demo.mp4    # graba mientras haces el recorrido
   adb pull /sdcard/centavo-demo.mp4 /tmp/
   ffmpeg -i /tmp/centavo-demo.mp4 -vf "fps=12,scale=360:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" -loop 0 docs/media/demo.gif
   ```
   El GIF debe pesar < 10 MB. Si no puedes interactuar con el emulador mientras grabas: **🙋 Acción del autor**.
   (Recuerda: con el bloqueo activo `FLAG_SECURE` impide grabar; graba en demo con el bloqueo apagado.)

## Paso 7 · README completo (inglés, plantilla del portafolio)

1. **Centavo** + tagline *Your money, on your phone. No account needed.* + badges: CI
   (`https://github.com/malpi-dev/Centavo/actions/workflows/ci.yaml/badge.svg`), versión
   (`https://img.shields.io/github/v/release/malpi-dev/Centavo`), plataforma (`Android`), Flutter.
2. GIF + 4 capturas en una tabla.
3. **Try it:** enlace a `https://github.com/malpi-dev/Centavo/releases/latest` + "Tap **Explore demo** to skip
   everything — no account, no internet needed."
4. **Features:** lista corta (offline-first, budgets con estados, dashboard con gráficas, app lock, CSV, backup opcional, dark mode, demo).
5. **Tech stack:** Flutter, Riverpod (generator), go_router, Drift, freezed, fl_chart, local_auth, Supabase, Maestro, GitHub Actions.
6. **Architecture:** diagrama Mermaid de capas (`presentation → domain ← data`, `core`) y explicación de por qué los
   repositorios son intercambiables (Drift = fuente de verdad, mock = demo/tests, Supabase = solo respaldo) y del
   offline-first + respaldo (LWW por fila reforzado por el trigger `keep_newest`, supuesto de un dispositivo a la vez).
7. **Backend:** tablas del schema `centavo`, qué protege cada política RLS (tabla), triggers, RPC `ensure_profile`,
   "No Edge Functions: no secret key is needed".
8. **Getting started:** requisitos; `flutter pub get` + `dart run build_runner build -d`; correr **sin** Supabase
   (`flutter run`, modo local + demo); **con** Supabase local (`supabase start`, `supabase db reset`, `.env.json` desde
   `.env.example.json`, `flutter run --dart-define-from-file=.env.json`; código OTP en Mailpit `http://127.0.0.1:54324`).
9. **Testing:** `./tool/check.sh`, `supabase test db`, `./tool/e2e.sh` (Maestro).
10. **Roadmap:** §3.3 de la definición + "Ideas para el roadmap" de la bitácora.

Añade una sección breve **Privacy** (datos locales; respaldo opcional; qué se sube) y la licencia (MIT, archivo
`LICENSE`, si el autor está de acuerdo — **🙋** confirmar).

## Paso 8 · Verificación final (definición §16)

Recorre la checklist de §16 de la definición y márcala en la entrada de la bitácora, con evidencia breve por punto
(test, captura o comando). Incluye: todo F1–F10 en Android, modo avión sin cuenta, demo sin `.env.json`, respaldo y
restauración local **y** remoto, estados de UI, modo oscuro, tests + pgTAP + Maestro, CI verde, analyzer limpio, RLS
comentado y aplicado en remoto, `.env.example.json` completo, `CLAUDE.md` con la excepción, README completo.

## Paso 9 · Cierre, merge y tag

1. Actualiza la bitácora (fase 14 ✅, 14/14 = 100 %) y, en `docs/definicion.md`, el **Estado** a `✅ MVP listo`.
2. Cierra la fase según `00-guia-general.md` §3.3 (PR + CI verde + squash merge).
3. Tag en `main`:
   ```bash
   git checkout main && git pull origin main
   git tag -a v1.0.0 -m "Centavo v1.0.0"
   git push origin v1.0.0
   gh run watch        # espera al workflow Release
   gh release view v1.0.0
   ```
   Descarga el APK del release, instálalo en un emulador limpio y repite la prueba de humo.
4. **🙋 Acción del autor:** hacer el repo público (`gh repo edit malpi-dev/Centavo --visibility public
   --accept-visibility-change-consequences`), añadir descripción y topics (`flutter`, `riverpod`, `drift`, `supabase`,
   `offline-first`, `personal-finance`). Opcional: renombrarlo a `centavo` en minúsculas (convención del portafolio)
   con `gh repo rename centavo` y actualizar `origin` y los enlaces del README.
5. En la carpeta del portafolio (no es repo): `../CLAUDE.md` y `../README.md` → estado de Centavo `🚀 Publicado`
   (si hay APK + GIF + repo público; si falta algo, `✅ MVP listo`), con enlaces a repo y release.
6. Registra el resultado del release (URL del APK) en la bitácora mediante un PR corto desde la rama
   `docs/release-v1.0.0` (`docs: record v1.0.0 release`), squash merge.

---

## Criterios de terminado

- [ ] Migración aplicada en remoto con `psql`; schema `centavo` expuesto; RLS y 14 políticas verificadas; seed **no** aplicado.
- [ ] Respaldo y restauración verificados contra el proyecto remoto.
- [ ] APK firmado con el keystore de release; secretos en GitHub; workflow `Release` probado con un `-rc` y luego con `v1.0.0`.
- [ ] README completo según la plantilla, con GIF, capturas, diagrama y secciones de backend y testing.
- [ ] Checklist §16 de la definición verificada y registrada en la bitácora.
- [ ] Tag `v1.0.0` con `centavo-v1.0.0.apk` en GitHub Releases; estado del portafolio actualizado.
