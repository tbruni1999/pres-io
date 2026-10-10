# Progreso

Documento de continuidad: qué funciona, qué se probó, qué falta y qué sigue.
La dirección de juego actual está en [`DESIGN.md`](DESIGN.md).

## Estado actual: los tres locos en carpa (10 de octubre de 2026)

- **Salim** (vende sal, cinta aisladora y sombrilla; megáfono a la mañana) y **Raúl "Antena"** (pizarrón con el día;
  espanta a los comerciantes con la antena) se suman a Beto. Cada uno llega solo, atraído por algo, y elegís dónde va su carpa.
- **Panel de charla** para cada loco (el capítulo de hoy queda a la vista; antes era un aviso de 4 s) con la manta de Salim y el pizarrón de Raúl.
- La meta del pueblito vuelve a pedir **los tres vecinos**: ya se puede completar jugando.
- Catálogo de 10 locos más (para el pueblito) en [`LOCOS.md`](LOCOS.md).
- Sin cambio de esquema de guardado (sigue en 5): solo hay ids nuevos de vecinos y objetos.

| Comprobación | Resultado |
|---|---|
| Pruebas de dominio | **70 pruebas, 1.024 comprobaciones OK** |
| Prueba de humo | **84 comprobaciones OK** (llegan Salim y Raúl, comprar en la manta, pizarrón) |
| Capturas | recorrido completo sin errores; máximo 341 llamadas de dibujo |

## Hoja de ruta: lo que queda (relevamiento del 10 de octubre)

**Inmediato (juego)**
- Etapa del **pueblito**: hoy fundarlo solo muestra el fogón. Falta el mundo nuevo (casas rearmadas, empleos, la computadora). *Grande.*
- **Minería**: comerciante nuevo que trae el pico, picar con skillcheck, comprador de mineral, después mina automática. *Grande.*
- **Ayudantes con sueldo** (la mina): se van si no les pagás. *Mediano.*
- Prueba de **estrategias**: que la meta se alcance jugando por dos caminos en ~10 días, sin regalar plata. *Mediano.*

**UX que falta**
- Menú principal con "Continuar" (hoy siempre arranca partida nueva) y "Salir" con confirmación. *Mediano / chico.*
- Releer las historias de comerciantes y locos (un cuaderno). *Mediano.*
- Ayuda de controles en el juego; scroll en paneles largos; avisos que no se pierdan. *Chico / mediano.*
- Colisión de los vehículos. *Chico.*

**Después**
- Rosa, la colecta del pozo, confianza y ascenso a referente (el dominio ya existe, falta llevarlo al juego).
- Dilemas (doña Rosa y su "orégano"), seguridad que escala hasta el **secuestro**, ganadería, agricultura, mercados mejores,
  delegado → alcalde → región → país.

**Técnico / entrega (del brief)**
- Exportar el **.exe de Windows** (faltan plantillas 4.7.2) y probarlo, con guardado en `%APPDATA%`. *Mediano.*
- Medir **rendimiento** con el protocolo del brief en el hardware objetivo (lo tiene que correr Tomás) y perfiles de calidad Bajo/Medio. *Mediano.*
- Fusionar mallas estáticas (341 de 400 llamadas de dibujo). *Chico.*
- **Audio** del mundo: sonidos 3D de fogón, agua, lluvia, caballo, motor, perro. *Mediano.*
- Textos de errores de carga al CSV; overlay F3 con p99 y costo de simulación p95. *Chico.*

## Estado anterior: clima, noches, Beto y la meta del pueblito (10 de octubre de 2026, esquema 5)

Respuestas de Tomás a las 24 preguntas, ya implementadas (detalle en [`DESIGN.md`](DESIGN.md)):
- **Clima del día** (sol, nublado, viento, lluvia) con efectos reales y sin trabar: la lluvia dura unas horas,
  nunca dos días seguidos ni los primeros dos días. Lluvia visible (partículas) y cielo gris de a poco.
- **Fogón con leña**: se apaga solo, la lluvia lo apaga y la **lona** lo protege. Hervir y asar piden el fuego prendido.
- **Herramientas que se gastan** (caña 40, caña de fibra 120, hacha 25) y caña de rama en el fogón para no trabarse.
- **Antes de dormir siempre pasa algo**: misterio de las luces del lago (6 capítulos), 12 rarezas, botella con plata,
  regalo anónimo, el **zorro** (fuego prendido o Polizón lo espantan) y el **desconocido de traje** que se lleva leña.
