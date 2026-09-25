# Centavo — Documento de definición

| Campo | Valor |
|---|---|
| **Tagline** | *Your money, on your phone. No account needed.* — finanzas personales offline-first |
| **Stack** | Flutter stable · Riverpod (`riverpod_generator`) · go_router · Drift · freezed · fl_chart · `supabase_flutter` |
| **Plataforma** | Android (objetivo principal) · iOS si es posible |
| **Estado** | 📋 Planificado |
| **Versión del documento** | 1.0 |
| **Fecha** | 2026-09-25 |
| **Repo** | `centavo` (carpeta local `Centavo/`) |
| **Bundle id** | `com.malpidev.centavo` *(propuesta)* |

> Este documento define **qué** se construye y **qué no**. Es la base para el plan de implementación,
> pero no es el plan: no desglosa tareas por día. Las reglas generales viven en `../CLAUDE.md` del
> portafolio y aquí se aplican a Centavo sin contradecirlas.

---

## 1. Resumen del producto

**Qué es.** Centavo es una app de finanzas personales para registrar ingresos y gastos, organizarlos por
categoría, fijar un presupuesto mensual por categoría y ver en un dashboard cómo va el mes.

**Qué problema resuelve.** La mayoría de apps de finanzas obligan a crear cuenta, dependen de internet y
suben tus datos a un servidor desde el primer minuto. Centavo funciona **al 100 % sin cuenta y sin conexión**:
los datos viven en el teléfono. Si el usuario quiere, activa un **respaldo opcional** en la nube para no
perder nada al cambiar de teléfono.

**Para quién.** Personas que quieren controlar gastos de forma rápida y privada (estudiantes,
freelancers, familias jóvenes) y que no quieren conectar su banco ni registrarse.

**Qué demuestra en el portafolio** (lo que un cliente freelance debe ver):

| Destaca | Cómo se evidencia |
|---|---|
| **Offline-first con Drift** | La base local SQLite (Drift) es la fuente de verdad. Modo avión: todo funciona. |
| Respaldo opcional en Supabase | Iniciar sesión solo para respaldar/restaurar; RLS por usuario; last-write-wins aplicado **en la base de datos** (trigger). |
| Gráficas con fl_chart | Dashboard con dona de gastos por categoría y barras ingreso vs. gasto de 6 meses. |
| Seguridad local | Bloqueo con biometría (`local_auth`) al abrir y al volver a la app. |
| Portabilidad de datos | Exportar movimientos a CSV y compartirlos. |
| Arquitectura limpia | Repositorios intercambiables (`drift` / `supabase` / `mock`), modo demo sin backend, tests de dominio y de repositorios con Drift en memoria. |

---

## 2. Usuarios y roles

Centavo no tiene roles de negocio (no hay admin). Hay **modos de uso** de un mismo usuario:

| Modo | Cómo se entra | Qué puede hacer | Qué no puede hacer |
|---|---|---|---|
| **Local (sin cuenta)** — modo por defecto | *Start fresh* en la bienvenida | Todo el alcance del MVP: movimientos, categorías, presupuestos, dashboard, biometría, exportar CSV. | Respaldar/restaurar en la nube. |
| **Local + respaldo** | *Settings → Backup → Sign in* (código por email) | Todo lo anterior + *Back up now*, respaldo automático al abrir la app, *Restore*, borrar su respaldo, cerrar sesión conservando los datos locales. | Ver datos de otros usuarios (RLS). Sincronización en vivo entre dispositivos. |
| **Demo** | *Explore demo* en la bienvenida o en la pantalla de inicio de sesión del respaldo | Navegar y modificar datos de ejemplo en memoria; todo el flujo funciona. El respaldo se simula. | Nada persiste: al salir del demo o cerrar la app, los datos de ejemplo se pierden. No toca la base Drift real. |

Notas:
- El usuario con respaldo **sigue siendo local-first**: la app nunca lee de Supabase para pintar pantallas,
  solo para restaurar.
- `auth.users` es compartido con las otras apps del portafolio; el perfil de Centavo vive en `centavo.profiles`.

---

## 3. Alcance del MVP

### 3.1 Incluye

Cada feature tiene criterios de aceptación (CA) verificables. Todo lo que no esté aquí queda fuera.

**F1. Bienvenida y arranque**
- Primera vez: pantalla de bienvenida con tres opciones: *Start fresh*, *Explore demo*, *Restore from backup*.
- CA1: *Start fresh* crea la base local con las categorías por defecto y la moneda elegida, y lleva al dashboard sin pedir cuenta.
- CA2: Las siguientes aperturas van directo al dashboard (o a la pantalla de bloqueo si la biometría está activa).
- CA3: Se elige una moneda (lista corta: USD, EUR, MXN, COP, ARS, CLP, PEN, BRL; por defecto según el locale del dispositivo, fallback USD).

**F2. Movimientos (ingresos y gastos)**
- Crear, editar y eliminar un movimiento: tipo (ingreso/gasto), monto, categoría, fecha, nota opcional.
- Lista agrupada por día, filtrada por mes (selector de mes), con filtro por tipo y por categoría.
- CA1: El monto se valida > 0 y con máximo 2 decimales (o 0 decimales para monedas sin centavos como CLP).
- CA2: Solo se puede elegir una categoría del mismo tipo que el movimiento.
- CA3: Eliminar pide confirmación y ofrece *Undo* en un snackbar durante ~4 s.
- CA4: Crear/editar/eliminar funciona en modo avión y el cambio se ve inmediatamente en la lista y el dashboard.

**F3. Categorías**
- Categorías por defecto (gasto: Food, Transport, Home, Health, Entertainment, Shopping, Other; ingreso: Salary, Freelance, Other income).
- Crear/editar categoría: nombre, tipo, ícono (set cerrado de ~30 íconos Material) y color (paleta cerrada de ~12).
- Archivar categoría (deja de aparecer al crear movimientos, se conserva en históricos).
- CA1: No se permiten dos categorías activas con el mismo nombre y tipo.
- CA2: El tipo de una categoría no se puede cambiar una vez creada.
- CA3: Una categoría con movimientos no se elimina; se archiva. Una categoría sin movimientos sí se puede eliminar.

**F4. Presupuesto mensual por categoría**
- Para cada mes, el usuario asigna un monto límite a categorías de gasto.
- Pantalla de presupuestos del mes: por categoría, gastado / límite / restante y barra de progreso.
- CA1: Un solo presupuesto por categoría y mes.
- CA2: Estados visuales: `onTrack` (< 80 %), `warning` (80–100 %), `exceeded` (> 100 %).
- CA3: El total del mes suma solo categorías con presupuesto; los gastos sin presupuesto se muestran aparte como "Unbudgeted".
- CA4: Botón *Copy from previous month* cuando el mes actual no tiene presupuestos y el anterior sí.

**F5. Dashboard**
- Selector de mes; tarjetas de Ingresos, Gastos y Balance del mes.
- Dona de gastos por categoría (top 5 + "Others").
- Barras de ingreso vs. gasto de los últimos 6 meses.
- Resumen de presupuestos (las 3 categorías más cerca de su límite) con enlace a F4.
- CA1: Los totales coinciden exactamente (en centavos) con la suma de los movimientos del mes.
- CA2: Un mes sin datos muestra el estado vacío con CTA *Add your first transaction*.

