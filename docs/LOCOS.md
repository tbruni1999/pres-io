# Catálogo de locos (propuesta, 10 de octubre de 2026)

Generado con 6 ángulos distintos (18 candidatos) y un jurado que fusionó, descartó por reglas y puntuó.
Es una propuesta: lo implementado está en DESIGN.md.


## 0. Lo que condiciona todo
- **Hay 3 lugares para carpa** (`SPOTS = lake, back, road`) y Beto ocupa uno, así que en la etapa de carpa entran **2 locos más**. Si se quieren más en el lago, hay que sumar lugares. Si no, el resto pasa al pueblito.
- Ahora un loco llega solo por un hecho del jugador (`ATTRACTED_BY`). Todos los de abajo usan un hecho nuevo, que es un nombre sugerido.
- Precios que hay que tener en cuenta: pan 7 a 12, bidón 5 a 6. El ahumado (mojarra / tararira) se paga 8/20 con Ramiro, 11/28 con la Chola y 13/34 con Coco.

## 1. Fusiones

| Grupo | Se queda | Absorbe | Por qué |
|---|---|---|---|
| Adivinos (clima y antojo de mañana) | **Raúl "Antena"** | Madame Yoli, Profe Anselmo | Los tres hacen lo mismo. Raúl tiene el problema más limpio, que además depende de dónde ponés su carpa. Yoli y Anselmo pasan al pueblito. |
| Guardias de noche | **Kid Pejerrey** | Walter el Sereno, Cabo Peralta | Hacen el mismo trabajo. El problema de Kid es una elección (aceptar o no el guanteo), lo que lo hace más jugable. Peralta queda como comisario del pueblito. |
| Seguros | **Carpinchi Seguros** | Pocho Seguros, Wilson Carpinchi | Es el mismo personaje dos veces. Se juntan la carencia, la exclusión por viento y el peritaje. |
| Curanderas | **La Abuela Yuya** | La Tota | Son la misma idea. Se usa la mecánica de la Tota (té gratis, prohibiciones) y la historia de la Yuya (la planta que lleva a doña Rosa). |
| Pozos y veta | **La Nené Carnada** | Cacho Pozo | Los dos cavan pozos y terminan en la veta. Cacho vuelve en el pueblito vendiendo el pico. |
| Sacan el espinel por vos | **Mirta y la Clorinda** | Nemo "el Primo" | Hacen lo mismo y los dos llevan a la ganadería. Mirta tiene más humor y una salida legal mejor (la escritura). |

Nombres repetidos: hay un Pocho de pesca y un Pocho de seguros, y un Wilson hachero y un Wilson de seguros. Quedan **Nono Pocho**, **Wilson el Hachero** y **Carpinchi**. Darío pasa a apellidarse Ferreyra para no repetir el Sosa de Kid.

## 2. Descartes por reglas
- **El ojeo de la Yuya**: es un cobro fijo cada 3 días, o sea un sueldo con otro nombre. Se saca. La Yuya se queda con la mecánica de la Tota.
- **El "fondo de prosperidad" de Anselmo**: se queda con tu primera venta del día, que también es un sueldo encubierto.
- **Los 30 minutos obligatorios de lectura de Anselmo**: es un castigo sin gracia.
- **El castigo de la Torre de Yoli** (no vender ahumado o herramienta ×2): es demasiado críptico para la carpa.
- **Wilson el Hachero minero con sueldo**: solo se puede en el pueblito, como ayudante, y eso el DESIGN lo permite. En la carpa no cobra.
- **Darío intentando fiarle a Coco**: rozaba la regla de fiado. Queda como chiste (Coco le dice que no) y no como mecánica.
- **"Energía"**: no existe en el juego. Donde aparecía se pasa a hambre o sed.

## 3. Puntajes
Escala de 1 a 5. En la columna Balance, 5 quiere decir poco riesgo.

