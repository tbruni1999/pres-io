# Esquema de guardado — versión 5

Archivo JSON UTF-8 en `user://saves/<slot>.json`. Slots usados: `manual_1` (Esc → Guardar) y
`autosave` (al cerrar cada jornada). Ajustes en `user://settings.cfg`, fuera de las partidas.

## Escritura
1. Instantánea del estado al terminar una transacción (todo corre en el hilo principal).
2. Se escribe `<slot>.json.tmp`, se vuelve a leer y se valida completo.
3. Si existe, el guardado anterior se renombra a `<slot>.json.bak` (se conserva una copia).
4. El temporal se renombra a `<slot>.json`. Si falla, se intenta restaurar el `.bak`.

No se afirma atomicidad absoluta: depende de que `rename` sea atómico en el sistema de archivos,
lo que **no se probó en Windows**. Fallas de permisos o disco devuelven un mensaje y no reemplazan
el guardado anterior.

## Lectura
- Se valida en un `GameState` temporal; la partida activa solo se reemplaza si todo es válido.
- Si el principal está dañado y hay `.bak` válido, se carga la copia y se avisa.
- `schema_version` mayor que la soportada → "versión más nueva", no se abre (tampoco se cae al `.bak`).
- Nunca se cargan scripts, escenas ni Resources desde el archivo.

## Campos

| Campo | Tipo | Notas |
|---|---|---|
| `schema_version` | número | `5` (1 a 4 se migran al cargar, en cadena) |
| `game_version` | texto | p. ej. `0.1.0-h1` (informativo) |
| `seed` | cadena decimal int64 | semilla de la partida |
| `rng_seed`, `rng_state` | cadena decimal int64 | generador administrativo; se restaura exacto |
| `tick` | cadena decimal ≥ 0 | pasos administrativos desde el inicio. Día = tick / ticks_per_day + 1 |
| `ticks_per_day` | número entero | 360 en H1 |
| `office` | texto | cargo actual (`community_organizer`) |
| `settlement` | objeto | `population`, `base_water_capacity` (enteros) |
| `treasury.opening_cents` / `cash_cents` | cadena decimal | centésimos de UC |
| `treasury.next_entry_id` | número entero | |
| `treasury.ledger[]` | lista | `id`, `day`, `tick` (cadena), `kind` (`payment`), `origin`, `reason_key`, `amount_cents` (cadena), `operation_key` |
| `projects[]` | lista | `id`, `site_id`, `status` (`available`/`under_construction`/`completed`), `paid_cents` (cadena), `approved_tick` (cadena, −1 si no), `approved_day`, `completion_day`, `completed_day`, `operational_from_day`, `operation_key` |
| `applied_operations[]` | lista | `key`, `tick` (cadena): operaciones ya aplicadas |
| `facts[]` | lista | `subject` (`player`, `neighbor_rosa`), `facts` (lista de textos) |
| `player_state` | objeto | billetera (`opening_cents`, `wallet_cents`, `earned_total_cents`, `spent_total_cents`, cadenas), `hunger_bp`, `thirst_bp` (0–10000), `bag` [{`id`, `count`}], `tools` [ids], `tool_wear` [{`id`, `uses`}] (usos que le quedan a cada herramienta que se gasta), `faint_count`, `donated_total_cents`, `fish_caught_total` y contadores del día |
| `camp` | objeto | `wood`, `buildings` [ids], `passes` [{`id`, `merchant`, `start`, `status` (scheduled/passing/stopped/queued/leaving/gone), `stop_tick`, `leave_tick`, `bought`, `x`, `v` (posición y velocidad en metros, números), `visited`}] (ticks en cadena), `next_pass_id`, `branches_taken` [ids], `trees_cut` [{`tree`, `day`}], `smoker_items` [{`id`, `count`}] (crudo cargado), `smoker_ready_tick` (cadena, −1 = vacío), `merchant_visits` [{`id`, `count`}] (capítulo de cada historia), `weather` (sun/cloudy/wind/rain), `rain_start`, `rain_end` (cadenas, −1 = no llueve), `last_rain_day`, `fire_until` (cadena, −1 = apagado), `storage` [{`id`, `count`}] (acopio de materiales), `longline_items` [{`id`, `count`}] (espinel), `craving` ({`merchant`, `item`} o vacío), `night_thread` (capítulo de las luces del lago), `neighbors` [{`id`, `spot` ("" = sin lugar todavía), `since`, `talked_day`, `ep`}] |
| `reports[]` | lista | informes de cierre (últimos 30); dinero en cadenas; incluye la jornada del personaje (ganado, gastado, pescado, podrido, desmayo, `slept_outside`) y `events` [{`key`, `n`}] (lo que pasó antes de dormir y al cerrar) |
| `player` | objeto o null | `position` [x, y, z], `yaw` (rad), `pitch` (grados). Fuera del mapa → punto inicial |

## Validaciones de relación
- Caja = fondo inicial + ingresos − pagos del libro.
- Cada obra aprobada tiene su clave en `applied_operations` y un pago igual a su costo en el libro.
- Fechas coherentes con el plazo; no hay obras vencidas sin completar ni informes de días abiertos.
- Todos los proyectos del contenido están presentes y no hay desconocidos.

## Migración 1 → 2
Los guardados de H1 (escritorio y caja) conservan calendario (incluida su jornada de 360 pasos),
fondo, obras, hechos e informes. Se agrega un personaje inicial y un campamento vacío; la agenda
de comerciantes se arma en el próximo cierre.

## Migración 2 → 3
Se agrega el ahumadero vacío (`smoker_items` = [], `smoker_ready_tick` = "-1") y `slept_outside` = false en los informes.

## Migración 3 → 4
Cada pasada recibe su posición calculada con la fórmula vieja, `visited` = false y `merchant_visits` vacío.
Quien venía jugando conserva su choza (`shack` se agrega a las construcciones: el refugio inicial ahora es una carpa).

## Migración 4 → 5
Clima de sol sin lluvia, fogón apagado (hay que echarle leña), acopio, espinel, antojo, misterio y vecinos vacíos;
cada herramienta que se gasta arranca con todos sus usos; los informes reciben `events` = [].

## Fixtures
- `tests/fixtures/save_v1_day2.json`: generado con el código de H1. Histórico, no se regenera.
- `tests/fixtures/save_v2_day3.json`: generado con el código de "Choza y lago". Histórico.
- `tests/fixtures/save_v3_day2.json`: generado con el código de "noche y ahumadero". Histórico.
- `tests/fixtures/save_v4_day2.json`: en carpa, un comerciante parado y otro en fila. Histórico.
- `tests/fixtures/save_v5_day3.json`: generado con `tools/make_fixture.gd` (Beto con carpa, espinel, cemento en el acopio, informe con eventos de noche).

## Validaciones del personaje y el campamento
- Billetera = inicial + ganado − gastado.
- Ahumadero: si tiene carga, tiene hora de listo (y viceversa); solo se carga lo que se puede ahumar.
- Lluvia: inicio y fin juntos (o ninguno) y fin ≥ inicio. Acopio solo con materiales; espinel solo con pescado.
- Desgaste: solo de herramientas que se tienen, y toda herramienta que se gasta tiene su desgaste.
- Vecinos: ids y lugares conocidos.
- Objetos, herramientas, construcciones y comerciantes deben existir en el contenido.
