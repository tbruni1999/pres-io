# Progresión: propuestas medidas (11 de octubre de 2026)

Relevamiento con agentes de solo lectura y un bot que juega 40 días (20 semillas por política).
**Ninguna de estas propuestas está aplicada.** Son cambios de balance y los decide Tomás.
Los números son del bot: sirven para ordenar las palancas, no para fijar valores finales (el bot compra poco y no usa la bici ni la sal de Salim).

Referencia actual: fundación mediana **día 38** (10 de 20 corridas).

## Propuestas de progresión

### Paquete para fundar hacia el día 10: pique, re-picada, meta, espinel y Raúl
- **Cuándo:** Día 1 (pique y re-picada); días 2-4 (espinel y luces); fundación prevista entre el día 11 y el 12.
- **Qué cambia:** Aplicar juntas las cinco palancas de abajo: pique de la caña básica 4-8 s; re-picada de 3 s tras un skillcheck fallido; meta de 500 UC con 5 chapas y 3 de cemento; espinel antes que el ahumadero y la lona; luces del lago forzadas en las noches 2 y 4. Orden: primero los datos (pique, meta, orden de edificios), después la re-picada y las luces forzadas, y recién después volver a medir con el bot. Complementos que siguen mejorando el resultado: la conservadora que guarda pescado y la orilla a 8 m del camino.
- **Números:** Bot, 20 semillas x 40 días, política meta: hoy la fundación es mediana día 38 (10/20 corridas). Paquete de las cinco: 20/20, mediana día 12; ganado al día 10: 418 -> 971 UC. Con meta de 400 UC: mediana día 11. Con la conservadora de 6 pescados o la orilla a 2 s: mediana día 11 (20/20). No conviene (medido): 5 pasadas por día (3/20); tope de 2 o 4 de leña por día a Beto (4/20 y 8/20); bolsa de 15 sin conservar (0/20 y 256 pescados podridos en 40 días); ahumadero de 12 (sin cambio: la mochila de 6 no llena la tanda); hacha a 60 UC, leña de 90 pasos y árboles que rebrotan en 1 día (la mediana se mueve un día o nada). Salidas: /tmp/claude-0/-home-user-pres-io/023d7f98-0ef0-5c60-82ce-c9c250822682/scratchpad/relevo/out_v2.txt, out_v3.txt, out_v4.txt, out_v5.txt y out_v6c.txt (script bot_v2.gd). Limitación: el bot atiende cada pasada, no compra bici ni sal de Salim y sobreestima el ingreso; sirve para ordenar palancas, no para fijar valores finales.
- **Por qué:** Cada palanca ataca un cuello que el bot midió: la espera del pique (la más grande), la plata de la meta (la segunda), un vecino que llega tarde y el orden de la cadena. Respeta las reglas: nadie cobra sueldo, no hay fiado y los problemas de cada loco siguen siendo con el jugador. Advertencia de diseño: el ingreso de los primeros 10 días más que se duplica; si el grind se siente poco, el ajuste fino va en la meta (400-500 UC), no en la espera.
- **Archivos:** /home/user/pres-io/data/items/rod_basic.tres; /home/user/pres-io/scripts/presentation/ui/activities.gd; /home/user/pres-io/scripts/domain/balance_config.gd (líneas 116-117); /home/user/pres-io/data/buildings/longline.tres, smokehouse.tres y tarp.tres (campo order); /home/user/pres-io/scripts/domain/nights.gd (before_bed)
- **Esfuerzo:** mediano

### Caña de bambú: pique de 4 a 8 s (hoy 7 a 15 s) · *marcada por el jurado para hacer ya*
- **Cuándo:** Desde el día 1; se nota en las primeras pasadas.
- **Qué cambia:** Bajar bite_min_s a 4.0 y bite_max_s a 8.0 en la caña básica. La caña de fibra queda en 4-9. El skillcheck no cambia.
- **Números:** Espera del pique 7-15 s -> 4-8 s. Bot (política meta): fundación mediana día 38 -> 27 (10/20 -> 20/20); ganado al día 10: 418 -> 719 UC; pescados en 10 días: 125 -> 170. Si se siente demasiado rápido, 5-9 s no está medido.
- **Por qué:** La espera era el 85-90 % del tiempo de pesca: de unos 2.080 s en 10 días, unos 1.800 s no hacían nada. El grind se mantiene (hay que pescar mucho igual), pero desaparece el tiempo muerto.
- **Archivos:** /home/user/pres-io/data/items/rod_basic.tres (bite_min_s, bite_max_s)
- **Esfuerzo:** chico