| Loco | Rol | Humor | Claridad | Balance | Implementar | Total |
|---|---|---|---|---|---|---|
| Mirta y la Clorinda | tarea | 5 | 5 | 5 | 4 | **19** |
| Raúl "Antena" | beneficio | 4 | 5 | 4 | 5 | **18** |
| Salim | vendedor | 5 | 4 | 4 | 4 | **17** |
| Carpinchi Seguros | vendedor | 5 | 4 | 4 | 4 | **17** |
| Kid Pejerrey | beneficio | 4 | 4 | 3 | 4 | 15 |
| Nono Pocho | tarea | 4 | 4 | 3 | 4 | 15 |
| La Nené Carnada | vendedor | 4 | 4 | 4 | 3 | 15 |
| Wilson el Hachero | tarea | 5 | 3 | 2 | 3 | 13 |
| La Abuela Yuya | beneficio | 4 | 3 | 3 | 3 | 13 |
| Darío "Yapa" Ferreyra | tarea | 4 | 3 | 2 | 3 | 12 |

## 4. Catálogo final (10 locos)

Quedan **4 de tarea, 3 vendedores y 3 de beneficio**.

### Vendedores

**Salim, "el Turco de Todo"** (vendedor)
- **Lo trae**: tener el cartel y venderles a comerciantes 3 veces en un día (hecho `busy_road`).
- **Qué hace**: tiene una manta abierta a toda hora con cosas que el camino no trae.
- **Problema**: grita ofertas con megáfono de 6 a 9. Si su carpa está en `lake`, en esas horas pica 30 % menos. En cualquier otro lugar te despierta igual y arrancás el día con +15 de hambre. Si pasás a menos de 4 m de la manta, te frena 2 s.
- **Números**:
  - Sal gruesa: 10 UC (un pescado crudo aguanta un cierre).
  - Cinta aisladora: 20 UC (−30 % de desgaste, una vez por herramienta y por día).
  - Sombrilla: 80 UC (con sol, 40 % menos sed cerca de la carpa).
  - Combo sorpresa: 30 UC (te toca cualquiera de las anteriores, o un "Rolex" inútil con 10 % de chance).
  - Todo sube 1 UC cada 2 capítulos, hasta +5 ("inflación, no es mío").
- **Historia**: busca al Gallego Paz, su ex socio, que se fue con un container de linternas. Las pistas salen de la panza de los pescados. En el capítulo 7 descubre que el Gallego le vende las linternas al de traje para las luces del lago. En el capítulo 10 reparte la mercadería gratis (y aclara que es lo único gratis de su vida). Después abre "El Todo Salim", el almacén del pueblito.
- *"¿Fiado? Fiado vendía mi abuelo. Por eso yo vendo y él está en una foto."*
- *"Esto no es caro, maestro. Caro es lo que pagás por no tenerlo."*

**Carpinchi Seguros** (vendedor)
- **Lo trae**: el primer robo, sea del zorro o del de traje (hecho `robbed_once`).
- **Qué hace**: vende pólizas de un día, al contado.
- **Problema**: la letra chica siempre juega en tu contra. Cada mañana te ofrece "ampliar la cobertura" y no te deja agarrar la caña por 3 s (con la bici te le escapás). Para cobrar hay que hacer el peritaje: 20 min de juego sin pescar ni vender, más un cartel con el contrato que no se puede saltear por 5 s.
- **Números**:
  - Póliza Zorro: 15 UC por día. Paga lo robado a precio de Coco.
  - Póliza Leña: 10 UC por día. Repone la leña robada.
  - Póliza Lluvia: 15 UC. Paga 40 UC si llueve.
  - Carencia: todas cubren recién a partir del día siguiente al de la compra.
  - Ninguna cubre los días de viento ("fuerza mayor eólica").
- **Historia**: quiere ser "Productor del Año" y le falta asegurar algo imposible. Prueba con el lago, con Turbo, con el humo de Beto. Junta pruebas de que el de traje hace robos chicos para asustar a la gente y que venda. En el capítulo 10 te da la "Póliza Pueblo" y anuncia su próximo producto, el Seguro de Secuestro.
- *"El zorro no es un animal. Es un siniestro con cola."*
- *"Firme acá, acá y acá. Esta última es para que conste que firmó las otras."*