- **Beto**, el primer loco: llega por el olor del primer ahumado, elegís dónde va su carpa, mantiene el fogón con tu leña,
  se come un ahumado por día y cuenta su historia en 10 charlas.
- **Espinel**: pesca solo de noche; a la mañana lo sacás manteniendo E.
- **Antojo del día** (un comerciante paga 50 % más por algo), **hallazgos** al pescar, **precios que nunca bajan**.
- **Bici** (la Chola, 220 UC): 1,5× más rápido y 25 % menos hambre y sed.
- **Meta de la etapa** en la mochila: 1.500 UC, 10 chapas (Coco), 6 bolsas de cemento (Chola), la escritura
  (final de la historia de la Chola) y 3 vecinos con carpa. Al completarla: **fogón con los vecinos**.
- **Malos días más duros**: desmayo 15 % → 30 % → … (tope 60 %), dormir afuera cuesta más.

### Bugs corregidos en esta tanda
Revisión independiente (repetición de 12 días con guardar/cargar cada día idéntica byte a byte; migraciones v1–v4 → v5 jugadas):
- La meta pedía 3 vecinos pero solo existe Beto: no se podía completar. Ahora pide los que ya pueden llegar (hoy 1; sube solo cuando lleguen los otros dos).
- El panel del fogón mostraba mal la hora de "prendido hasta" si pasaba de las 24:00 (el día siguiente arranca a las 06:00). Ahora se calcula desde el tick y dice "(mañana)".
- Partidas v4 con ahumadero no atraían a Beto hasta otra tanda: la migración marca "ya ahumó".

### Verificado en este entorno
| Comprobación | Comando | Resultado |
|---|---|---|
| Importación | `godot --headless --path . --import` | sin errores |
| Pruebas de dominio | `godot --headless --path . --script tests/run_tests.gd` | **66 pruebas, 962 comprobaciones OK** |
| Prueba de humo | `godot --headless --path . res://tests/smoke_test.tscn` | **76 comprobaciones OK** |
| Render real | `xvfb-run ... godot --path . res://tools/screenshot_tour.tscn` | 33 capturas sin errores de script (llvmpipe), incluidas lluvia, nublado, Beto y su carpa, espinel, lona y bici |

Rendimiento medido en el recorrido (render por software): máximo **341 llamadas de dibujo** y ~23.700 primitivas
por cuadro (con lona, bici, Beto, su carpa y la lluvia en pantalla). Sigue debajo del presupuesto (400 / 500.000),
pero ya está más cerca: el próximo paso de estética debería fusionar mallas estáticas del campamento.

### No verificado
- Balance real de la nueva dureza (desgaste, leña que se va, Beto comiendo ahumados): falta que Tomás lo juegue.
- La etapa del pueblito en sí: fundar el pueblito hoy muestra el fogón y queda marcado; el mundo nuevo viene después.

## Siguiente paso propuesto
1. Los otros dos locos (atraídos por el cartel y por el muelle/el perro), con sus problemas.
2. La etapa del pueblito: casas rearmadas, empleos, el comerciante del pico y la minería.
3. Fusionar mallas estáticas del campamento para bajar llamadas de dibujo.

## Estado anterior: carpa, fila de comerciantes, estética y diálogos (10 de octubre de 2026)

Novedades de esta entrega:
- **Arranque en carpa con fogatita** (la choza es una mejora construible).
- **Fila de comerciantes**: cada pasada guarda su posición; los que llegan detrás de uno parado esperan a 7,5 m.
- **Historias por entregas**: 10 capítulos por comerciante, uno por visita; el de Coco termina con el perro Polizón, que te sigue y de noche se echa junto al fuego.
- **Estética** con técnicas livianas: texturas procedurales tileables de 512 px (compresión de GPU y mipmaps), mapeo triplanar
  (sin costuras en primitivas), shader de suelo que mezcla tierra y pasto con una máscara, shader de agua con normales en movimiento
  y fresnel, pasto y juncos con MultiMesh por zonas (sin sombras, con distancia máxima), glow suave, ajuste de contraste y saturación,
  y parpadeo de la fogata.
- Medido en el recorrido de capturas (render por software): máximo **256 llamadas de dibujo** y **~21.000 primitivas** por cuadro
  (presupuesto del brief: 400 y 500.000). No hizo falta agrupar mallas estáticas: el número ya está por debajo del objetivo.

## Estado anterior: "Choza y lago" + noche y ahumadero (7 de octubre de 2026)

Cambio de dirección pedido por Tomás después de probar H1: empezar sin nada, muy manual y grindero,
con NPC graciosos. El H1 anterior (asentamiento, escritorio, caja) quedó en el historial de Git
(commit `78c7091`); sus partidas se migran al esquema nuevo.

