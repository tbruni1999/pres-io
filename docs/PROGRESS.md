# Progreso

Documento de continuidad: qué funciona, qué se probó, qué falta y qué sigue.
La dirección de juego actual está en [`DESIGN.md`](DESIGN.md).

## Estado actual: "Choza y lago" (6 de octubre de 2026)

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

### Verificado en este entorno
Contenedor Linux, Intel Xeon 2,1 GHz (4 vCPU), sin GPU. Godot 4.7.2 oficial.

| Comprobación | Comando | Resultado |
|---|---|---|
| Importación | `godot --headless --path . --import` | sin errores |
| Pruebas de dominio | `godot --headless --path . --script tests/run_tests.gd` | **33 pruebas, 191 comprobaciones OK** |
| Prueba de humo | `godot --headless --path . res://tests/smoke_test.tscn` | **44 comprobaciones OK** |
| Render real | `xvfb-run ... godot --path . res://tools/screenshot_tour.tscn` | 21 capturas sin errores de script (llvmpipe) |

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

## Siguiente paso propuesto
1. Ajustar balance con lo que Tomás sienta jugando (velocidades de skillcheck, precios, sed).
2. Ahumadero (el pescado ahumado no se pudre y vale más).
3. Minería: pico, mina con skillcheck, comprador de mineral.
4. Primer ayudante con sueldo por día.
