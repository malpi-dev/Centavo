# Fase 13 · Pulido y E2E

**Rama:** `feat/fase-13-pulido-y-e2e`
**Objetivo:** identidad visual final (ícono adaptativo y splash claro/oscuro), auditoría de estados de UI, modo
oscuro, pantallas pequeñas y accesibilidad, y los dos flujos E2E de Maestro en verde.
**Referencias:** definición §11, §12.1, §13 (flujos de Maestro), §16 · `CLAUDE.md` del portafolio (Definición de terminado).
**Requisitos previos:** fase 12 terminada. Emulador Android. Java 17+ (para Maestro).

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Ícono y splash

### 1.1 Fuentes SVG (`assets/icon/`)

Concepto (§11): moneda de cobre con el signo "¢" sobre verde pino. Dibujado con trazos (sin depender de fuentes).

`icon.svg` (ícono completo, 1024×1024):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#1F6F5C"/>
  <g id="coin">
    <circle cx="512" cy="512" r="300" fill="#B8692E"/>
    <circle cx="512" cy="512" r="262" fill="none" stroke="#E9A56B" stroke-width="18"/>
    <path d="M 611 413 A 140 140 0 1 0 611 611" fill="none" stroke="#F7F6F2" stroke-width="56" stroke-linecap="round"/>
    <line x1="530" y1="330" x2="530" y2="694" stroke="#F7F6F2" stroke-width="40" stroke-linecap="round"/>
  </g>
</svg>
```

Deriva de él:
- `icon_foreground.svg`: sin el `<rect>` (fondo transparente) y la moneda escalada al 85 % alrededor del centro
  (`<g transform="translate(512 512) scale(0.85) translate(-512 -512)">…</g>`) para que quepa en la zona segura del
  ícono adaptativo.
- `splash_logo.svg`: igual que el foreground (fondo transparente, moneda al 100 %).
- `splash_android12.svg`: `viewBox="0 0 960 960"`, fondo transparente, moneda centrada en (480, 480) escalada al 80 %
  (Android 12 recorta el ícono del splash a un círculo de 640 px de diámetro).

Ajusta el trazo del "¢" si al renderizarlo no se ve centrado; lo importante es que se lea como una moneda con "¢".

### 1.2 Renderizar a PNG

```bash
brew install librsvg        # si no está instalado
cd assets/icon
rsvg-convert -w 1024 -h 1024 icon.svg -o icon.png
rsvg-convert -w 1024 -h 1024 icon_foreground.svg -o icon_foreground.png
rsvg-convert -w 768 -h 768 splash_logo.svg -o splash_logo.png
rsvg-convert -w 960 -h 960 splash_android12.svg -o splash_android12.png
cd ../..
```

Revisa los PNG abriéndolos (herramienta Read). Si no puedes instalar `librsvg` o el resultado no es correcto:
**🙋 Acción del autor** → que exporte esos cuatro PNG desde un editor (Figma, Inkscape…) con esos nombres y tamaños.

### 1.3 Configuración (`pubspec.yaml`, al final)

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/icon/icon.png
  adaptive_icon_background: "#1F6F5C"
  adaptive_icon_foreground: assets/icon/icon_foreground.png
  remove_alpha_ios: true

flutter_native_splash:
  color: "#1F6F5C"
  image: assets/icon/splash_logo.png
  color_dark: "#0F1412"
  image_dark: assets/icon/splash_logo.png
  android_12:
    color: "#1F6F5C"
    image: assets/icon/splash_android12.png
    color_dark: "#0F1412"
    image_dark: assets/icon/splash_android12.png
```

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Commitea los recursos generados en `android/` e `ios/`. Sustituye el `Icons.savings` provisional de la bienvenida y de
la pantalla de bloqueo por el logo (`Image.asset('assets/icon/splash_logo.png')`, declarado en `assets:`).

## Paso 2 · Auditoría de estados de UI (§12.1)

Recorre la tabla y, para cada celda, confirma que existe **y** que hay un test que la cubre (si falta, añádelo):

| Pantalla | Carga | Vacío | Error |
|---|---|---|---|
| Dashboard | skeleton de tarjetas y gráficas | "No transactions in <month>" + *Add transaction* | mensaje + *Retry* por sección |
| Transactions | skeleton de filas | *Add your first transaction* / con filtros: *No results* + *Clear filters* | mensaje + *Retry* |
| Transaction form | spinner al cargar para editar; *Save* en progreso | — | errores por campo; SnackBar para `StorageError` |
| Budgets | skeleton | "No budgets for <month>" + *Set a budget* / *Copy from previous month* | mensaje + *Retry* |
| Categories | skeleton | *Archived* vacía oculta | mensaje + *Retry* |
| Lock | esperando biometría | — | `lockedOut` / `notAvailable` con instrucción |
| Backup | progreso con paso actual | "Not signed in" + beneficios | offline / backend pausado / código inválido con acción |
| Export | progreso al generar | "Nothing to export for this range" | error de escritura/compartir |
| Welcome / Restore | spinner durante restauración | "No backup found" | error de red con *Retry* |

Busca también pantallas en blanco: `grep -rn "SizedBox.shrink()" lib/features/*/presentation` y revisa cada caso.