**La Nené Carnada** (vendedor)
- **Lo trae**: haber pescado 30 veces (hecho `fished_30`). Llega diciendo: *"Te vi pescar con miga de pan. Me dolió el alma."*
- **Qué hace**: vende carnada viva, que también sirve para el espinel.
- **Problema**: saca las lombrices de TU suelo. Cada noche deja 2 o 3 pozos cerca de lo que construiste. Si pisás uno, quedás trabado 2 s y tenés 20 % de chance de que se te caiga un pescado crudo. Taparlo es mantener E 2 s, y ella cava otro.
- **Números**:
  - Tarro de lombrices: 15 UC (+30 % de pique por 1 día; con carnada el espinel saca +1 por noche).
  - Mojarritas vivas ×3: 30 UC (en cada tirada, 60 % de chance de tararira).
  - Precio de lista, nunca baja.
- **Historia**: busca la Lombriz Madre que vio su abuelo. Cada vez cava más hondo y encuentra una herradura de Turbo, una dentadura y la llave del Fiat de la Chola. En el capítulo 10 encuentra una veta en vez de la lombriz: *"Esto no se come, pero se vende."* Es el anzuelo para la minería.
- *"Esta lombriz se llama Raúl. No te encariñes, va al anzuelo."*
- *"¿El pozo al lado de tu carpa? Eso es arqueología, no me lo cobres."*

### Beneficio

**Raúl "Antena" Benítez** (beneficio)
- **Lo trae**: haber visto 2 capítulos de las luces del lago (hecho `lake_lights_2`).
- **Qué hace**: cada mañana anota en un pizarrón el **clima de mañana y el antojo de mañana** (qué comerciante y qué producto, a +50 %). Acierta siempre.
- **Problema**: cuando para un comerciante, sale a "escanearlo" con la antena, y la parada dura 30 % menos. La chance de que salga depende de su carpa: 100 % en `road`, 50 % en `lake` y 15 % en `back`. Ramiro le tapa los ojos a Turbo y la Chola ni apaga el motor.
- **Números**: el informe es gratis, uno por día. Lo que se pierde es tiempo de parada, nunca precio.
- **Historia**: quiere que lo abduzcan para cobrar una jubilación interplanetaria, y cada capítulo arma un aparato peor que el anterior. Descubre que las luces son un dron del de traje que saca fotos para el loteo. No se desanima: decide que el de traje es un agente de otro planeta. En el capítulo 10 pide una computadora "para mandarle mails a la nave" y queda como el técnico del pueblo.
- *"Mañana nublado y la Chola paga de más el ahumado. Me lo dijo un marciano, o un vecino de Florida."*
- *"No te acerques al cartel, que me cortás la frecuencia."*

**Kid Pejerrey (Rubén Sosa)** (beneficio)
- **Lo trae**: que el de traje te haya robado leña 2 veces (hecho `wood_stolen_2`).
- **Qué hace**: guardia de noche. Corre al de traje el 100 % de las veces y al zorro el 70 %, aunque el fogón esté apagado.
- **Problema**: cada mañana te desafía a un guanteo de tres minutos.
  - Si aceptás: +20 de hambre, +20 de sed y la caña clava 20 % más lento durante 1 h.
  - Si te negás: esa noche no hace guardia ("no me respetás como profesional").
  - Además te llama "Monzón" delante de los comerciantes.
- **Números**: no cobra. Pide "agua con limón", que no tenés, se queja y ahí queda.
- **Historia**: perdió en el Luna Park en el noveno round y empeñó el cinturón para pagarle el veterinario a un perro. En el capítulo 8 descubre que Polizón es nieto de ese perro. En el capítulo 10 hace una exhibición en el muelle contra Coco, recupera el cinturón con la plata de las entradas y se nombra sereno del pueblo.
- *"Guardia alta, Monzón. La vida pega abajo y el pejerrey también."*
- *"Ese de traje vino a la noche. No le pegué, eh. Le expliqué con las manos."*