### Si el pez se escapa, vuelve a picar en 3 s (sin recastear)
- **Cuándo:** Desde el día 1, con cualquier caña.
- **Qué cambia:** Un skillcheck fallido no reinicia la espera completa: la línea sigue en el agua y el mismo pez pica de nuevo a los 3 s, sin gastar uso de la caña. Aviso nuevo: 'Se escapó, pero volvió a morder. Esa tararira te tiene ganas.'
- **Números:** Hoy: descanso de 1,2 s y nueva espera de 7-15 s tras cada escape (alrededor de 1 de cada 4 tiradas). Propuesta: 3 s. Bot: fundación mediana 38 -> 31 (20/20); pescados en 10 días 125 -> 151; cañas rotas en 10 días 4 -> 3.
- **Por qué:** El escape ya cuesta el pescado; un segundo castigo de tiempo se siente injusto y aburrido. Deja al skillcheck como única habilidad, de acuerdo con 'todo lo manual es un skillcheck'.
- **Archivos:** /home/user/pres-io/scripts/presentation/ui/activities.gd (clase Fishing: en _on_check, rama MISS, en lugar de _rest() pasar a 'wait' con _timer = 3.0 y sin llamar a _cast_line); /home/user/pres-io/data/text/strings.csv (FISH_ESCAPED, línea 42)
- **Esfuerzo:** chico

### Meta del pueblito: 500 UC, 5 chapas y 3 de cemento (hoy 1.500, 10 y 6) · *marcada por el jurado para hacer ya*
- **Cuándo:** Meta de la etapa carpa (fundación hacia el día 10-12).
- **Qué cambia:** Cambiar los valores por defecto: goal_money_uc = 500 y goal_materials = {'sheet_metal': 5, 'cement': 3}. La escritura y los 3 vecinos no cambian.
- **Números:** Plata: 1.500 -> 500 UC. Materiales: 10 chapas (250 UC) y 6 cementos (240 UC) -> 5 (125 UC) y 3 (120 UC). Bot (referencia): 10/20 con mediana día 38 -> 15/20 con mediana día 21; óptimo: día 26 -> 17. Desmayo del 15 %: 225 UC -> 75 UC.
- **Por qué:** El cuello de la meta es la plata en caja: hoy la referencia llega a 1.500 UC recién el día 38. Con 500 el salto cae en la ventana de 10 días. No toca crédito ni sueldos.
- **Archivos:** /home/user/pres-io/scripts/domain/balance_config.gd (líneas 116-117: goal_money_uc y goal_materials; data/balance.tres no los pisa, así que manda el default); /home/user/pres-io/docs/DESIGN.md y /home/user/pres-io/docs/PROGRESS.md (cifras de la meta)
- **Esfuerzo:** chico

### Cadena de objetivos: espinel antes que el ahumadero y la lona · *marcada por el jurado para hacer ya*
- **Cuándo:** Después del cartel (día 2-4).
- **Qué cambia:** Cambiar el campo order de los edificios: espinel 5 -> 3, ahumadero 4 -> 5, lona 3 -> 4. La cadena queda cartel -> espinel -> ahumadero -> lona (sorted_buildings ordena por order).
- **Números:** Espinel: 6 madera + 60 UC; da 2-4 pescados por noche (15 % grandes). Ahumadero: 10 madera + 120 UC. Bot: fundación mediana 38 -> 36 (19/20 corridas).
- **Por qué:** El espinel es el primer ingreso que no pide tiempo del jugador y cuesta la mitad que el ahumadero. Ordenar de lo barato y automático a lo caro es una decisión fácil.
- **Archivos:** /home/user/pres-io/data/buildings/longline.tres (order 5 -> 3); /home/user/pres-io/data/buildings/smokehouse.tres (order 4 -> 5); /home/user/pres-io/data/buildings/tarp.tres (order 3 -> 4); /home/user/pres-io/scripts/domain/game_content.gd (sorted_buildings)
- **Esfuerzo:** chico

