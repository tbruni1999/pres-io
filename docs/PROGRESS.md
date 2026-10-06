# Progreso

Documento de continuidad: qué funciona, qué se probó, qué falta y qué sigue.

## Estado actual: H0 + H1 completos (5-6 de octubre de 2026)

### Qué se puede hacer
1. Aparecer junto a la oficina comunitaria y recorrer el asentamiento (plaza, pozo, almacén
   cerrado, 12 viviendas, calle con postes y cables, acceso sur cortado).
2. Hablar con **Rosa Benítez** (vecina referente). Explica la falta de agua; recuerda si escuchaste
   el pedido y si prometiste ocuparte, y cambia lo que dice según el estado del pozo.
3. Inspeccionar el pozo: capacidad (20 personas por jornada), demanda (60) y cobertura (33 %).
4. En el escritorio de la oficina: caja y disponible, movimientos, ficha de la obra (costo
   3.200 UC, plazo, beneficio 20 → 60 personas, caja después de aprobar) y aprobación con confirmación.
5. Aprobar: se descuenta una sola vez y aparece la obra en el mapa (andamios, materiales, cinta y
   Don Aurelio trabajando).
6. Cerrar la jornada desde el escritorio (o esperar los 6 minutos): la obra se completa, el pozo
   cambia a reparado (techo, tanque, canilla, bidones llenos) y Rosa aparece con el balde lleno.
7. Informe de cierre: caja al empezar, ingresos (0), pago de la obra, caja al cerrar, personas
   abastecidas ese día, capacidad desde mañana y reacción de la comunidad.
8. Guardar (Esc → Guardar), cerrar, cargar: obra, saldos, día, hechos de diálogo y posición se
   conservan. Autoguardado al cerrar cada jornada.
9. Libreta (Tab) con pendientes derivados del estado y el último informe. Ajustes de sensibilidad,
   eje invertido, FOV y volúmenes. Diagnóstico F3.

### Verificado en este entorno
Entorno: contenedor Linux (kernel 6.18), Intel Xeon @ 2,1 GHz (4 vCPU), sin GPU.
Godot 4.7.2 oficial (Linux x86_64).

| Comprobación | Comando | Resultado |
|---|---|---|
| Importación | `godot --headless --path . --import` | sin errores ni advertencias |
| Pruebas de dominio | `godot --headless --path . --script tests/run_tests.gd` | **20 pruebas, 97 comprobaciones OK** |
| Prueba de humo | `godot --headless --path . res://tests/smoke_test.tscn` | **42 comprobaciones OK** |
| Render real | `xvfb-run ... godot --path . res://tools/screenshot_tour.tscn` | 18 capturas sin errores de script (OpenGL 4.5 Mesa llvmpipe, Compatibility) |
| Exportación | `--export-release "Windows Desktop"` | **falla: faltan plantillas 4.7.2** (esperado, ver README) |

Las pruebas de dominio cubren: doble aprobación cobra una vez; fondos insuficientes no alteran
nada; caja = inicial + ingresos − pagos; la capacidad cambia desde la jornada correcta (y con una
obra de plazo 2); cerrar jornada = avanzar sus pasos uno a uno; simulación sin actores; valores
cero sin divisiones inválidas; guardar/cargar idéntico incluido el RNG; cargar no repite efectos;
JSON dañado, versión futura, datos alterados y proyecto desconocido se rechazan; uso de la copia
`.bak`; una carga fallida no toca la partida actual; la pausa no avanza la economía; el reloj no
descarta pasos; diálogo según estado; fixture v1.
Se comprobó además que el runner detecta errores: al introducir a propósito un bug de doble
cobro, 10 comprobaciones fallaron y el proceso salió con código 1.

La prueba de humo usa el rayo real del jugador: enfoca a Rosa, abre el diálogo con `E`, registra
la promesa, verifica que una pared bloquea el rayo, inspecciona el pozo, usa el escritorio,
aprueba (confirmación + pago), verifica la obra visible, cierra la jornada, comprueba informe,
variante reparada y balde con agua, guarda, empieza de cero, carga y verifica reconstrucción,
saldo y posición; también Tab y Esc.

Mediciones orientativas (build de desarrollo, CPU del contenedor, no es el hardware objetivo):
paso administrativo p95 ≈ 1 µs, cierre de jornada p95 ≈ 36 µs, guardado completo p50 ≈ 1,9 ms.
Escena desde el inicio: ~333 draw calls, ~13 000 primitivas, ~880 nodos, memoria estática ~56 MB.

### No verificado (pendiente de una persona con el juego abierto)
- **Rendimiento en el hardware objetivo** (Bajo: Ryzen 5 3500U/Vega 8; Medio: Ryzen 5 3600/GTX 1650):
  NO VERIFICADO. Los ~11 FPS observados son de render por software (llvmpipe) y no dicen nada del
  hardware real. Tampoco hay medición de VRAM ni de tiempos de inicio en SSD.
- Windows: el proyecto no se ejecutó en Windows; tampoco se exportó.
- Sensación de control: sensibilidad del mouse, captura del cursor al alternar ventanas,
  colisiones al caminar por puertas y bordes, escalones del zócalo de la oficina.
- Audio: los buses y la reproducción se configuran, pero el entorno no tiene salida de sonido.
- Legibilidad en un monitor real a 720p (las capturas son de 1280 × 720 y se leen bien).
- Aviso de apagado `1 resources still in use at exit` (audio ambiente) con `--quit-after` y en la
  prueba de humo. No se reprodujo en un caso mínimo; no afecta datos. Revisar en H4 con audio real.

### Decisiones relevantes
Ver [`DECISIONS.md`](DECISIONS.md). Lo más importante para H2: plazo de obra = cierre de la jornada
`aprobación + plazo − 1`; un único autoload `Game`; comandos con clave de operación estable;
textos en CSV.

## Pendiente para H2 — economía y presupuesto
- Recaudación (base imponible 4.500 UC/jornada, tasa 5 %, rango 0–15 %) y comando `SetTaxRate`.
- Costo administrativo (80 UC/jornada) y funcionamiento del agua (40 → 60 UC/jornada).
- Sobres por período de 3 jornadas, reserva, disponible = caja − compromisos, autorización
  `floor(asignación × k / 3)`, restos mayores para el redondeo, revisión a mitad de período.
- **Cambio de modelo del agua:** la capacidad de H1 (20 → 60) pasa a ser *física*; el servicio
  efectivo dependerá de `factor_financiero`. La UI debe explicarlo y el informe distinguir capacidad
  física de agua prestada. Migración de guardado 1 → 2: agregar sobres vacíos y período actual;
  probar con el fixture v1.
- Los otros tres proyectos (acceso, mercado/taller, aula) con sus efectos y una vista de
  comparación en el escritorio.
- Pruebas: asignar/liberar no crea dinero, porcentajes exactos, estrategias de solvencia.

## Siguiente tarea concreta
Empezar H2 por `TreasuryState`: agregar ingresos por cierre (paso 2) y el pago del costo
administrativo (paso 3) con sus pruebas, sin tocar todavía la UI de sobres.
