# Centavo — Guía general de implementación

> **Lee este archivo completo antes de empezar cualquier fase.** Después lee `bitacora.md` para saber en qué
> fase vas y, por último, el archivo de la fase que toca (`fase-NN-<nombre>.md`).
> Cada fase está escrita para poder ejecutarse sin contexto previo: sigue los pasos en orden y no te saltes ninguno.

## 1. Documentos de referencia (orden de prioridad)

1. `../../../CLAUDE.md` (carpeta del portafolio): reglas globales. **Prevalece** sobre todo lo demás.
2. `../../CLAUDE.md` (raíz del repo Centavo, se crea en la fase 01): excepciones propias de Centavo.
3. `../definicion.md`: **qué** se construye (alcance, modelo, backend, UI). Cada fase cita las secciones (§) que necesita.
4. Archivo de la fase actual: **cómo** se construye, paso a paso.
5. `bitacora.md`: estado, decisiones tomadas durante la implementación y bloqueos.

Si encuentras una contradicción entre documentos, sigue el de mayor prioridad y **anótala en la bitácora**
(sección "Decisiones y desviaciones"). Las decisiones ya tomadas al escribir este plan también están en esa tabla:
**léelas**, porque algunas corrigen detalles de la definición (por ejemplo, el tipo de la columna `color`).

## 2. Idiomas (obligatorio)

| Qué | Idioma |
|---|---|
| Código (nombres de variables, clases, funciones, archivos), comentarios en el código | **Inglés** |
| Textos de la UI (botones, mensajes, errores visibles) — viven en `lib/l10n/app_en.arb` | **Inglés** |
| Mensajes de commit, títulos y descripciones de PR, nombres de rama | **Inglés** |
| SQL (nombres, comentarios de políticas `comment on policy`) | **Inglés** |
| `README.md` y `CLAUDE.md` del repo | **Inglés** |
| Documentos en `docs/` (incluida la bitácora) | **Español** |

## 3. Protocolo de cada fase (ramas y merge a `main`)

Cada fase es **una rama nueva** creada desde `main` y termina **integrada en `main`**. Sigue estos pasos siempre.

### 3.1 Al empezar la fase

```bash
cd ~/Developer/MobilePorfolio/Centavo
git status                               # debe estar limpio; si no, ver nota abajo
git checkout main
git pull origin main
git checkout -b feat/fase-NN-<nombre>    # ej.: feat/fase-03-dominio
```

- El nombre de la rama es exactamente el del archivo de la fase sin `.md`, con prefijo `feat/`
  (`fase-01-andamiaje.md` → `feat/fase-01-andamiaje`).
- Si `git status` no está limpio: **no borres nada**. Si los cambios son solo de `docs/`, se commitean como primer
  commit de la rama de la fase (`docs: ...`). Si son de código y no sabes de dónde salen, detente y pregunta al autor.
- Actualiza `bitacora.md`: estado de la fase → `🚧 En progreso`, fecha de inicio, "Fase actual" y barra de progreso
  (ver §5). Commit: `docs: start phase NN`.

### 3.2 Durante la fase

- Commits pequeños con **Conventional Commits** en inglés: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`, `ci:`.
  Ejemplo: `feat(budgets): add GetBudgetProgress use case`.
- No hagas nada que no pida la fase. Si ves algo útil fuera de alcance, anótalo en la bitácora ("Ideas para el roadmap").
- Pasos marcados con **🙋 Acción del autor** requieren que el humano haga algo (login, crear cuentas, secretos,
  probar en un teléfono…). **Detente, explica exactamente qué debe hacer y espera** su confirmación. No inventes
  credenciales ni te saltes el paso.
- Tras modificar cualquier archivo con anotaciones (`@freezed`, `@riverpod`, `@DriftDatabase`, `@JsonSerializable`)
  ejecuta `dart run build_runner build --delete-conflicting-outputs`.

### 3.3 Al terminar la fase

1. Ejecuta la verificación completa (el script existe desde la fase 01):
   ```bash
   ./tool/check.sh
   ```
   Hace: `pub get` → `gen-l10n` → `build_runner` → `dart format` (sin cambios) → chequeo de arquitectura →
   `flutter analyze` (sin infos, warnings ni errores) → `flutter test`. Todo debe pasar.
   Si la fase toca la base de datos de Supabase (desde la fase 11), además: `supabase db reset` y `supabase test db`.
2. Revisa la **checklist de "Criterios de terminado"** del archivo de la fase. Cada casilla debe cumplirse de verdad.
3. Actualiza `bitacora.md`: estado `✅ Terminada`, fecha de fin, barra de progreso, entrada en el "Registro" con lo
   hecho, decisiones y pendientes. Commit: `docs: update implementation log for phase NN`.
4. Integra en `main` con **squash merge** vía Pull Request:
   ```bash
   git push -u origin feat/fase-NN-<nombre>
   gh pr create --base main --title "feat: phase NN - <short english title>" \
     --body "<english summary of what was done + the phase checklist>"
   gh pr checks --watch                     # espera a que el CI termine (existe desde la fase 01)
   gh pr merge --squash --delete-branch
   git checkout main && git pull origin main
   ```
   - Si el CI falla: corrige en la misma rama, `git push` y vuelve a esperar. **Nunca** hagas merge con CI en rojo.
   - Si `gh` no está autenticado (`gh auth status` falla): **🙋 Acción del autor** → pedir que ejecute `gh auth login`.
   - Solo si el autor lo autoriza explícitamente, alternativa local:
     `git checkout main && git merge --squash feat/fase-NN-<nombre> && git commit -m "feat: phase NN - ..." && git push origin main && git branch -D feat/fase-NN-<nombre>`.
5. No empieces la fase siguiente en la misma rama. Cada fase arranca desde `main` actualizado.

## 4. Reglas técnicas que aplican a todas las fases

### 4.1 Arquitectura (definición §8)

```
lib/
  main.dart · app.dart
  core/            # domain/ (Money, YearMonth, LocalDate, Clock…), errors/, database/ (Drift), supabase/,
                   # config/, theme/, router/, di/ (providers de repositorios), presentation/ (widgets comunes), utils/
  l10n/            # app_en.arb (+ archivos generados, ignorados por git)
  features/<feature>/{domain,data,presentation}