### Raúl llega seguro: luces del lago en la noche 2 y en la noche 4 · *marcada por el jurado para hacer ya*
- **Cuándo:** Noche 2 (primera luz) y noche 4 (segunda luz); Raúl el día 5.
- **Qué cambia:** En Nights.before_bed: si es el día 2 y todavía no hubo luces, el evento es 'lights' (sin sorteo); si es el día 4 y hubo una sola, también. Así el hecho lake_lights_2 queda hecho la noche 4 y Raúl llega la mañana del día 5 (check_arrivals al cerrar el día 4).
- **Números:** Hoy las luces salen con peso 4 de unos 22 (18-21 % por noche). Bot (emulado con el hecho puesto el día 4): vecinos a tiempo para el día 10 de 8/20 -> 17/20. Con el paquete: 20/20.
- **Por qué:** Raúl cuenta para la meta y hoy depende del sorteo. Con una causa visible el jugador sabe por qué falta. Raúl no cobra, y sus problemas (escanea a los comerciantes) siguen siendo con el jugador.
- **Archivos:** /home/user/pres-io/scripts/domain/nights.gd (before_bed, líneas 13-27)
- **Esfuerzo:** chico

### Conservadora que guarda 3 pescados crudos de una noche a la otra (100 UC)
- **Cuándo:** Disponible desde el día 3-4, cuando hay plata después del cartel.
- **Qué cambia:** La conservadora deja de ser solo +9 de mochila: al cerrar el día, hasta 3 pescados crudos que tengas no se pudren (ocupan lugar y la mochila le suma +3). Precio en la Chola: 250 -> 100 UC. Texto de la mochila: 'Lo que no está en la conservadora se pudre al terminar el día.' Versión mayor: 6 pescados.
- **Números:** Bot (emulado desde el día 1, sin costo): meta 10/20 (mediana día 38) -> 20/20 (mediana día 31); pescados podridos en 40 días 144 -> 53; ganado al día 10: 418 -> 559 UC. Con 6 pescados: mediana día 29 y cero podridos. Ojo: la conservadora actual (+9 de mochila, sin conservar) no sirve: una bolsa de 15 sin conservar da 256 podridos y 0/20 de meta.
- **Por qué:** Hoy el pescado que sobra después de la última pasada (que llega a la choza entre las 14:45 y las 16:20) se pierde. Tres pescados guardados valen unos 20 UC por día: se paga en unos 5 días. Es compra al contado, sin fiado. Como ocupa lugar en la mochila, el jugador decide cuánto pescar y lo ve.
- **Archivos:** /home/user/pres-io/data/items/cooler.tres (bag_bonus 9 -> 3; campo nuevo keep_raw = 3); /home/user/pres-io/scripts/domain/item_definition.gd (campo nuevo); /home/user/pres-io/scripts/domain/simulation.gd (_close_day, paso 6b, líneas 142-170: no tirar hasta keep_raw crudos si hay conservadora); /home/user/pres-io/data/merchants/chola.tres (sells cooler 250 -> 100); /home/user/pres-io/data/text/strings.csv (BAG_ROTS, línea 291)
- **Esfuerzo:** mediano

### Coco pasa todos los días con el cartel, como última pasada
- **Cuándo:** Desde que hay cartel (día 2-3).
- **Qué cambia:** Con el cartel construido, Merchants.plan_day reserva la última pasada del día para Coco (el camión). Coco ya requiere el cartel: cambia solo la agenda, no sus precios. Frase nueva al llegar: 'Coco llegó a la tarde, puntual como el cartel.'
- **Números:** Proxy medido (Coco con peso 6 en vez de 2, es decir unas 55 % de las pasadas en lugar de 29 %): meta 10/20 -> 15/20; mediana día 38 -> 34; ganado al día 10: 418 -> 458 UC. Coco paga pescado grande 18 (Chola 15, Ramiro 10), vende chapas a 25 y compra hasta 25 por parada. Con una visita diaria, su historia (10 capítulos y el perro) cierra alrededor del día 10: fecha fija.
- **Por qué:** La última pasada llega entre las 14:45 y las 16:20: Coco es el comprador que se lleva el pescado de la tarde. Es una regla que el jugador puede planear. Coco vende; no cobra sueldo.
- **Archivos:** /home/user/pres-io/scripts/domain/merchants.gd (plan_day y _pick_merchant, líneas 27-53 y 97-110); /home/user/pres-io/data/merchants/coco.tres (sin cambio); /home/user/pres-io/data/text/strings.csv (frases de Coco al llegar)
- **Esfuerzo:** mediano

