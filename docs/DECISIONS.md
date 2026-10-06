# Decisiones registradas

Cada decisión indica qué se eligió y por qué. Se revisan cuando una prueba lo justifique.

## Cambio de dirección "Choza y lago" (6 de octubre)
- El juego arranca sin pueblo ni presupuesto (ver `DESIGN.md`). La caja comunitaria, el pozo y
  Rosa quedan en el dominio para cuando lleguen vecinos; la UI del escritorio se quitó.
- **Billetera del personaje separada del fondo comunitario** (`PlayerState` vs `TreasuryState`).
  Invariante: billetera = inicial + ganado − gastado (se valida al cargar).
- **Comerciantes**: la agenda del día sale del generador de la partida al cerrar cada jornada.
  La posición del vehículo se calcula con el tick (`Merchants.position_x`), así se reconstruye al cargar.
  Las señas se validan en el dominio por posición sobre el camino; la cercanía del jugador la mira la presentación.
- **Skillcheck**: la presentación decide acierto/error (es habilidad del jugador); el dominio decide
  qué pescado pica y cuánto tarda con el generador de la partida. Dónde cae la zona es cosmético.
- **Actividades vs paneles**: pescar, martillar, talar y mantener E frenan al jugador pero el tiempo corre.
  Los paneles (comerciar, fogón, mochila, informe, pausa) pausan el reloj.
- **Dormir y desmayo** usan la misma función de pasos que el reloj, con "descanso": hambre y sed no bajan.
- **Jornada de 8 minutos** (480 pasos). Las partidas viejas conservan su duración guardada.
- Guardado: esquema 2 con migración real desde el 1 (se agregan personaje y campamento).
  El pago de una obra se valida contra el libro de movimientos, no contra el costo actual del balance,
  para que ajustar precios no invalide partidas.

## Motor y entorno
- **Godot 4.7.2 estable**, verificado con `--version` (`4.7.2.stable.official.ed1daf0bf`).
  Ejecutable oficial de Linux usado en el entorno de desarrollo; checksum SHA-512 contrastado con
  `SHA512-SUMS.txt` del release.
- **Renderer Compatibility** según el brief. No se usan SDFGI, SSR, niebla volumétrica ni lightmaps.
  Iluminación: un sol direccional fijo (sombras a 50 m, 2 divisiones), ambiente de color,
  tonemap filmic, una luz omni sin sombras dentro de la oficina.

## Arquitectura (tres capas)
- **Dominio** (`scripts/domain`): clases `RefCounted` y funciones estáticas de `Simulation`.
  No usa el SceneTree ni la hora del sistema; las pruebas lo ejecutan sin escenas.
- **Aplicación** (`scripts/application`): un único autoload, `Game` (`game_session.gd`), que ejecuta
  comandos, avanza el reloj, guarda/carga y emite señales (`treasury_changed`,
  `project_state_changed`, `service_changed`, `day_closed`, `state_replaced`, `facts_changed`).
- **Presentación** (`scripts/presentation`): escenas, actores y UI. Solo leen el estado y emiten
  comandos; nunca modifican dinero.
- Las definiciones (`BalanceConfig`, `ProjectDefinition`, `GameContent`) son Resources `.tres` de
  solo lectura por convención. El progreso vive en `GameState` / `ProjectState`.

## Comandos e idempotencia
- Aprobar una obra usa la clave estable `approve_project:<id>`. Si llega dos veces, la segunda
  devuelve `duplicate` sin efectos. Otra clave sobre la misma obra se rechaza por estado.
- Orden: validar todo (autoridad, estado, lugar libre, fondos) → aplicar sin puntos de falla →
  registrar clave → señal. Un rechazo no deja mutaciones (probado comparando el JSON completo).
- Autoridad mínima: el estado guarda el cargo (`community_organizer`) y cada proyecto declara qué
  cargo puede aprobarlo. Se valida en el dominio, no ocultando botones.