**La Abuela Yuya** (beneficio)
- **Lo trae**: comer pescado crudo 3 veces (hecho `ate_raw_3`). Si se implementa el desmayo, puede ser `fainted_once`.
- **Qué hace**: cada mañana te da un té gratis (+25 de sed y +15 de hambre, y ese día gastás 10 % menos). Si te desmayás con ella cerca, te cuesta 0 UC y 1 h.
- **Problema**: uno de cada 4 días te prohíbe algo al azar: vender ahumado, andar en bici o pescar después de las 20. Si lo hacés igual, al otro día no hay té. Además se lleva 1 mojarra cruda por día "para cataplasmas".
- **Números**: vende una sola cosa, la pomada, a 35 UC fijos (cubre el próximo desmayo).
- **Historia**: busca una planta "que crece donde el agua y el fuego se miran". Prueba semillas y le salen un zapallo gigante y un tomate que Polizón cuida. En el capítulo 10 crece una planta rara y te da un plantín: *"Si alguien pregunta, es orégano."*
- *"Abrí la boca. Ajá. Tenés la lengua de uno que vende ahumado y no se lo come."*
- *"Hoy nada de bici. Tenés el ciático cruzado con el ánimo."*

### Tarea

**Mirta y la Clorinda** (tarea)
- **Lo trae**: tener el cartel y el espinel (hechos `built_sign` y `built_longline`).
- **Qué hace**: a las 6 saca el espinel y deja lo que haya en un balde junto a tu carpa, así no se pudre si te olvidás. Si llueve, lo vuelve a encarnar (+1 pescado esa noche).
- **Problema**: la Clorinda te eligió a vos de enemiga.
  - Cada mañana te come 1 pan de la mochila. Si no hay pan, muerde la lona (−15 % de durabilidad).
  - Muge a las 5:30 en la puerta de tu carpa, así que arrancás con +10 de hambre.
- **Números**: rescata el 100 % del espinel. No cobra.
- **Historia**: el de traje la echó de la estancia con una escritura firmada por un muerto. Cruza datos con la caja del remate de la Chola y aparece la escritura verdadera. En el capítulo 10 la Clorinda está preñada y Mirta te deja el ternero "a medias".
- *"La Clorinda odia a todo el mundo; a vos un poquito más."*
- *"Muuu. Significa 'son las cinco y media'. Ella no tiene reloj, tiene principios."*

**Nono Pocho** (tarea)
- **Lo trae**: construir el muelle (hecho `built_dock`).
- **Qué hace**: pesca desde el muelle de 7 a 13 los días que no llueve. Deja lo que saca en un balde (se agarra con E) y se pudre al cierre igual que el resto.
- **Problema**: pesca con TU mejor caña, la gasta y si la rompe te avisa recién a la noche. Suelta todas las tarariras, también las tuyas si las dejás en el balde.
- **Números**:
  - Saca alrededor de 8 por día (10 con nublado, 6 con viento): 3 de cada 4 son mojarras y quedan, 1 de cada 4 es tararira y la suelta.
  - Cada pez es 1 de desgaste para la caña; la de bambú le dura unos 2 días.
  - Si le dejás una caña de fibra en el muelle, usa esa y no toca la tuya.
- **Historia**: lo echaron del club de pesca por soltar la tararira récord. Busca a "la Colorada", de 4 kg. Su registro de pesca prueba que el lago tiene fauna protegida, y eso frena el loteo. En el pueblito funda el Club de Pesca y Suelta.
- *"Tu caña no se rompió. Se jubiló. Como yo."*
- *"¿La tararira? Libre, como el viento."*