### Orilla de pesca a unos 8 m del camino (caminar 2 s, no 6)
- **Cuándo:** Desde el día 1.
- **Qué cambia:** Acercar el punto de pesca 'shore' y el borde del lago en la escena para que el lago quede a unos 8 m del camino. La velocidad del personaje (4 m/s) no cambia.
- **Números:** Caminata lago-camino de 6 s (24 m) -> 2 s (8 m): cada pasada pasa de 12 s de ida y vuelta a 4 s. Bot: meta 10/20 -> 19/20; mediana día 38 -> 34; ganado al día 10: 418 -> 484 UC; pescados en 40 días: 509 -> 573. Con el paquete: mediana 12 -> 11.
- **Por qué:** Mientras pescás no podés moverte (el input se bloquea al empezar la pesca). Con el lago lejos, una seña se pierde: cancelás, caminás 6 s y llegás tarde. No conviene subir a 5 pasadas por día: el bot empeora (3/20, y con el lago cerca 7/20).
- **Archivos:** /home/user/pres-io/scenes/world/lakeside.tscn (punto de pesca 'shore' y borde del lago); /home/user/pres-io/scripts/presentation/ui/ui_root.gd (start_activity bloquea el input: sin cambio)
- **Esfuerzo:** mediano

### Mostrar la última pasada y cuánto pescado se va a pudrir
- **Cuándo:** Desde el día 1 (el aviso de salida desde el día 2, cuando hay cartel).
- **Qué cambia:** En la mochila (Tab) y en el HUD: 'Última pasada: 15:00 aprox.' y 'Si cerrás ahora se pierden 3 pescados'. Al tirar la caña, si lo que se pesca no tiene salida antes de la noche, aviso: 'Esto no tiene salida hoy: se va a pudrir.'
- **Números:** Las 4 pasadas arrancan en franjas de unos 45 min: 07:05-07:55, 09:30-10:15, 11:50-12:40 y 14:10-15:00; llegan frente a la choza entre 14:45 y 16:20 según el comerciante. De ahí a las 21:00 no hay comprador (unas 5 horas de juego). Hoy el pudrimiento es 144 de 509 pescados en 40 días (28 %, bot).
- **Por qué:** El único aviso es una línea fija ('El pescado se pudre al terminar el día'). Con la hora y la cifra, la decisión (vender, ahumar, guardar o dejar de pescar) se toma con un número, no con la sorpresa del informe.
- **Archivos:** /home/user/pres-io/scripts/domain/merchants.gd (helper nuevo: hora de la última pasada desde camp.passes); /home/user/pres-io/scripts/presentation/ui/hud.gd (línea de estado, junto a _objective); /home/user/pres-io/scripts/presentation/ui/bag_panel.gd (BAG_ROTS, línea 55); /home/user/pres-io/data/text/strings.csv (BAG_ROTS y claves nuevas)
- **Esfuerzo:** mediano

### Objetivo: la meta antes que la choza y el muelle
- **Cuándo:** Desde el cartel (día 2) hasta la fundación.
- **Qué cambia:** En Objectives.current, mostrar la meta (OBJ_GOAL con su cuenta) antes del bucle de construcciones. Choza y muelle salen de la cadena: pasan a opcionales y no bloquean la meta.
- **Números:** Choza (15 madera + 100 UC) y muelle (20 madera + 150 UC) = 250 UC y 35 madera que no cuentan para la meta. Bot que sigue la cadena al pie (política guía): meta fundada 0/20 corridas en 40 días; chapas y cemento comprados 0/20. Sin choza ni muelle (política meta): 10/20.
- **Por qué:** Un solo objetivo con su cuenta es la forma más directa de saber qué hacer. La choza, además, no tiene efecto (ver la idea de la choza).
- **Archivos:** /home/user/pres-io/scripts/presentation/ui/objectives.gd (líneas 24-28: OBJ_GOAL antes del bucle); /home/user/pres-io/scripts/domain/game_content.gd (sorted_buildings: excluir opcionales); /home/user/pres-io/data/buildings/shack.tres y dock.tres (campo nuevo optional); /home/user/pres-io/data/text/strings.csv (OBJ_SHACK, OBJ_DOCK, OBJ_GOAL)
- **Esfuerzo:** chico