## Paso 3 · Modo oscuro, pantallas pequeñas y accesibilidad

1. **Test de humo visual** (`test/app/screens_smoke_test.dart`): para cada pantalla principal (Welcome, Dashboard,
   Transactions, Transaction form, Budgets, Budget form, Settings, Categories, Category form, Export, Backup, Lock),
   en demo, con las combinaciones {claro, oscuro} × {360×640 dp, 411×891 dp} × {`textScaler` 1.0, 1.3}: se construye
   sin excepciones ni overflow (`tester.takeException()` es `null`). Usa `tester.view.physicalSize`/`devicePixelRatio`
   y restablece con `addTearDown(tester.view.reset)`.
2. **Colores sueltos:** `grep -rnE "Color\(0x|Colors\.[a-z]" lib --include=*.dart | grep -v lib/core/theme` debe
   devolver vacío (salvo `Colors.transparent`, aceptable).
3. **Textos sueltos:** revisa que no quedan strings de UI fuera de `app_en.arb`
   (`grep -rn "Text('" lib/features`).
4. **Accesibilidad:** botones solo-ícono con `tooltip`; `CategoryAvatar` con `Semantics(label: nombre)`; objetivos
   táctiles ≥ 48 dp (usa `meetsGuideline(androidTapTargetGuideline)` y `textContrastGuideline` en 2–3 pantallas clave).
5. Capturas manuales en el emulador de las pantallas principales en claro y oscuro; revísalas.

## Paso 4 · Maestro

### 4.1 Instalación

```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
maestro --version       # anótala en la bitácora
```

Si falla por Java u otro requisito: **🙋 Acción del autor**.

### 4.2 Identificadores

Maestro encuentra los widgets de Flutter por `Semantics(identifier: …)` (selector `id:`) o por texto visible.
Asegúrate de que tienen `identifier` al menos: `welcome-start-fresh`, `welcome-explore-demo`, `currency-USD`,
`currency-continue`, `fab-add-transaction`, `tx-amount`, `tx-save`, `dashboard-expense`, `budget-set-<id de Food>`,
`budget-limit`, `budget-save`, `demo-exit`. Para `dashboard-expense`, el `Semantics` debe envolver **directamente** el
texto del monto (`container: true`) para que `copyTextFrom` lea el importe.

### 4.3 `.maestro/demo_add_expense.yaml` (obligatorio, flujo feliz)

```yaml
appId: com.malpidev.centavo
name: Demo - add an expense and see the dashboard update
---
- clearState
- launchApp
- tapOn:
    id: "welcome-explore-demo"
- assertVisible: "Demo mode — changes aren't saved"
- copyTextFrom:
    id: "dashboard-expense"
- evalScript: ${output.before = parseFloat(maestro.copiedText.replace(/[^0-9.]/g, ''))}
- tapOn:
    id: "fab-add-transaction"
- tapOn:
    id: "tx-amount"
- inputText: "12.50"
- tapOn: "Coffee"
- tapOn:
    id: "tx-save"
- assertVisible:
    id: "dashboard-expense"
- copyTextFrom:
    id: "dashboard-expense"
- assertTrue: ${Math.abs(parseFloat(maestro.copiedText.replace(/[^0-9.]/g, '')) - output.before - 12.5) < 0.001}
- tapOn: "Transactions"
- assertVisible: ".*12\\.50.*"
```

### 4.4 `.maestro/fresh_start_budget.yaml`

`clearState` → *Start fresh* → `currency-USD` → *Continue* → tab *Budgets* → `budget-set-00000000-0000-4000-8000-000000000001`
(Food) → límite `600` → *Save* → FAB → gasto `50` en *Food* → *Save* → tab *Budgets* → `assertVisible` del texto
"$50.00 of $600.00" (o el formato que use tu `spentOfLimit`) y "On track".

### 4.5 Ejecutar

```bash
flutter build apk --release            # sin .env.json: modo local + demo (la firma de release llega en la fase 14)
adb install -r build/app/outputs/flutter-apk/app-release.apk
maestro test .maestro/
```

Ambos flujos en verde. Si un selector por texto falla por el formato, usa regex (`".*50\\.00.*"`). **No** se añaden a
CI (bitácora); se corren en local antes de cada tag.

## Paso 5 · Script de conveniencia

`tool/e2e.sh`: construye el APK release, lo instala en el dispositivo conectado y ejecuta `maestro test .maestro/`
(con `set -euo pipefail`). Documenta su uso en el `CLAUDE.md` del repo.

## Paso 6 · Cierre

`00-guia-general.md` §3.3. Añade a la entrada de la bitácora la salida resumida de `maestro test`.

---

## Criterios de terminado

- [ ] Ícono adaptativo (moneda cobre "¢" sobre verde pino) y splash claro/oscuro, incluido Android 12.
- [ ] Todas las celdas de la tabla de estados existen y están cubiertas por tests.
- [ ] Sin overflows en 360×640 ni con texto al 130 %; modo oscuro correcto en todas las pantallas.
- [ ] Sin colores ni textos sueltos fuera del tema y del ARB.
- [ ] `demo_add_expense.yaml` y `fresh_start_budget.yaml` en verde en un emulador.
- [ ] `./tool/check.sh` y CI en verde; PR mergeado; bitácora actualizada.