### Qué se puede hacer
1. Despertar en la choza. Hambre y sed bajan todo el tiempo (barras abajo a la izquierda).
2. Pescar en la orilla: esperar el pique y acertar el **skillcheck** (la tararira pide dos seguidos).
   Centro de la zona = "perfecto" (dos pescados). Mochila de 6.
3. Tomar agua del lago (mantener E): a veces cae mal.
4. Comerciantes por el camino: **Don Ramiro** (carreta con Turbo), **la Chola** (Fitito) y,
   con cartel, **Coco** (camión). Hay que salir y hacerles señas a tiempo; si no, pasan de largo.
   Cada uno compra y vende distinto y tiene sus frases.
5. Juntar ramas (1 por montón por día) y, con hacha, talar árboles con skillcheck (3 de madera, vuelven a crecer).
6. Construir martillando: **fogón** (3 madera: hervir agua y asar pescado, cada uso gasta 1 madera),
   **cartel** (4 madera + 40 UC: los comerciantes paran solos y aparece Coco), **muelle** (20 madera + 150 UC: más tarariras).
7. El pescado se pudre al terminar el día. Desmayo con castigo creciente. Dormir termina el día.
8. Mochila (Tab), un objetivo a la vista arriba, guardar/cargar y autoguardado al cerrar cada día.
9. **Noche**: reloj en el HUD (06:00 a 24:00), atardecer cálido, noche con luna, farol en la choza y
   el fogón que ilumina. De noche no pica ni pasan comerciantes. Si no te acostás, dormís afuera.
10. **Ahumadero** (10 madera + 120 UC): cargás hasta 8 pescados con 1 madera, sale humo de la chimenea
    y a las ~3 h de juego sacás pescado ahumado que no se pudre y vale casi el doble.

### Verificado en este entorno
Contenedor Linux, Intel Xeon 2,1 GHz (4 vCPU), sin GPU. Godot 4.7.2 oficial.

| Comprobación | Comando | Resultado |
|---|---|---|
| Importación | `godot --headless --path . --import` | sin errores |
| Pruebas de dominio | `godot --headless --path . --script tests/run_tests.gd` | **48 pruebas, 446 comprobaciones OK** |
| Prueba de humo | `godot --headless --path . res://tests/smoke_test.tscn` | **58 comprobaciones OK** |
| Render real | `xvfb-run ... godot --path . res://tools/screenshot_tour.tscn` | 26 capturas sin errores de script (llvmpipe), incluidas atardecer y noche |

Las pruebas de dominio cubren además de lo de H1: hambre/sed, cansancio, desmayo con castigo creciente,
dormir sin hambre, pesca determinista por semilla y límite de mochila, agenda de comerciantes,
señas a tiempo y "te lo perdiste", venta con tope por parada, cartel que los hace parar y trae a Coco,
pescado podrido, agua del lago (aprox. 1 de cada 3 cae mal), fogón, ramas, tala, construcción sin
materiales sin cambios, colecta comunitaria, migración de guardado v1 → v2 y fixture v2.

La prueba de humo juega con las teclas reales: mira la cama, pesca con skillcheck (acierto y error),
toma agua manteniendo E, junta ramas, le hace señas a Ramiro y le vende, martilla el fogón
(con un error), hierve agua, guarda/carga, se desmaya de sed y despierta en la choza, duerme, Tab y Esc.

### No verificado
- Rendimiento en el hardware objetivo: NO VERIFICADO (sin GPU real).
- Balance: si el grind se siente bien o pesado. Números en `data/` para ajustar sin tocar código.
- Sensación del skillcheck con un humano (velocidades y anchos de zona).
- Los vehículos no tienen colisión: se los puede atravesar.
- Windows y exportación (faltan plantillas, ver README).
- Aviso de audio al cerrar el proceso (`1 resources still in use at exit`), sin efecto en datos.

### Contenido guardado para más adelante
Escenas del pueblo (casas, pozo con tres estados, oficina, almacén, Rosa), la colecta comunitaria
(dominio y pruebas) y el diálogo de Rosa. Vuelven cuando lleguen vecinos.

### Siguiente paso que se había propuesto entonces
1. Elegir cómo llega el primer vecino (opciones presentadas a Tomás).
2. Ajustar balance con lo que Tomás sienta jugando (velocidades de skillcheck, precios, sed, duración de la noche).
3. El comerciante nuevo que trae el pico → minería con skillcheck y comprador de mineral.
4. Primer ayudante con sueldo por día.