**F6. Bloqueo con biometría**
- Interruptor en ajustes. Si está activo, al abrir la app y al volver tras ≥ 30 s en segundo plano se muestra la pantalla de bloqueo.
- Usa `local_auth` con respaldo al PIN/patrón del dispositivo (no solo biometría).
- CA1: El interruptor está deshabilitado (con explicación) si el dispositivo no tiene bloqueo de pantalla configurado.
- CA2: Al activarlo se pide autenticación una vez para confirmar.
- CA3: Mientras la app está en el selector de apps recientes, el contenido se oculta (Android `FLAG_SECURE` solo con bloqueo activo).

**F7. Exportar a CSV**
- *Settings → Export CSV*: rango (mes actual, mes elegido, todo) → genera archivo y abre la hoja de compartir del sistema.
- Columnas: `date,type,category,amount,currency,note` (fecha ISO `YYYY-MM-DD`, monto con punto decimal, UTF-8, RFC 4180).
- CA1: El archivo se abre correctamente en Google Sheets y Excel.
- CA2: Exportar un rango vacío muestra un aviso en vez de generar un archivo vacío.

**F8. Respaldo opcional en Supabase**
- Iniciar sesión con email + código de 6 dígitos (OTP de Supabase Auth), solo desde *Settings → Backup* o *Restore from backup*.
- *Back up now*, respaldo automático al abrir la app (si pasaron ≥ 24 h, activado por defecto al iniciar sesión, desactivable), *Restore from backup*, *Delete my backup*, *Sign out* (conserva datos locales).
- CA1: Sin conexión o con el backend pausado, el respaldo falla con un mensaje claro y la app sigue funcionando.
- CA2: Tras respaldar en el dispositivo A y restaurar en un dispositivo B limpio, B muestra los mismos movimientos, categorías y presupuestos.
- CA3: Se muestra la fecha del último respaldo exitoso.
- CA4: Un usuario no puede leer ni escribir filas de otro (verificado con test de RLS en local).
- Detalle de la estrategia en §7 y §8.3.

**F9. Modo demo**
- *Explore demo* carga repositorios mock en memoria con ~3 meses de datos realistas.
- Banner persistente "Demo mode — changes aren't saved" con acción *Exit demo*.
- CA1: El modo demo funciona sin red y sin `.env.json` configurado.
- CA2: Salir del demo vuelve a la bienvenida (o a los datos locales reales si existen) sin mezclar datos.

**F10. Ajustes y tema**
- Tema: System / Light / Dark. Moneda (cambiarla no convierte montos; solo cambia el formato — se avisa).
- Biometría (F6), Backup (F8), Export (F7), Categorías (F3), *About* (versión, enlace al repo, licencias).
- *Erase all local data* con doble confirmación.
- CA1: El modo oscuro se aplica a todas las pantallas, gráficas incluidas.

### 3.2 Fuera del MVP

| No se hará | Por qué |
|---|---|
| Sincronización en vivo multi-dispositivo (Realtime) | Complejidad de conflictos; el respaldo cubre el caso "cambio de teléfono". |
| Multi-moneda y conversión de tipos de cambio | Requiere API externa y modelo más complejo; una moneda por instalación. |
| Varias cuentas/billeteras (banco, efectivo, tarjeta) y transferencias | Duplica el modelo; no está en el "Incluye". |
| Movimientos recurrentes / programados | Requiere jobs en segundo plano; roadmap. |
| Conexión con bancos / lectura de SMS / OCR de tickets | Fuera de alcance y de presupuesto. |
| Adjuntar fotos de recibos (Storage) | No aporta a los "Destaca"; roadmap. |
| Notificaciones push de presupuesto excedido | Requeriría Edge Function y FCM; roadmap (local notifications). |
| Importar CSV | Validación y mapeo de columnas costosos; solo exportar. |
| Cifrado de la base local (SQLCipher) | Complica el build; la biometría protege el acceso. |
| Borrado de la cuenta de Auth desde la app | Necesita la secret key → Edge Function; en MVP solo se borra el respaldo. |
| Login con Google/Apple, contraseña o magic link | El OTP por email basta y evita configurar deep links. |
| Web y escritorio | Portafolio móvil. |
| Traducción al español de la UI | UI en inglés (mercado internacional); la infraestructura l10n queda lista. |
| Widgets de pantalla de inicio, Wear OS | Fuera de alcance. |

### 3.3 Futuro / Roadmap

- Sincronización incremental automática y en segundo plano (`workmanager`) entre varios dispositivos.
- Movimientos recurrentes y recordatorios locales ("¿registraste tus gastos hoy?").
- Alertas locales al pasar el 80 % / 100 % de un presupuesto.
- Varias cuentas y transferencias; multi-moneda con tasa manual.
- Importar CSV; adjuntar fotos de recibos (Supabase Storage).
- Cifrado local con SQLCipher.
- Borrado de cuenta vía Edge Function.
- UI en español; widget de "gasto de hoy".
- Metas de ahorro.

---

## 4. Módulos / features

| Feature (carpeta) | Descripción | Pantallas | ¿MVP? |
|---|---|---|---|
| `onboarding` | Bienvenida, elección de moneda, entrada a demo/restore | Welcome, Currency picker | Sí |
| `transactions` | CRUD de movimientos, lista por mes con filtros | Transactions list, Transaction form (new/edit) | Sí |
| `categories` | Categorías por defecto y personalizadas, archivar | Categories list, Category form | Sí |
| `budgets` | Presupuesto mensual por categoría, progreso, copiar mes anterior | Budgets overview, Budget form | Sí |
| `dashboard` | Totales del mes, gráficas, resumen de presupuestos | Dashboard | Sí |
| `export` *(transversal)* | Generar CSV y compartir | Export sheet | Sí |
| `security` *(transversal)* | Bloqueo biométrico y ocultar contenido en recientes | Lock screen | Sí |
| `backup` *(transversal)* | Auth por OTP, respaldar, restaurar, borrar respaldo | Backup settings, Sign in (email), Verify code | Sí |
| `demo` *(transversal)* | Cambio a repositorios mock, banner | (banner global) | Sí |
| `settings` *(transversal)* | Tema, moneda, accesos a los módulos, borrar datos, about | Settings, About | Sí |
| `recurring` | Movimientos recurrentes | — | No |
| `accounts` | Múltiples cuentas/billeteras | — | No |
| `sync` | Sincronización en vivo multi-dispositivo | — | No |

---

## 5. Flujos de usuario y navegación

### 5.1 Flujos principales

**A. Primer uso sin cuenta**
1. Abrir app → `/welcome`.
2. *Start fresh* → `/welcome/currency` → elegir moneda → *Continue*.
3. Se crean categorías por defecto en Drift → `/dashboard` en estado vacío.

**B. Registrar un gasto**
1. En cualquier tab principal, FAB *+* → `/transactions/new` (tipo *Expense* preseleccionado).
2. Escribir monto → elegir categoría (chips) → fecha (hoy por defecto) → nota opcional → *Save*.
3. Vuelve a la pantalla anterior; lista, dashboard y presupuestos se actualizan (streams de Drift).

**C. Definir presupuesto del mes**
1. Tab *Budgets* → mes actual. Si está vacío y el anterior tiene presupuestos: *Copy from previous month*.
2. *Set budget* en una categoría → `/budgets/edit?category=<id>&month=2026-10` → monto → *Save*.
3. Se ve gastado / límite / restante y el color de estado.