- El botón de aprobar pide confirmación (dos clics) mostrando el costo; es comodidad de UI, la
  protección real es la del dominio.

## Tiempo
- 1 paso administrativo = 1 s de simulación; 360 pasos por jornada (6 min a velocidad normal).
- `SimClock` acumula tiempo real y ejecuta como máximo 4 pasos por fotograma. Lo que excede queda
  pendiente para los fotogramas siguientes (nunca se descarta) y se cuenta como atraso (F3).
- "Cerrar jornada" ejecuta los pasos que faltan con la misma función `Simulation.step()`; la
  prueba `test_advance_day_equals_stepping` compara ambos caminos.
- Diálogos, escritorio, libreta y pausa pausan el reloj administrativo. Los avisos no.
- **Plazo de obra:** una obra con plazo D aprobada durante la jornada N se completa en el cierre
  de la jornada N + D − 1 y opera desde la jornada siguiente. Para el pozo (plazo 1): aprobás el
  día 1, se completa al cerrar el día 1, el agua sube a 60 desde el día 2. Se eligió así para que
  la primera sesión muestre el resultado con un solo cierre. Consecuencia conocida: aprobar al final
  del día da el mismo plazo que al principio; si el balance de H2 lo exige se puede pasar a contar
  jornadas completas.
- Orden de cierre implementado en H1: instantánea → movimientos del día → servicio prestado →
  obras que vencen → informe y reacción → la fecha avanza. Ingresos y funcionamiento (pasos 2–3 del
  brief) se agregan en H2 dentro de la misma función.

## Economía de H1
- Dinero en enteros de centésimos (`10000 UC` = `1000000`). Porcentajes en puntos básicos.
- Tesorería: fondo inicial 10.000 UC y pagos de obra. No hay impuestos ni funcionamiento todavía,
  y la UI no los menciona. Invariante comprobado: caja = inicial + ingresos − pagos.
- Agua: capacidad física 20 → 60 personas; demanda = población (60). Cobertura en puntos básicos
  con demanda cero = 100 %. En H1 la capacidad física es la efectiva; en H2 pasará a depender del
  financiamiento (ver PROGRESS).
- La reacción de la comunidad es un texto elegido a partir del estado (obra terminada hoy, obra en
  curso o nivel de cobertura). No hay número de confianza todavía: no se muestra un indicador falso.

## Mundo y arte
- Mapa jugable de ~120 × 120 m dentro de lomas con colisión (el brief prevé 220 × 220 para la
  versión completa). 12 viviendas exteriores, oficina con interior, almacén exterior, pozo, plaza,
  calle principal y acceso sur cortado.
- Geometría con un **kit de piezas** (`KitShape`, script `@tool`): cajas, cilindros, conos y esferas
  con material compartido y colisión simple opcional, editables desde el inspector. Es bloqueo
  provisional; se reemplaza por glTF sin tocar reglas. Las piezas idénticas comparten malla.
- El pozo tiene tres variantes (deteriorado / en obra / reparado) que se eligen a partir del
  estado; se reconstruyen al cargar. La colisión del lugar es la misma en las tres.
- Carteles con `Label3D` y textos del CSV. Cables con líneas sin sombra.

## Interacción
- Rayo único desde la cámara de 2,5 m con máscara mundo + interactuables. Si lo primero que toca es
  una pared, no hay objetivo (probado en la prueba de humo).
- Capas de física: 1 `world`, 2 `player`, 3 `interactable`.

## Guardado
- JSON versionado (`schema_version` 1) en `user://saves`. Enteros grandes como cadenas decimales.
  Detalle en `SAVE_SCHEMA.md`.

## Textos
- Traducción nativa de Godot con `data/text/strings.csv` (clave, `es`). Locale de respaldo `es`.
  El dominio devuelve mensajes ya traducidos con parámetros (`Texts.t`).

## Audio
- Tres buses: Master, Ambiente, Efectos. Sonidos provisionales generados por
  `tools/generate_audio.py`: viento en bucle, pasos y confirmación/error de UI.