### La choza hace algo (o sale de la carrera)
- **Cuándo:** Después del cartel y la lona (día 4-6), cuando se piensa en la choza.
- **Qué cambia:** Hoy la choza solo cambia la escena (camp_piece.gd) y ninguna regla la consulta. Darle una función: (a) guarda hasta 6 pescados crudos de una noche a la otra, o (b) con choza, dormir afuera resta la mitad (1.250 bp en vez de 2.500). Elegir una.
- **Números:** (a): con 6 pescados la referencia emulada queda en cero podridos (ver conservadora). (b): hoy dormir afuera resta 25 % de hambre y sed (slept_outside_loss_bp 2.500; piso 1.000).
- **Por qué:** El edificio más caro de la cadena (100 UC + 15 madera) no hace nada, y es lo que más confunde. Un efecto visible en el primer uso lo vuelve una decisión fácil.
- **Archivos:** /home/user/pres-io/scripts/domain/simulation.gd (_close_day, pasos 6b y 6c, líneas 142-188); /home/user/pres-io/scripts/domain/balance_config.gd (líneas 16-17); /home/user/pres-io/data/buildings/shack.tres; /home/user/pres-io/scripts/presentation/world/camp_piece.gd (sin cambio)
- **Esfuerzo:** mediano

### Tope de 150 UC por desmayo
- **Cuándo:** Cuando la billetera pasa de 1.000 UC (etapa 2); con la meta en 500 el 15 % son 75 UC y casi no pega.
- **Qué cambia:** La penalización sigue siendo el porcentaje de la billetera (15 %, 30 %, 45 %...), pero con tope de 150 UC por desmayo. La mochila muestra: 'El próximo te cuesta hasta 150 UC'.
- **Números:** Hoy 15 % de 1.500 UC = 225 UC; el segundo desmayo, 30 % = 450 UC. Con tope: 150 y 150. Valor inicial a calibrar.
- **Por qué:** El desmayo no debe decidir la meta por sorpresa. Sigue siendo un mal día (pierde plata y el día), pero acotado; 'un mal día pega fuerte' se mantiene.
- **Archivos:** /home/user/pres-io/scripts/domain/balance_config.gd (líneas 46-49: nuevo faint_penalty_cap_uc = 150); /home/user/pres-io/scripts/domain/simulation.gd (_faint, líneas 268-281); /home/user/pres-io/scripts/presentation/ui/bag_panel.gd (BAG_FAINTS, línea 70)
- **Esfuerzo:** chico

### Beto trae su propia leña: el fuego no baja tu madera
- **Cuándo:** Desde que llega Beto (día 6-9).
- **Qué cambia:** Beto mantiene el fogón con sus ramas: tend_fire deja de restar camp.wood. Se conserva el impuesto de un ahumado por día (su problema con vos). No poner tope a su fuego: medido, empeora. Texto nuevo: 'Beto trajo sus ramas y prendió el fuego. Tu leña quedó en paz. El ahumado, no.'
- **Números:** Hoy Beto gasta unas 2,7 madera por día (106 en 40 días, referencia): casi la mitad de lo que dan las ramas (6 por día). Bot con fuego gratis: meta 10/20 -> 15/20; mediana 38 -> 34. Tope de 2 por día: 4/20; tope de 4 por día: 8/20 (peor que hoy).
- **Por qué:** Un fuego limitado obliga a encender a mano y a dejar de hervir, y eso es tiempo perdido. Decisión de diseño a confirmar: hoy el 'problema con vos' es la leña; con esto pasa a ser el impuesto.
- **Archivos:** /home/user/pres-io/scripts/domain/neighbors.gd (tend_fire, líneas 96-103: no restar camp.wood); /home/user/pres-io/data/text/strings.csv (MSG_BETO_FIRE, línea 365)
- **Esfuerzo:** chico