```

- `domain/` (incluido `core/domain/`) **no importa**: `package:flutter/*`, Riverpod, Drift, Supabase,
  `shared_preferences`, `local_auth`, `share_plus`, `path_provider`, `intl`, `dart:io`, `dart:ui`, ni nada de
  `data/` o `presentation/`. Sí puede importar: `dart:core`/`dart:async`/`dart:math`, `package:meta`,
  `package:collection`, `package:freezed_annotation`, `core/domain/`, `core/errors/` y otros `domain/`.
- `presentation/` **nunca** importa Drift, Supabase ni archivos `data/`. Obtiene los repositorios de
  `lib/core/di/repository_providers.dart` (el único "composition root" que importa implementaciones de `data/`).
- Cada repositorio tiene una implementación real (`drift_*`, `supabase_*`, `local_auth_*`, `prefs_*`…) y una `mock_*`
  (o `in_memory_*`). Excepción documentada en el `CLAUDE.md` del repo: los datos de negocio son `drift` + `mock`;
  Supabase solo se usa en `backup` (definición §8.3).
- Los repositorios **lanzan** subclases de `DomainError` (`lib/core/errors/domain_error.dart`). Nunca dejan escapar
  `SqliteException`, `PostgrestException`, `AuthException`, `SocketException` ni `PlatformException`.
- Casos de uso **solo** donde la definición §6.3 los lista. El CRUD simple va directo al repositorio desde un provider.
- `tool/check_architecture.sh` (fase 01) verifica estas reglas con `grep`; debe pasar siempre.

### 4.2 Código Dart / Flutter

- **Nombres de archivo** en `snake_case` (`get_budget_progress.dart`). Clases en `PascalCase`, miembros en `camelCase`.
- Lints: `very_good_analysis`. `flutter analyze` debe quedar en **0 issues**. `// ignore:` solo con justificación
  en la misma línea y nunca para esconder un error real.
- Imports: usa `package:centavo/...`. Si el lint instalado exige imports relativos dentro de `lib/`, obedece al lint.
- **Dinero:** siempre `int` en unidades mínimas (`amountMinor`). **Prohibido `double` para montos.** Los porcentajes
  se calculan con enteros cuando deciden un estado (ver fase 03).
- **Fechas:** los instantes (`createdAt`, `updatedAt`, `deletedAt`, `archivedAt`) son `DateTime` en **UTC**
  (usa siempre `clock.nowUtc()`; nunca `DateTime.now()` fuera de `SystemClock`). Los días de calendario son
  `LocalDate` y los meses `YearMonth` (fase 02).
- **Modelos:** `freezed`. En freezed 3.x la clase se declara `abstract class X with _$X` (o `sealed class` para uniones).
- **Riverpod:** con `riverpod_generator` (`@riverpod` / `@Riverpod(keepAlive: true)`). Providers de repositorio
  `keepAlive`; providers de pantalla autoDispose (el valor por defecto de `@riverpod`).
- **Código generado** (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) **no se commitea**: está en
  `.gitignore` y el CI lo genera.
- **Textos de UI:** nunca literales en widgets. Van en `lib/l10n/app_en.arb` y se leen con `context.l10n.<key>`
  (extensión creada en la fase 02).
- **Colores:** siempre desde el tema (`Theme.of(context).colorScheme` o la extensión `CentavoColors`). Nada de `Color(0x…)`
  sueltos en widgets, salvo en `lib/core/theme/`.
- **Claves para tests y Maestro:** los elementos interactivos importantes llevan `key: const Key('kebab-case-id')`.
  Los que usa Maestro llevan además `Semantics(identifier: 'kebab-case-id', ...)` (se ve como `id` en Maestro).
- **Estados de UI:** toda pantalla que carga datos usa `AsyncStateView` (fase 02) con carga, vacío y error con *Retry*
  (definición §12.1). Nada de pantallas en blanco.
- **No adivines APIs.** Si dudas de la firma de una librería (Drift, Riverpod 3, go_router, fl_chart, local_auth,
  share_plus, supabase_flutter…), revisa el código fuente en `~/.pub-cache/hosted/pub.dev/<paquete>-<versión>/`
  o su documentación oficial de la **versión instalada** (mira `pubspec.lock`). Anota en la bitácora cualquier
  diferencia con lo que dice la fase.
- **Dependencias:** solo las de la definición §9 (con los ajustes anotados en la bitácora). Añadir otra requiere
  justificarla en la bitácora.

### 4.3 Secretos

- Nunca commitees `.env.json`, `android/key.properties`, keystores (`*.jks`, `*.keystore`) ni claves.
- En el cliente solo va la **publishable key** (`sb_publishable_…`). La secret key (`sb_secret_…`) jamás.

## 5. Cómo actualizar la barra de progreso

La barra tiene **un bloque por fase** (14 en total):

- `█` = fase terminada · `▒` = fase en progreso · `░` = fase pendiente.
- Formato: `` `█████▒░░░░░░░░` 5/14 fases terminadas (36 %) `` — el porcentaje es `terminadas / 14 × 100`,
  redondeado al entero.
- Tabla de referencia del porcentaje: 0→0 %, 1→7 %, 2→14 %, 3→21 %, 4→29 %, 5→36 %, 6→43 %, 7→50 %, 8→57 %,
  9→64 %, 10→71 %, 11→79 %, 12→86 %, 13→93 %, 14→100 %.
- Actualiza también "Fase actual" y "Última actualización" en la cabecera de la bitácora.

## 6. Cuando algo no sale

1. Lee el error completo. Busca la causa, no el parche.
2. Si una instrucción de la fase no funciona con la versión instalada de una librería, adapta siguiendo la
   documentación oficial y **anota la desviación** en la bitácora.
3. Si tras 2–3 intentos razonables sigues bloqueado, anota el bloqueo en la bitácora ("Bloqueos") y pregunta al autor.
4. Nunca uses `--no-verify`, `git push --force` a `main`, ni desactives reglas de lint o tests para "pasar".

## 7. Comandos frecuentes

```bash
flutter run --dart-define-from-file=.env.json          # con respaldo configurado
flutter run                                            # sin .env.json: modo local + demo, sin respaldo
dart run build_runner watch --delete-conflicting-outputs
flutter test test/features/budgets                     # una carpeta de tests
supabase start && supabase db reset && supabase test db  # desde la fase 11 (Docker encendido)
maestro test .maestro/                                 # desde la fase 13
```

## 8. Mapa de fases

| # | Archivo | Objetivo |
|---|---|---|
| 01 | `fase-01-andamiaje.md` | `flutter create`, dependencias, lints, l10n, Android (`local_auth`), estructura, scripts de verificación, CI |
| 02 | `fase-02-core.md` | `Money`, `YearMonth`, `LocalDate`, `Clock`, `DomainError`, env, tema claro/oscuro, fuentes, ajustes, router con tabs, widgets comunes |
| 03 | `fase-03-dominio.md` | Modelos, interfaces de repositorio, validadores y casos de uso puros con tests |
| 04 | `fase-04-persistencia-drift.md` | Base Drift v1, repositorios Drift, traducción de errores, tests en memoria, snapshot de esquema |
| 05 | `fase-05-modo-demo.md` | `DemoDataset`, repositorios mock, `AppMode` y cambio de repositorios, banner de demo |
| 06 | `fase-06-onboarding-y-categorias.md` | Bienvenida, moneda, *Start fresh*, *Explore demo*, gestión de categorías |
| 07 | `fase-07-movimientos.md` | Lista por mes con filtros, formulario, borrar con *Undo* |
| 08 | `fase-08-presupuestos.md` | Presupuestos del mes, progreso y estados, copiar mes anterior |
| 09 | `fase-09-dashboard.md` | Tarjetas, dona, barras de 6 meses y resumen de presupuestos con fl_chart |
| 10 | `fase-10-ajustes-bloqueo-y-csv.md` | Ajustes completos, bloqueo biométrico, `FLAG_SECURE`, exportar CSV, borrar datos |
| 11 | `fase-11-backend-supabase.md` | Supabase local: migración (schema, RLS, triggers, RPC), seed, pgTAP, job de CI |
| 12 | `fase-12-respaldo.md` | Auth OTP, respaldo, restauración, borrar respaldo, respaldo automático |
| 13 | `fase-13-pulido-y-e2e.md` | Ícono, splash, auditoría de estados y modo oscuro, flujos Maestro |
| 14 | `fase-14-lanzamiento.md` | Supabase remoto, firma y workflow de release, README, tag `v1.0.0` |