**D. Activar respaldo**
1. *Settings → Backup* → `/settings/backup` → *Sign in to back up*.
2. `/settings/backup/sign-in`: email → *Send code* → `/settings/backup/verify`: código de 6 dígitos.
3. Sesión creada → RPC `centavo.ensure_profile()` → primer respaldo completo → "Last backup: just now".

**E. Restaurar en un teléfono nuevo**
1. `/welcome` → *Restore from backup* → sign-in + verify.
2. Descarga todas las filas del usuario → merge last-write-wins en Drift → `/dashboard` con los datos.

**F. Explorar demo**
1. `/welcome` (o `/settings/backup/sign-in`) → *Explore demo*.
2. `appModeProvider = demo` → los providers de repositorio devuelven implementaciones mock → `/dashboard` con datos de ejemplo y banner.
3. *Exit demo* → vuelve a `/welcome` (o al dashboard real si ya existía base local).

**G. Abrir con bloqueo activo**
1. App a primer plano → si `biometricLock` y (arranque o ≥ 30 s en background) → `/lock`.
2. Autenticación OK → vuelve a la ruta previa. Cancelada → permanece en `/lock` con *Unlock*.

### 5.2 Mapa de rutas (go_router)

```
/welcome                          Welcome (Start fresh · Explore demo · Restore from backup)
/welcome/currency                 Currency picker
/lock                             Lock screen (redirect global si está bloqueada)

StatefulShellRoute (bottom navigation)
├── /dashboard                    Dashboard            ?month=YYYY-MM
├── /transactions                 Transactions list    ?month=YYYY-MM&type=&category=
├── /budgets                      Budgets overview     ?month=YYYY-MM
└── /settings                     Settings

/transactions/new                 Transaction form (create)   ?type=expense|income
/transactions/:id                 Transaction form (edit)
/budgets/edit                     Budget form   ?category=<id>&month=YYYY-MM
/settings/categories              Categories list
/settings/categories/new          Category form (create)
/settings/categories/:id          Category form (edit)
/settings/export                  Export CSV
/settings/backup                  Backup settings
/settings/backup/sign-in          Sign in (email) + botón Explore demo
/settings/backup/verify           Verify OTP code
/settings/about                   About
```

**Redirects** (en orden): 1) sin onboarding completado y no demo → `/welcome`; 2) bloqueo activo y app bloqueada → `/lock`;
3) rutas `/settings/backup/*` protegidas cuando no hay `.env.json` configurado (se oculta la opción).

---

## 6. Modelo de dominio

Modelos puros con `freezed` en `lib/features/<feature>/domain/`. Sin imports de Drift, Supabase ni Flutter UI.

### 6.1 Entidades

**`Money`** (value object, `lib/core/domain/money.dart`)
- `int amountMinor` — monto en unidades mínimas (centavos). **Nunca `double`.**
- `String currencyCode` — ISO 4217. Moneda única por instalación (en `AppSettings`).
- Operaciones: `+`, `-`, comparación, `percentOf`. Formateo con `intl` en presentation.
- `minorUnits` por moneda: 2 por defecto, 0 para CLP (tabla en `core`).

**`Category`**
| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` (UUID v4) | Generado en el cliente (necesario para offline + respaldo). |
| `name` | `String` | 1–30 caracteres, trim. |
| `type` | `TransactionType` (`income` \| `expense`) | Inmutable. |
| `icon` | `String` | Clave de un set cerrado (`food`, `car`, …). |
| `color` | `int` | ARGB de la paleta cerrada. |
| `isDefault` | `bool` | Creada en el onboarding. |
| `archivedAt` | `DateTime?` | Archivada. |
| `createdAt`, `updatedAt` | `DateTime` (UTC) | `updatedAt` se usa para last-write-wins. |
| `deletedAt` | `DateTime?` | Tombstone (borrado lógico, necesario para respaldar borrados). |

**`Transaction`** (en código `MoneyTransaction` para no chocar con `drift`)
| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` (UUID v4) | |
| `type` | `TransactionType` | |
| `amountMinor` | `int` | > 0 (el signo lo da `type`). |
| `categoryId` | `String` | Debe coincidir en `type` con la categoría. |
| `occurredOn` | `DateTime` (fecha local, sin hora) | Día del movimiento. |
| `note` | `String?` | ≤ 140 caracteres. |
| `createdAt`, `updatedAt`, `deletedAt` | `DateTime` / `DateTime?` | Igual que arriba. |