### Costo por uso de las cañas: fibra a 120 UC y cinta a 10 UC por 20 usos
- **Cuándo:** (a) Desde que la Chola pasa con el cartel (día 4-8); (b) desde que llega Salim (día 3-4).
- **Qué cambia:** (a) En la Chola, caña de fibra de 300 a 120 UC; en la fila de compra mostrar el costo por tirada ('1 UC por tirada', contra 0,63 de la de bambú). (b) La cinta de Salim pasa de 20 UC por 15 usos a 10 UC por 20 usos, con el texto 'Le devuelve 20 usos a tu caña'.
- **Números:** Hoy: fibra 300 / 120 = 2,5 UC por tirada (bambú 25 / 40 = 0,63). Bot (política caña, medido con pique 7-15): fundación 4/20 (mediana día 40) con 300 -> 16/20 (mediana día 37) con 120. Cinta: hoy 20 / 15 = 1,33 UC por uso, el doble de la caña nueva; propuesta 10 / 20 = 0,50 (sin medir).
- **Por qué:** El precio por uso hace que la compra se entienda sola: cinta si la caña está casi rota, caña nueva si no. Con el pique de 4-8 la fibra gana por pescado grande (30 % contra 12 %) y durabilidad, y 120 UC la mantiene como compra real. Salim sigue al contado.
- **Archivos:** /home/user/pres-io/data/merchants/chola.tres (sells rod_good 300 -> 120); /home/user/pres-io/scripts/presentation/ui/trade_panel.gd (fila de compra, líneas 84-99); /home/user/pres-io/scripts/domain/neighbors.gd (SALIM_STOCK, línea 22: tape 20 -> 10); /home/user/pres-io/scripts/domain/balance_config.gd (línea 110: tape_uses 15 -> 20); /home/user/pres-io/data/text/strings.csv (TRADE_BUY_ROW, línea 165; SHOP_TAPE, línea 501)
- **Esfuerzo:** chico

### Ventana de seña más ancha y cuenta regresiva en el camino
- **Cuándo:** Desde el día 1.
- **Qué cambia:** Subir HAIL_DISTANCE_X de 32 a 45 m en merchant_road.gd. Marcar al comerciante que pasa con los segundos que quedan para hacerle seña ('Seña: 6 s').
- **Números:** Ventana hoy: unos 40 m (de -32 a +8 m frente a la choza) -> 53 m. Chola (6 m/s): 6,7 s -> 8,8 s; Coco (4 m/s): 10 s -> 13,2 s; Ramiro (2,6 m/s): 15,6 s -> 20,6 s. Sin medir en el bot (el bot siempre hace la seña).
- **Por qué:** La Chola cuenta para la escritura (10 visitas): cada pasada perdida por reflejos atrasa la meta. Con la cuenta visible, el reflejo se vuelve una decisión.
- **Archivos:** /home/user/pres-io/scripts/presentation/world/merchant_road.gd (constante HAIL_DISTANCE_X; condición de seña); /home/user/pres-io/scripts/presentation/ui/hud.gd (o etiqueta sobre el vehículo, para el marcador)
- **Esfuerzo:** chico

### Después del pueblito: colecta del pozo de Rosa como segunda meta
- **Cuándo:** Al fundar (día 10-12) y etapa 2 (días 11-20).
- **Qué cambia:** Al fundar el pueblito, abrir la colecta del pozo (poner el hecho neighbor_rosa.collection_open, que el diálogo de Rosa ya usa). En vez de 'próximamente', la meta del pozo: 1.000 UC; los vecinos aportan 30 UC por día y el jugador completa el resto. Pozo arreglado: agua del pozo a sed llena, sin madera.
- **Números:** Pozo: 1.000 UC. Vecinos: 30 UC x 10 días = 300 UC; el jugador aporta 700 UC (unos 70 UC por día). Referencia con pique, meta de 500 y materiales a la mitad (out11): ganado 719 UC al día 10 y 1.850 al día 20. Sed: pozo arreglado 100 % (well_drink_fixed_bp 10.000) contra 25 % roto (2.500).
- **Por qué:** La etapa del pueblito necesita un siguiente paso visible (hoy termina en 'próximamente'). Los vecinos donan, no cobran; Rosa ya tiene diálogo, escena y colecta programada.
- **Archivos:** /home/user/pres-io/scripts/domain/stage_goal.gd (found(): marcar el hecho de la colecta); /home/user/pres-io/data/dialogue/neighbor_rosa.json; /home/user/pres-io/data/projects/well_repair.tres (cost_uc 1.000); /home/user/pres-io/scenes/actors/neighbor_rosa.tscn y /home/user/pres-io/scenes/props/well_site.tscn (en el pueblito); /home/user/pres-io/data/text/strings.csv (FOGON_NEXT, línea 476)
- **Esfuerzo:** mediano