**Wilson el Hachero** (tarea)
- **Lo trae**: comprarle el hacha a la Chola (hecho `bought_axe`).
- **Qué hace**: al cierre suma +5 de madera a la pila. Con él despierto, el de traje no roba.
- **Problema**: usa TU hacha (1 de desgaste por madera) y algunas noches "tala" algo que construiste. El orden es: cartel, estaca del espinel, tablón del muelle, palo de la lona. Siempre te lo devuelve en forma de 1 madera.
- **Números**:
  - 20 % de chance por noche de talar algo, como mucho una vez cada 3 noches.
  - Nunca toca la choza ni el ahumadero.
  - Con el banquito de Coco (30 UC) la chance baja a 8 %.
- **Historia**: busca un árbol que no le alcancen los brazos para abrazar y se hace amigo de Turbo. Arranca las estacas naranjas del loteo y las trae… como leña. En el pueblito es el primer ayudante de la mina, y ahí sí cobra sueldo.
- *"Te traje cinco leñas y una sorpresa. La sorpresa era tu cartel."*
- *"No es que yo tale todo. Es que todo está hecho de madera, hermano."*

**Darío "Yapa" Ferreyra** (tarea)
- **Lo trae**: venderles a Ramiro, la Chola y Coco el mismo día (hecho `sold_to_all_three`).
- **Qué hace**: pone un cajón en el camino y vende lo que dejes ahí, aunque estés pescando o durmiendo. La plata queda en una lata.
- **Problema**: siempre da yapa, y con lo tuyo. Le vende al primero que pasa, aunque sea Ramiro y pague menos. Si el cajón está vacío, vende algo de tu mochila "porque estaba ahí".
- **Números**:
  - Vende a precio de lista y regala 1 de cada 5.
  - Con el cajón vacío, 50 % de chance de vender 1 cosa tuya al azar.
  - El cartel de "NO TOCAR" (1 madera) lo respeta 4 de cada 5 veces.
- **Historia**: lo echaron de la feria por regalar demasiado. Anota todo en un cuaderno y descubre que "esto necesita una computadora". En el pueblito arma la feria y vende por internet.
- *"¿Tu bidón? Lo vendí. Estaba solito en la mochila, mirándome."*
- *"Fiado no, rebaja no. ¿Yapa? La yapa no se negocia, se regala."*

## 5. Recomendación

### 2.º loco: **Salim** (vendedor) | 3.º loco: **Raúl "Antena"** (beneficio)
- **Arman un rompecabezas con los 3 lugares de carpa.**
  - Salim en `lake` te arruina el pique de la mañana.
  - Raúl en `road` acorta las paradas de los comerciantes.
  - Beto ya ocupa uno.
  - Elegir dónde va cada uno pasa a ser una decisión real.
- **Se implementan fácil.**
  - Raúl solo necesita adelantar el clima y el antojo que el juego ya genera, más un multiplicador de duración de la parada.
  - Salim es una tienda con una ventana horaria y un modificador según el lugar.
- **No rompen la economía**: Raúl da información, no plata, y Salim vende a precios que no bajan.
- **Plan B para el vendedor**: Carpinchi Seguros. Funciona solo con eventos que ya existen (zorro y de traje). Su carencia de un día evita que se combine con el pronóstico de Raúl para cobrar la Póliza Lluvia a lo seguro.

### Si se agregan más lugares en el lago
1. **Mirta y la Clorinda**: es la de puntaje más alto y empieza a automatizar la pesca, que es la meta de la etapa 2.
2. **Nono Pocho**.
3. **Kid Pejerrey**: si entra, hay que bajar el robo del de traje para que siga habiendo peligro.

### Quedan para el pueblito
| Personaje | Rama del pueblito |
|---|---|
| Wilson el Hachero | mina, como ayudante con sueldo |
| La Nené Carnada | la veta |
| Cacho Pozo | vende el pico |
| La Abuela Yuya | agricultura y el dilema de doña Rosa |
| Darío | feria y computadora |
| Kid Pejerrey / Cabo Peralta | seguridad y rescate en el secuestro |
| Madame Yoli | avisa robos y anticipa la amenaza de secuestro |
| Profe Anselmo | el banco |
| Carpinchi Seguros | Seguro de Secuestro, si no entró antes en la carpa |