**`Budget`**
| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` (UUID v4) | |
| `categoryId` | `String` | Solo categorías de tipo `expense`. |
| `month` | `YearMonth` (value object `year`, `month`) | Se persiste como fecha día 1 (`2026-10-01`). |
| `limitMinor` | `int` | > 0. |
| `createdAt`, `updatedAt`, `deletedAt` | | |

**`AppSettings`** (no se respalda en MVP salvo `currencyCode`, que va a `profiles`)
`currencyCode`, `themeMode`, `biometricLockEnabled`, `onboardingCompleted`, `autoBackupEnabled`.

**`BackupStatus`**: `signedInEmail?`, `lastBackupAt?`, `inProgress`.

Relaciones: `Category 1—N Transaction`, `Category 1—N Budget` (una por mes).

### 6.2 Reglas de negocio

1. Montos siempre enteros positivos en unidades mínimas.
2. `transaction.type == category.type`; `budget` solo sobre categorías `expense`.
3. Unicidad: categoría activa por (`name` insensible a mayúsculas, `type`); presupuesto por (`categoryId`, `month`).
4. Borrado siempre lógico (`deletedAt`); las consultas de UI excluyen tombstones.
5. Categoría con movimientos no borrados → solo se archiva.
6. Toda escritura actualiza `updatedAt = now().toUtc()`.
7. Cambiar la moneda no convierte montos.

### 6.3 Casos de uso (solo donde hay lógica real)

| Caso de uso | Lógica |
|---|---|
| `GetMonthSummary(month)` | Totales de ingreso, gasto y balance del mes; agrupación de gastos por categoría con top 5 + "Others". |
| `GetMonthlyTrend(endMonth, months = 6)` | Serie ingreso/gasto por mes, rellenando meses vacíos con 0. |
| `GetBudgetProgress(month)` | Por categoría con presupuesto: gastado, restante, % y estado (`onTrack`/`warning`/`exceeded`); total presupuestado; gasto "unbudgeted". |
| `CopyBudgetsFromPreviousMonth(month)` | Copia límites del mes anterior sin sobrescribir los existentes; ignora categorías archivadas. |
| `DeleteOrArchiveCategory(id)` | Decide borrar vs. archivar según existan movimientos. |
| `ExportTransactionsCsv(range)` | Construye filas CSV con escape RFC 4180 y formato de monto por moneda. |
| `RunBackup()` / `RestoreBackup()` | Selecciona cambios desde `lastBackupAt`, orden de subida (categorías → presupuestos → movimientos), merge LWW al restaurar. |
| `SeedDefaultCategories(currency)` | Crea categorías por defecto una sola vez. |

CRUD simple (crear/editar movimiento, etc.) **no** tiene caso de uso: la UI llama al repositorio vía provider.
Las validaciones de entrada del formulario viven en un validador de dominio puro reutilizado por el form.

### 6.4 Errores de dominio tipados

`sealed class DomainError` en `lib/core/errors/`. Convención común (regla 6 del `CLAUDE.md`): los repositorios **lanzan**
`DomainError`; no devuelven `Result`. Riverpod (`AsyncValue.guard`) captura la excepción y la UI hace `switch` exhaustivo:

| Error | Cuándo |
|---|---|
| `ValidationError(field, reason)` | Monto ≤ 0, nombre vacío, nota demasiado larga. |
| `NotFoundError(entity, id)` | Id inexistente o borrado. |
| `DuplicateError(entity)` | Categoría o presupuesto duplicado. |
| `CategoryTypeMismatchError` | Movimiento/presupuesto con categoría de tipo incorrecto. |
| `CategoryInUseError` | Intento de borrar categoría con movimientos. |
| `StorageError(cause)` | Error inesperado de Drift/SQLite. |
| `NetworkError` | Sin conexión o timeout en respaldo. |
| `BackendUnavailableError` | Proyecto Supabase pausado / 5xx. |
| `AuthError(kind)` | `invalidCode`, `codeExpired`, `rateLimited`, `notSignedIn`. |
| `BiometricError(kind)` | `notAvailable`, `notEnrolled`, `lockedOut`, `cancelled`. |
| `ExportError(reason)` | `emptyRange`, error de escritura de archivo. |

Los repositorios capturan `SqliteException`, `PostgrestException`, `AuthException`, `SocketException` y
`PlatformException` y los traducen a estos tipos. Nunca llegan excepciones crudas a presentation.

---

## 7. Backend: uso de Supabase

Supabase en Centavo es **solo un destino de respaldo**. La app nunca consulta Supabase para pintar pantallas.

### 7.1 Schema `centavo` y tablas

Espejo de las tablas locales + `user_id`. Todas con `user_id uuid not null default auth.uid() references auth.users on delete cascade`.

**`centavo.profiles`**
| Columna | Tipo | Constraints |
|---|---|---|
| `id` | `uuid` | PK, FK `auth.users(id)` on delete cascade |
| `currency_code` | `char(3)` | not null, check `~ '^[A-Z]{3}$'` |
| `created_at` / `updated_at` | `timestamptz` | not null default `now()` |

**`centavo.categories`**
| Columna | Tipo | Constraints |
|---|---|---|
| `id` | `uuid` | PK (generado en el cliente) |
| `user_id` | `uuid` | not null; `unique (id, user_id)` para FKs compuestas |
| `name` | `text` | not null, check `char_length between 1 and 30` |
| `type` | `text` | check `in ('income','expense')` |
| `icon` | `text` | not null |
| `color` | `integer` | not null |
| `is_default` | `boolean` | not null default false |
| `archived_at`, `deleted_at` | `timestamptz` | null |
| `created_at`, `updated_at` | `timestamptz` | not null (los pone el cliente) |
| `synced_at` | `timestamptz` | not null default `now()` (lo pone el trigger) |

**`centavo.transactions`**
| Columna | Tipo | Constraints |
|---|---|---|
| `id` | `uuid` | PK |
| `user_id` | `uuid` | not null |
| `category_id` | `uuid` | not null; FK `(category_id, user_id) → categories(id, user_id)` |
| `type` | `text` | check `in ('income','expense')` |
| `amount_minor` | `bigint` | check `> 0` |
| `occurred_on` | `date` | not null |
| `note` | `text` | check `char_length <= 140` |
| `created_at`, `updated_at`, `deleted_at`, `synced_at` | `timestamptz` | como arriba |

**`centavo.budgets`**
| Columna | Tipo | Constraints |
|---|---|---|
| `id` | `uuid` | PK |
| `user_id` | `uuid` | not null |
| `category_id` | `uuid` | FK `(category_id, user_id) → categories(id, user_id)` |
| `month` | `date` | check `month = date_trunc('month', month)::date` |
| `limit_minor` | `bigint` | check `> 0` |
| `created_at`, `updated_at`, `deleted_at`, `synced_at` | `timestamptz` | |
| — | — | `unique index (user_id, category_id, month) where deleted_at is null` |

Índices: `(user_id, updated_at)` en las tres tablas de datos (para restauración ordenada).

### 7.2 RLS

RLS activado en **todas** las tablas. Cada política va comentada con `comment on policy` y un comentario SQL en la migración.

| Tabla | Política | Qué protege |
|---|---|---|
| `profiles` | `select`/`update` `using/with check (id = auth.uid())`; sin `insert` (lo hace `ensure_profile()`) ni `delete` (cascade desde `auth.users`) | Cada usuario solo ve y edita su propio perfil. |
| `categories` | `select`, `insert`, `update`, `delete` con `user_id = auth.uid()` (`with check` en insert/update) | Nadie lee ni escribe categorías ajenas; impide insertar filas a nombre de otro usuario. |
| `transactions` | Igual que `categories` | Idem; la FK compuesta impide además apuntar a una categoría de otro usuario. |
| `budgets` | Igual que `categories` | Idem. |

Solo rol `authenticated`; `anon` no tiene políticas (acceso denegado). El `delete` existe únicamente para *Delete my backup*.

### 7.3 Lógica en BD

- **Constraints**: checks de monto, tipo, mes normalizado, longitud; FKs compuestas `(category_id, user_id)`; unicidad parcial de presupuesto.
- **Trigger `centavo.keep_newest()`** (`before update` en las tres tablas de datos): si `new.updated_at < old.updated_at`
  devuelve `null` (se ignora la actualización). **Last-write-wins garantizado por la base de datos**, aunque un
  dispositivo con datos viejos suba después.
- **Trigger `centavo.set_synced_at()`** (`before insert or update`): `new.synced_at = now()`.
- **Trigger `centavo.check_category_type()`** (`before insert or update` en `transactions` y `budgets`): el tipo del
  movimiento coincide con el de la categoría; los presupuestos solo sobre categorías `expense`.
- **RPCs**: solo `ensure_profile()` (convención común para crear perfiles). El respaldo es `upsert` por lotes vía PostgREST y la restauración es `select` filtrado por RLS.
  Si el upsert por lotes resulta lento, se evaluará una RPC `centavo.backup_batch(jsonb)` (decisión abierta, §17).

### 7.4 Auth y perfiles

- Auth **opcional**, solo para respaldo. Método: `signInWithOtp(email, shouldCreateUser: true)` + `verifyOTP(type: email)` con código de 6 dígitos.
  Es la convención común de las 4 apps (`CLAUDE.md`): plantilla de email genérica con `{{ .Token }}`, "Confirm email" activado y SMTP propio en remoto.
- `auth.users` es compartido con Agendo, Rutta y Vitrina: el mismo email es el mismo usuario en todas.
  **No** se usa un trigger sobre `auth.users` (crearía perfiles de Centavo para usuarios de otras apps); tras verificar el
  código la app llama a la RPC `centavo.ensure_profile()` (`security definer`, idempotente), único camino para crear perfiles.
- Sesión persistida por `supabase_flutter`. *Sign out* no borra la base local.

### 7.5 Realtime, Storage y Edge Functions

| Servicio | ¿Se usa? | Motivo |
|---|---|---|
| Realtime | **No** | No hay sincronización en vivo; Drift es la fuente de verdad. |
| Storage | **No** | El CSV se comparte con la hoja del sistema; no hay adjuntos en MVP. |
| Edge Functions | **No** | Ninguna operación requiere una clave secreta. (Borrado de cuenta → roadmap.) |

### 7.6 Migraciones, seed y entorno; Drift local

**Supabase**
- `supabase/migrations/20260928000000_centavo_init.sql`: `create schema centavo`, grants a `authenticated`, tablas, índices,
  triggers, RLS y políticas comentadas. Solo toca el schema `centavo`.
- `supabase/config.toml`: añadir `centavo` a `[api] schemas` y `extra_search_path`. En remoto, exponer `centavo` en *API settings*.
- `supabase/seed.sql` (solo local): un usuario demo (`demo@centavo.test`, UUID fijo) en `auth.users`, su perfil, las
  categorías por defecto y ~3 meses de movimientos y presupuestos (mismo dataset que el mock, §12).
  **No se aplica en remoto** porque `auth.users` es compartido.
- Local: `supabase start` (Docker) → `supabase db reset` aplica migraciones + seed.
- Remoto: `psql "$SUPABASE_DB_URL" -f supabase/migrations/<archivo>.sql`. **Nunca `supabase db push`** (historial compartido entre repos).
- Test de RLS: `supabase/tests/rls_test.sql` con pgTAP (`supabase test db`) que comprueba que el usuario A no ve filas de B.

**Drift (base local, fuente de verdad)**
- Archivo `centavo.sqlite` en el directorio de documentos de la app (`drift_flutter` → `driftDatabase(name: 'centavo')`).
- Tablas: `categories`, `transactions`, `budgets` (mismas columnas que arriba, sin `user_id`/`synced_at`, UUID como `TEXT`,
  fechas como `DateTime` UTC, `occurredOn` y `month` como texto ISO `YYYY-MM-DD`), y `sync_state` (clave/valor: `lastBackupAt`, `lastRestoreAt`).
- Constraints locales equivalentes (`CHECK amount_minor > 0`, índices únicos) para que las reglas se cumplan también sin backend.
- `schemaVersion = 1`. Cada cambio posterior: subir `schemaVersion`, `dart run drift_dev make-migrations` (guarda snapshots en
  `drift_schemas/` y genera tests de migración) y migración paso a paso en `MigrationStrategy.onUpgrade`.
- Ajustes simples (`themeMode`, `biometricLockEnabled`, etc.) en `shared_preferences`, no en Drift.

---

## 8. Arquitectura

### 8.1 Capas y reglas de dependencia

Clean Architecture ligera por feature (CLAUDE.md), aplicada así:

- `domain/`: modelos `freezed`, interfaces de repositorio, casos de uso con lógica real, errores. No importa `data/`, Drift, Supabase ni Flutter UI.
- `data/`: implementaciones `drift_*`, `supabase_*`, `mock_*`, mappers solo cuando el formato difiere (fila Drift/JSON ↔ dominio).
- `presentation/`: pantallas, widgets y providers Riverpod. **Nunca** importa Drift ni `supabase_flutter` directamente.
- `core/`: errores (`DomainError`), `Money`, tema, router, base Drift, cliente Supabase, configuración de entorno, `AppMode`.

### 8.2 Árbol de archivos (ejemplo, no exhaustivo)

```
Centavo/
├── lib/
│   ├── main.dart
│   ├── app.dart                         # MaterialApp.router, tema claro/oscuro
│   ├── core/
│   │   ├── config/env.dart              # lee --dart-define (SUPABASE_URL, …)
│   │   ├── database/app_database.dart   # @DriftDatabase + tablas + migraciones
│   │   ├── database/tables/*.dart
│   │   ├── supabase/supabase_client.dart
│   │   ├── domain/money.dart · year_month.dart · result.dart
│   │   ├── errors/centavo_failure.dart
│   │   ├── app_mode/app_mode_provider.dart   # local | demo
│   │   ├── router/app_router.dart
│   │   ├── theme/app_theme.dart · app_colors.dart
│   │   └── utils/clock.dart · uuid.dart
│   ├── l10n/app_en.arb
│   └── features/
│       ├── transactions/
│       │   ├── domain/money_transaction.dart · transaction_repository.dart
│       │   ├── data/drift_transaction_repository.dart · mock_transaction_repository.dart
│       │   └── presentation/transactions_screen.dart · transaction_form_screen.dart · transactions_providers.dart
│       ├── categories/{domain,data,presentation}/…
│       ├── budgets/
│       │   ├── domain/budget.dart · budget_repository.dart · get_budget_progress.dart
│       │   ├── data/drift_budget_repository.dart · mock_budget_repository.dart
│       │   └── presentation/…
│       ├── dashboard/{domain/get_month_summary.dart, presentation/…}
│       ├── backup/
│       │   ├── domain/backup_repository.dart · auth_repository.dart · run_backup.dart · restore_backup.dart
│       │   ├── data/supabase_backup_repository.dart · supabase_auth_repository.dart
│       │   │        mock_backup_repository.dart · mock_auth_repository.dart · dtos/*.dart
│       │   └── presentation/…
│       ├── security/{domain/biometric_repository.dart, data/local_auth_biometric_repository.dart, mock_…, presentation/lock_screen.dart}
│       ├── export/{domain/export_transactions_csv.dart, data/file_share_exporter.dart, presentation/…}
│       ├── onboarding/…
│       ├── demo/data/demo_dataset.dart
│       └── settings/…
├── test/
│   ├── core/money_test.dart
│   ├── features/budgets/domain/get_budget_progress_test.dart
│   ├── features/transactions/data/drift_transaction_repository_test.dart   # NativeDatabase.memory()
│   ├── features/backup/…
│   └── drift/generated_migrations/…     # generado por make-migrations
├── drift_schemas/                         # snapshots del esquema Drift
├── supabase/
│   ├── config.toml
│   ├── migrations/20260928000000_centavo_init.sql
│   ├── tests/rls_test.sql
│   └── seed.sql
├── .maestro/
│   ├── demo_add_expense.yaml
│   └── fresh_start_budget.yaml
├── docs/definicion.md
├── assets/fonts/ · assets/icon/
├── .github/workflows/ci.yaml · release.yaml
├── .env.example.json
├── analysis_options.yaml
├── build.yaml                             # opciones de drift/freezed
├── CLAUDE.md                              # excepción documentada: repos drift + supabase + mock
└── README.md
```

### 8.3 Repositorios intercambiables y modo demo

Cómo encaja "offline-first" con la regla 4 del CLAUDE.md (*cada repositorio tiene `supabase` y `mock`*):

| Interfaz (domain) | Implementación real | Mock | Nota |
|---|---|---|---|
| `TransactionRepository` | `DriftTransactionRepository` | `MockTransactionRepository` | En Centavo el rol "real" de los datos lo cumple **Drift**, no Supabase. |
| `CategoryRepository` | `DriftCategoryRepository` | `MockCategoryRepository` | |
| `BudgetRepository` | `DriftBudgetRepository` | `MockBudgetRepository` | |
| `BackupRepository` | `SupabaseBackupRepository` | `MockBackupRepository` | Único punto que escribe/lee Supabase (datos). |
| `AuthRepository` | `SupabaseAuthRepository` | `MockAuthRepository` | OTP por email. |
| `BiometricRepository` | `LocalAuthBiometricRepository` | `MockBiometricRepository` | Mock siempre "ok" (demo y tests). |
| `SettingsRepository` | `PrefsSettingsRepository` | `InMemorySettingsRepository` | |

Esta adaptación se documenta en el `CLAUDE.md` del repo como excepción justificada: los datos de negocio no
tienen implementación `supabase_*` porque Supabase no es fuente de verdad; en su lugar existe el
`BackupRepository` con implementación `supabase` y `mock`. Se mantiene el espíritu de la regla: todo repositorio
tiene una implementación real y un mock usados en tests y en el modo demo.

**Estrategia de respaldo (simple y explícita)**
- **Qué se sube**: `profiles.currency_code` y las filas de `categories`, `budgets` y `transactions` (incluidos tombstones)
  con `updatedAt > lastBackupAt`. Primera vez: todo.
- **Cuándo**: manual (*Back up now*) y automático al abrir la app / volver a primer plano si hay sesión, `autoBackupEnabled`
  y pasaron ≥ 24 h desde el último respaldo exitoso. Nunca en segundo plano con la app cerrada.
- **Cómo**: `upsert` en lotes de 500 filas, en orden categorías → presupuestos → movimientos. `lastBackupAt` se actualiza
  solo si todo termina bien (hora de inicio del respaldo, para no perder cambios hechos durante la subida).
- **Restaurar**: descarga todas las filas del usuario y hace merge en Drift por `id`: se queda la fila con `updatedAt`
  más reciente (last-write-wins). Nunca borra filas locales que no estén en el servidor.
- **Conflictos**: last-write-wins por fila según `updatedAt` del cliente, reforzado en el servidor por el trigger `keep_newest`.
  Supuesto: un usuario usa un dispositivo a la vez.
- **Borrar respaldo**: elimina todas las filas del usuario en las 4 tablas (el usuario de Auth permanece).
- **Qué NO se hace**: sincronización continua, Realtime, merge por campo, resolución manual de conflictos, respaldo de
  ajustes (tema, biometría), cifrado extremo a extremo, purga automática de tombstones.

**Modo demo ("Explore demo")**
- `appModeProvider` (`AppMode.local` | `AppMode.demo`, en memoria, no persistido).
- Cada provider de repositorio hace `switch (ref.watch(appModeProvider))` y devuelve la implementación Drift/Supabase o la mock.
  Al cambiar el modo, Riverpod reconstruye todo el grafo dependiente: no hay datos mezclados.
- Los mocks usan listas en memoria + `StreamController` para emitir cambios (misma API reactiva que Drift), cargadas con `DemoDataset`.
- El demo nunca abre la base Drift real ni el cliente Supabase; funciona sin `.env.json`.

### 8.4 Gestión de estado y errores

- Riverpod con `riverpod_generator` (`@riverpod`). Providers de repositorio `keepAlive: true`; providers de pantalla autoDispose.
- Lecturas reactivas: los repositorios exponen `Stream<List<…>>` (`watch…`) desde Drift; la UI usa `StreamProvider` → `AsyncValue`
  con `when(loading/error/data)` y un widget común `AsyncStateView` (carga, vacío, error con *Retry*).
- Escrituras: `AsyncNotifier` por formulario (`TransactionFormController`, etc.) con `AsyncValue.guard`; el `DomainError`
  lanzado queda en el estado y se traduce a mensaje de usuario con `errorMessage(DomainError)` en presentation.
- Estado global: `appModeProvider`, `settingsProvider`, `lockStateProvider`, `backupStatusProvider`.
- `Clock` inyectable para tests de fechas y de `updatedAt`.

---

## 9. Stack y dependencias principales

| Paquete | Para qué |
|---|---|
| `flutter_riverpod`, `riverpod_annotation` | Estado e inyección de dependencias |
| `riverpod_generator` *(dev)* | Generación de providers |
| `go_router` | Navegación declarativa, shell con tabs, redirects |
| `freezed_annotation`, `json_annotation` | Modelos inmutables, uniones selladas |
| `freezed`, `json_serializable` *(dev)* | Generación de modelos y JSON (DTOs de respaldo) |
| `drift`, `drift_flutter` | Base local SQLite, fuente de verdad |
| `drift_dev`, `build_runner` *(dev)* | Generación de Drift y del resto del código |
| `supabase_flutter` | Auth OTP y respaldo |
| `fl_chart` | Dona y barras del dashboard |
| `local_auth` | Bloqueo biométrico / PIN del dispositivo |
| `shared_preferences` | Ajustes simples |
| `csv` | Serialización CSV RFC 4180 |
| `share_plus`, `path_provider` | Guardar y compartir el CSV |
| `intl`, `flutter_localizations` | Formato de moneda/fechas, l10n (ARB) |
| `uuid` | Ids generados en el cliente |
| `very_good_analysis` *(dev)* | Lints |
| `mocktail` *(dev)* | Mocks en tests |
| `flutter_launcher_icons`, `flutter_native_splash` *(dev)* | Ícono y splash |
| Maestro (CLI externa) | E2E |

Versiones: las estables más recientes al crear el proyecto (`flutter pub add` sin fijar versión; quedan fijadas en `pubspec.lock`).

---

## 10. Andamiaje inicial desde la CLI

Proyecto nuevo con la CLI oficial, sin plantillas. Flutter stable más reciente. Desde la carpeta existente `Centavo/`:

```bash
cd ~/Developer/MobilePorfolio/Centavo
flutter channel stable && flutter upgrade

# 1. Crear el proyecto en la carpeta actual
flutter create --org com.malpidev --project-name centavo --platforms android,ios .

# 2. Dependencias
flutter pub add flutter_riverpod riverpod_annotation go_router freezed_annotation json_annotation \
  drift drift_flutter supabase_flutter fl_chart local_auth shared_preferences csv share_plus \
  path_provider intl uuid
flutter pub add flutter_localizations --sdk=flutter
flutter pub add --dev build_runner riverpod_generator freezed json_serializable drift_dev \
  very_good_analysis mocktail flutter_launcher_icons flutter_native_splash
```

3. **Lints**: reemplazar `analysis_options.yaml` por
   `include: package:very_good_analysis/analysis_options.yaml` y excluir `**/*.g.dart`, `**/*.freezed.dart`.
4. **l10n**: `generate: true` en `pubspec.yaml` + `l10n.yaml` apuntando a `lib/l10n/app_en.arb`.
5. **Android**: `MainActivity` extiende `FlutterFragmentActivity` (requisito de `local_auth`); permiso
   `USE_BIOMETRIC` en `AndroidManifest.xml`. iOS: `NSFaceIDUsageDescription` en `Info.plist`.
6. **Estructura**: crear `lib/core/…` y `lib/features/<feature>/{domain,data,presentation}` según §8.2.
7. **Generación de código**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs   # o `watch` durante desarrollo
   ```
8. **Supabase local**:
   ```bash
   supabase init            # crea supabase/config.toml
   # añadir "centavo" a [api] schemas en config.toml
   supabase migration new centavo_init
   supabase start           # Docker
   supabase db reset        # migraciones + seed.sql
   ```
9. **Entorno**: copiar `.env.example.json` → `.env.json` (en `.gitignore`) y ejecutar:
   ```bash
   flutter run --dart-define-from-file=.env.json
   ```
   Sin `.env.json` la app funciona en modo local y demo; solo se oculta el respaldo.
10. **Ícono y splash**: configurar `flutter_launcher_icons` y `flutter_native_splash` en `pubspec.yaml` y ejecutar
    `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.
11. `.gitignore`: añadir `.env.json`, `supabase/.temp/`, `coverage/`.

> **El repositorio git lo inicializa el autor manualmente.** Este documento no incluye `git init` ni commits.

---

## 11. Identidad visual

Concepto: una moneda de cobre ("centavo") sobre un verde sobrio de finanzas. Material 3 con `ColorScheme` propio.

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `primary` | `#1F6F5C` (verde pino) | `#6FD3B5` | Botones, FAB, selección |
| `secondary` (acento) | `#B8692E` (cobre) | `#E9A56B` | Detalles, ícono, destacados |
| `background` / `surface` | `#F7F6F2` / `#FFFFFF` | `#0F1412` / `#18201D` | Fondos, tarjetas |
| `onSurface` | `#1B1F1D` | `#E6EAE7` | Texto |
| `income` | `#2E8B57` | `#7BD69A` | Montos de ingreso |
| `expense` | `#C8453B` | `#FF8A7F` | Montos de gasto |
| `warning` | `#D99A1E` | `#F2C055` | Presupuesto 80–100 % |
| `error` | `#B3261E` | `#F2B8B5` | Errores, presupuesto excedido |

- **Paleta de categorías**: 12 colores fijos con variante clara/oscura, contraste AA verificado sobre `surface`.
- **Tipografía**: *Manrope* (títulos y montos grandes) + *Inter* (cuerpo), empaquetadas en `assets/fonts` (sin descargar en runtime).
  Montos con cifras tabulares (`FontFeature.tabularFigures()`).
- **Ícono**: moneda cobre con el signo "¢" estilizado sobre fondo verde pino; versión *adaptive* para Android.
- **Splash**: fondo `primary` (claro) / `background` (oscuro) con la moneda centrada; `flutter_native_splash` con variante `dark`.
- **Modo oscuro obligatorio**: `ThemeMode.system` por defecto, seleccionable en ajustes; las gráficas leen colores del tema.

---

## 12. Estados de UI y datos de demo

### 12.1 Estados por pantalla

| Pantalla | Carga | Vacío | Error |
|---|---|---|---|
| Dashboard | Skeleton de tarjetas y gráficas | "No transactions in <month>" + *Add transaction* | Mensaje + *Retry* (error de base local) |
| Transactions list | Skeleton de filas | Ilustración + *Add your first transaction*; con filtros: "No results" + *Clear filters* | Mensaje + *Retry* |
| Transaction form | Spinner al cargar para editar; botón *Save* en progreso | — | Errores de validación por campo; snackbar para `StorageError` |
| Budgets | Skeleton | "No budgets for <month>" + *Set a budget* / *Copy from previous month* | Mensaje + *Retry* |
| Categories | Skeleton | (nunca vacío: existen las por defecto) sección *Archived* vacía oculta | Mensaje + *Retry* |
| Lock screen | Esperando biometría | — | `lockedOut` / `notAvailable` con instrucción |
| Backup | Progreso con paso actual ("Uploading transactions…") | "Not signed in" + beneficios del respaldo | Offline / backend pausado / código inválido con acción |
| Export | Progreso al generar | "Nothing to export for this range" | Error de escritura/compartir |
| Welcome / Restore | Spinner durante restauración | Restaurar sin datos en la nube → "No backup found" | Error de red con *Retry* |

### 12.2 Datos de ejemplo (mock y seed)

Mismo dataset en `lib/features/demo/data/demo_dataset.dart` (mock) y en `supabase/seed.sql` (local), moneda **USD**:
- Categorías por defecto (10) + 2 personalizadas: *Coffee* y *Gym*; 1 archivada: *Old car*.
- **3 meses** (el actual y los 2 anteriores, calculados relativos a "hoy" en el mock) con ~40–60 movimientos por mes:
  salario mensual (`$3,200.00`), 1–2 ingresos freelance, renta (`$950.00`), supermercado semanal, transporte, cafés, ocio.
- Presupuestos en los 3 meses para Food, Transport, Entertainment, Shopping y Coffee, con al menos uno `exceeded`
  y uno `warning` en el mes actual para mostrar los estados.
- El usuario demo de seed (`demo@centavo.test`) solo existe en local.

---

## 13. Estrategia de testing

| Nivel | Qué se prueba | Herramienta |
|---|---|---|
| Unit de dominio | `Money` (suma, formato de unidades mínimas, CLP sin decimales), `YearMonth`, `GetMonthSummary`, `GetMonthlyTrend`, `GetBudgetProgress` (umbrales 80/100 %), `CopyBudgetsFromPreviousMonth`, `DeleteOrArchiveCategory`, validadores, `ExportTransactionsCsv` (escape de comas/comillas) | `flutter_test` |
| Repositorios Drift | CRUD, tombstones excluidos, unicidad, streams emiten tras escribir, traducción a `DomainError` | Drift en memoria (`NativeDatabase.memory()`) |
| Migraciones Drift | Tests generados por `drift_dev make-migrations` (a partir de `schemaVersion` 2) | `drift_dev` |
| Respaldo | `RunBackup` selecciona solo cambios desde `lastBackupAt`, orden de subida, no actualiza `lastBackupAt` si falla; `RestoreBackup` aplica LWW | `mocktail` sobre `BackupRepository` + Drift en memoria |
| Mapeo Supabase | DTO ↔ dominio; `PostgrestException`/`SocketException` → `NetworkError`/`BackendUnavailableError` | `mocktail` |
| BD (RLS y triggers) | Aislamiento entre usuarios, `keep_newest`, `check_category_type`, checks | pgTAP con `supabase test db` (local) |
| Widgets clave | Transaction form (validaciones), Budgets (colores de estado), Lock screen, `AsyncStateView` en sus tres estados | `flutter_test` + `ProviderScope` con overrides mock |
| E2E | Ver abajo | Maestro |

**Flujos de Maestro** (`appId: com.malpidev.centavo`):
1. `demo_add_expense.yaml` (**obligatorio, flujo feliz**): Welcome → *Explore demo* → FAB → gasto de 12.50 en *Coffee* →
   *Save* → aparece en la lista → el total de gastos del dashboard aumenta.
2. `fresh_start_budget.yaml`: *Start fresh* → USD → crear presupuesto de Food → registrar gasto → ver progreso en Budgets.

Meta orientativa de cobertura: ≥ 80 % en `domain/` y `data/drift_*`. Los E2E se corren localmente (no en CI; ver §17).

---

## 14. CI/CD y entrega

**`.github/workflows/ci.yaml`** — en cada PR y push a `main`:
1. `actions/checkout` + `subosito/flutter-action` (canal stable, con caché).
2. `flutter pub get`
3. `dart run build_runner build --delete-conflicting-outputs`
4. `dart format --output=none --set-exit-if-changed lib test`
5. `flutter analyze` (sin warnings)
6. `flutter test --coverage`
7. *(Opcional, job separado)* `supabase start` + `supabase test db` para las pruebas pgTAP de RLS.

**`.github/workflows/release.yaml`** — en cada tag `v*`:
1. Mismos pasos de verificación.
2. Crear `.env.json` desde secrets (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`) y el keystore desde
   `ANDROID_KEYSTORE_BASE64` + `ANDROID_KEY_*` (firma de release en `android/key.properties`, fuera de git).
3. `flutter build apk --release --dart-define-from-file=.env.json`
4. Publicar `app-release.apk` como `centavo-vX.Y.Z.apk` en **GitHub Releases** (`softprops/action-gh-release`) con notas.

Versionado semántico; `v1.0.0` = MVP listo con demo pública. Keep-alive de Supabase: no vive aquí (repo de Agendo).

---

## 15. Variables de entorno

Flutter usa `--dart-define-from-file=.env.json`. Como `--dart-define-from-file` requiere JSON, el archivo documentado del
repo es **`.env.example.json`** (cumple la regla de `.env.example` del CLAUDE.md). `.env.json` está en `.gitignore`.

```json
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxxxxxxxxxxxxxxxxxxx",
  "BACKUP_ENABLED": "true"
}
```

| Variable | Descripción | Obligatoria |
|---|---|---|
| `SUPABASE_URL` | URL del proyecto (local de `supabase start` o remoto compartido). | Solo para respaldo |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key (`sb_publishable_…`). **Nunca** la secret key. | Solo para respaldo |
| `BACKUP_ENABLED` | `false` oculta todo el módulo de respaldo (builds sin backend). Si faltan URL/key, se trata como `false`. | No (default `true`) |

Fuera del cliente (no van en `.env.json`):
| Secreto | Dónde | Para qué |
|---|---|---|
| `SUPABASE_DB_URL` | Shell local del autor | Aplicar migraciones remotas con `psql` |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | GitHub Secrets | Firmar el APK de release |

---

## 16. Definición de terminado

Para pasar a ✅ **MVP listo**:
- [ ] F1–F10 cumplen sus criterios de aceptación en Android (e iOS si es posible).
- [ ] Toda la app funciona en modo avión sin cuenta (verificado manualmente).
- [ ] Modo demo funcionando sin backend y sin `.env.json`.
- [ ] Respaldo y restauración verificados entre dos dispositivos/emuladores contra Supabase local y remoto.
- [ ] Estados de carga, vacío y error en cada pantalla (§12.1); nada de pantallas en blanco.
- [ ] Modo oscuro correcto en todas las pantallas y gráficas.
- [ ] Tests unitarios de dominio, repositorios Drift (en memoria) y respaldo; pgTAP de RLS; flujo Maestro `demo_add_expense` en verde.
- [ ] CI en verde; `flutter analyze` sin warnings con `very_good_analysis`; `dart format` sin cambios.
- [ ] RLS activado y políticas comentadas en la migración; migración aplicada en remoto con `psql`.
- [ ] `.env.example.json` completo; ningún secreto en el repo.
- [ ] `CLAUDE.md` del repo documenta la excepción drift/supabase/mock.
- [ ] README completo según la plantilla del portafolio (incluye diagrama de capas y explicación offline-first + respaldo).

Para 🚀 **Publicado**: APK en GitHub Releases + GIF de demo (15–30 s: demo → gasto → dashboard → presupuesto → modo oscuro) + repo público.

---

## 17. Riesgos, supuestos y decisiones abiertas

**Riesgos**
| Riesgo | Mitigación |
|---|---|
| Semana 1 compartida con Agendo: poco tiempo | Orden de §18; el respaldo (F8) va al final y es lo primero que se recorta a "manual solamente" si falta tiempo. |
| Límite de emails del SMTP por defecto de Supabase (pocos por hora) | Resuelto para todo el proyecto: SMTP propio en remoto (p. ej. Resend free). |
| Reloj del dispositivo desajustado rompe LWW | Supuesto de un dispositivo a la vez; documentado en README. |
| Proyecto Supabase pausado | La app no depende de él; `BackendUnavailableError` con mensaje claro. Keep-alive en Agendo. |
| `local_auth` requiere `FlutterFragmentActivity` y varía por OEM | Incluido en el andamiaje; probar en emulador con huella simulada y en un dispositivo real. |
| Tiempos de `build_runner` (Drift + freezed + riverpod) | `build.yaml` limitando `generate_for`; usar `watch` en desarrollo. |
| Políticas de Google Play sobre borrado de cuenta | No se publica en Play en el MVP (APK en GitHub). Borrado de cuenta → roadmap. |

**Supuestos**
- Un usuario usa la app en un dispositivo a la vez; el respaldo no es sincronización.
- Volumen pequeño (miles de movimientos, no millones): consultas de agregación directas en Drift sin tablas de resumen.
- Una moneda por instalación.

**Decisiones tomadas en este documento (revisar)**
1. Auth de respaldo por **código OTP de 6 dígitos** (no magic link) para evitar deep links.
2. Moneda única por instalación, lista corta de 8 monedas.
3. Respaldo **manual + automático al abrir (≥ 24 h)**; LWW por fila reforzado con trigger `keep_newest`.
4. Borrado lógico (tombstones) en todas las tablas de datos; sin purga en MVP.
5. Ids UUID generados en el cliente.
6. UI en **inglés** con infraestructura ARB lista para español.
7. `.env.example.json` en lugar de `.env.example`.
8. Mock = listas en memoria; tests de repositorio = Drift en memoria.
9. Ajustes locales en `shared_preferences`, no en Drift, y no se respaldan (salvo moneda).

**Decisiones abiertas**
- ¿Commitear el código generado (`*.g.dart`, `*.freezed.dart`)? Propuesta: **no**, se genera en CI.
- ¿Maestro en CI (emulador en GitHub Actions)? Propuesta: no en MVP; se corre local antes de cada tag.
- ¿RPC `backup_batch(jsonb)` si el upsert por lotes es lento? Medir primero.
- ¿Soporte iOS verificado? Depende de disponibilidad de dispositivo/simulador y tiempo.
- Tipografías Manrope + Inter vs. una sola familia para reducir tamaño del APK.

---

## 18. Calendario

**Semana asignada: Semana 1 (28 sep – 4 oct 2026)**, en paralelo con Agendo. Objetivo: ✅ MVP listo antes del
2026-10-11; pulido, GIF y README final en la semana posterior a la 2.

Orden sugerido de construcción (alto nivel, cada bloque deja `main` funcional):

1. **Andamiaje** (§10): `flutter create`, dependencias, lints, estructura, tema claro/oscuro, router con shell y tabs vacías, CI básico.
2. **Core**: `Money`, `YearMonth`, `DomainError`, base Drift v1, `appModeProvider`.
3. **Categorías** (+ seed de categorías por defecto) y **onboarding** (Start fresh + moneda).
4. **Movimientos**: repositorio Drift + mock, lista por mes con filtros, formulario.
5. **Presupuestos**: repositorio, `GetBudgetProgress`, copiar mes anterior.
6. **Dashboard**: `GetMonthSummary`, `GetMonthlyTrend`, gráficas fl_chart.
7. **Modo demo**: `DemoDataset` + banner + *Explore demo* (desde aquí la app es demostrable sin backend).
8. **Ajustes, bloqueo biométrico y exportar CSV**.
9. **Respaldo**: migración Supabase + RLS + triggers + pgTAP, Auth OTP, backup/restore.
10. **Cierre**: estados de UI faltantes, tests, flujos Maestro, ícono y splash, workflow de release, README y tag `v1.0.0`.