### Pizarrón del día visible desde la mañana 1 (sin esperar a Raúl)
- **Cuándo:** Cada mañana desde el día 1.
- **Qué cambia:** Mostrar el pizarrón de Raúl (clima, lluvia, cada pasada con su hora y el antojo) como panel fijo de la carpa desde el día 1, con el mismo texto de Neighbors.raul_board. Título: 'Hoy en el camino'. Frase nueva: 'Ramiro a las 11:50. Turbo no opina.'
- **Números:** Hoy el pizarrón se ve solo hablando con Raúl: llega el día 8-11 en la mitad de las corridas del bot. Contenido: clima, 4 pasadas con hora de paso frente a la carpa y antojo.
- **Por qué:** Decidir el día (cuándo pescar, cuándo estar en el camino) es lo que más cuesta en los primeros 10 días. La información es gratis: no es sueldo ni crédito, y Raúl sigue con su problema (escanear) sin ser el único que informa.
- **Archivos:** /home/user/pres-io/scripts/domain/neighbors.gd (raul_board: sin cambio de reglas); /home/user/pres-io/scripts/presentation/ui/neighbor_panel.gd (línea 66: mover el bloque a un panel de la carpa); /home/user/pres-io/data/text/strings.csv (RAUL_BOARD_TITLE, línea 506)
- **Esfuerzo:** mediano

### Meta visible con su cuenta y una línea por vecino
- **Cuándo:** Desde el cartel (día 2) hasta la fundación.
- **Qué cambia:** En el HUD, bajo el objetivo: 'Pueblito: 320/500 UC · chapas 2/5 (Coco) · cemento 0/3 (Chola) · escritura 6/10 visitas · vecinos 2/3'. En el panel de la meta, una línea por vecino con su condición: 'Salim: 3 paradas con venta en un día, con cartel', 'Beto: el primer ahumado', 'Raúl: luces del lago 1/2'. Mostrar solo lo que falta.
- **Números:** Hoy el panel dice 'Vecinos con carpa 0/3' sin explicar cómo, y la pista solo dice dónde comprar. Raúl depende del sorteo (18-21 % por noche). Con la idea de las luces forzadas, Raúl ya está el día 5.
- **Por qué:** Responde 'qué hago ahora' en una línea y 'por qué falta X' en otra. Cada línea nombra la acción y el lugar (Coco, Chola, el lago).
- **Archivos:** /home/user/pres-io/scripts/presentation/ui/hud.gd (línea 113: objetivo); /home/user/pres-io/scripts/presentation/ui/objectives.gd (OBJ_GOAL con cuenta); /home/user/pres-io/scripts/presentation/ui/bag_panel.gd (_add_goal, líneas 75-89); /home/user/pres-io/data/text/strings.csv (GOAL_HINT, línea 469; OBJ_GOAL, línea 398; claves nuevas por vecino)
- **Esfuerzo:** mediano

### Dormir: aviso de pasadas perdidas y costo si es antes de las 19:30
- **Cuándo:** Cualquier hora; el aviso desde el día 1.
- **Qué cambia:** El botón Dormir muestra antes de confirmar: 'Dormir ahora: te perdés 2 pasadas (1 con venta)'. Si dormís antes de las 19:30 (dusk_minute), la jornada se salta con la pérdida de 'dormir afuera' (-25 % de hambre y sed).
- **Números:** Hoy go_to_bed no valida la hora: dormir a media mañana completa la jornada sin hambre ni sed y sin pasadas. Costo propuesto: slept_outside_loss_bp (2.500) antes de las 19:30. Pasadas por día: 4.
- **Por qué:** Un atajo sin costo claro no es una decisión. El aviso convierte la elección en un número que el jugador entiende.
- **Archivos:** /home/user/pres-io/scripts/domain/simulation.gd (go_to_bed y advance_to_end_of_day, líneas 76-93); /home/user/pres-io/scripts/presentation/ui/ui_root.gd (acción de cama, líneas 164-165 y caso 'sleep'); /home/user/pres-io/data/text/strings.csv (ACTION_SLEEP, línea 27)
- **Esfuerzo:** chico

### Etapa 2: mina a mano con pico y comprador de mineral (sin ayudantes)
- **Cuándo:** Etapa 2 (días 11-20), después del pueblito.
- **Qué cambia:** Comerciante nuevo, el del pico, que pasa desde el día 11 (hace falta una condición por hecho 'pueblo_founded'; hoy _pick_merchant solo mira edificios). Vende el pico a 80 UC. La mina es un frente de roca junto al camino que se pica con golpes como la tala (4 golpes, zona 2.200, velocidad 1,1): cada golpe acertado da 1 mineral. Coco compra mineral a 10 UC. Sin ayudantes en esta etapa.
- **Números:** Propuesta a calibrar con el bot: 6 mineral por día = unos 60 UC por día (cerca de lo que pide el pozo: unos 70 UC por día del jugador). Pico: 80 UC, 1 o 2 días de ingreso en la etapa 1.
- **Por qué:** Pico manual sin sueldo: respeta 'los vecinos no cobran' y que todo lo manual es un skillcheck. Los ayudantes con sueldo (que se van si no se les paga) quedan para la etapa 3.
- **Archivos:** /home/user/pres-io/data/merchants/ (comerciante nuevo, .tres); /home/user/pres-io/scripts/domain/merchants.gd (_pick_merchant: condición por hecho); /home/user/pres-io/scripts/domain/player_actions.gd (picar, como chop_tree); /home/user/pres-io/scripts/presentation/ui/ui_root.gd (contexto 'mine' y su acción); /home/user/pres-io/scripts/presentation/ui/activities.gd (Strikes reutilizado); /home/user/pres-io/data/items/ (pico y mineral); /home/user/pres-io/data/text/strings.csv
- **Esfuerzo:** grande

## Quedan para después (del jurado)

- Después de implementar las seis de progresión, volver a medir con el bot. Si la fundación sigue después del día 12: orilla de pesca a unos 8 m del camino (mediano; con el paquete ahorra solo un día) y Coco todos los días con el cartel (mediano; meta 10 → 15/20).
- Detalle de la meta y tablero de saltos (medianos): cuenta por requisito y por vecino en la mochila (Tab), y la próxima compra con su ETA. Conviene hacerlos cuando la meta de 500 esté fijada.
- Ajustes chicos de día 1: Mantené E con rótulo y aviso al soltar, y ventana de seña más ancha con cuenta regresiva. Primero mirar cómo se siente la línea «Ahora».
- Próxima tanda de UI (medianos): confirmar compras y obras con costo y efecto; última pasada y cuánto se pudre; chips de estado con hora; avisos con prioridad y «Mientras dormiste»; leyenda del skillcheck.
- Forma de las personas: variación por persona con tinte y desgaste (mediano). Si siguen cubiculares, menos piezas por persona (mediano), más segmentos (chico) y, solo si hace falta, el cuerpo único SDF (grande).
- Economía y etapas 2 y 3: conservadora que guarda pescado crudo, rehecha sin bajar los 250 UC (mediano); hacha de entrada, buscando otra salida que no sea un hacha de 60 UC (del día 1 al 3 se queda sin madera); Beto con su propia leña (lo decide Tomás: DESIGN dice que lo hace con tu leña); Rosa y el pozo; la mina con el pico.
- Descartadas por romper reglas o bajar precios: caña de fibra a 120 UC, cinta a 10 UC y conservadora a 100 UC (bajan precios; PROGRESS: los precios nunca bajan); costo por uso de las cañas (idem); desmayo que se reinicia por decena y tope de 150 UC (cambian la regla del desmayo, lo decide Tomás); pizarrón de Raúl desde el día 1 (su beneficio llega con él).
