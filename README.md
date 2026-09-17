# omarchy-matrix-rain

Port nativo de la lluvia digital de [Rezmason/matrix](https://github.com/Rezmason/matrix)
a un shader de Qt Quick, para usarla como fondo de escritorio sin pagar el
costo de un navegador.

**Estado: el paso de lluvia funciona y coincide con el original. Falta el bloom.**

```bash
tools/build-shaders.sh      # compila shaders/*.frag a .qsb
qml6 dev/main.qml           # ventana de prueba
qml6 dev/fullscreen.qml     # pantalla completa, para comparar
```

## Por que existe

Correr el Rezmason real en un WebView layer-shell funciona, pero cuesta
**~880 MB de RAM y ~35% de un core** con dos monitores: un proceso WebKit
completo por pantalla. Un `ShaderEffect` nativo corre dentro del proceso de
Quickshell que ya existe y no suma ninguno.

## Lo que hace posible el port

El original corre cuatro ping-pong buffers en half float (intro, raindrop,
symbol, effect) y encadena `rain -> bloom -> palette -> quilt`. Parece
irreproducible en un solo paso, pero **para la version `classic` ese estado no
hace falta**, y se puede demostrar leyendo los defaults:

| Default | Valor | Consecuencia |
|---|---|---|
| `brightnessDecay` | `1.0` | `mix(previo, nuevo, 1.0)` descarta el previo |
| `skipIntro` | `true` | el intro devuelve `2.0` fijo, y `max(0, 1 - a*5)` da 0 |
| `rippleTypeName` | `null` | `multipliedEffects=1`, `addedEffects=0`: no-op |
| `classic` | `{}` | no override ninguno de los anteriores |

Queda una funcion pura de (columna, fila, tiempo).

### El ciclado de glifos, en forma cerrada

Es la unica parte realmente stateful: `age` acumula por cuadro y al cruzar 1.0
sortea simbolo nuevo con el `simTime` de ese instante. Pero los tiempos de
switch son conocidos:

```
k      = floor(age0 + cyclesPerSecond * t)
t_k    = (k - age0) / cyclesPerSecond
symbol = floor(glyphSequenceLength * randomFloat(screenPos + t_k))
```

No es una aproximacion: da el mismo resultado. La unica diferencia deliberada
es que upstream avanza por CUADRO (y por lo tanto su velocidad de ciclado
depende del refresco); aca se fija en segundos.

## Como se verifico

No a ojo. Se capturaron el original (Chromium, `?version=classic`) y el port,
ambos a 1920x1080 en el mismo monitor, y se midio el paso de grilla por
autocorrelacion del perfil de brillo:

```
original  alto de celda ~24px -> 45 filas (corr 0.91)
port      alto de celda ~24px -> 45 filas (corr 0.86)
```

Eso destapo un error real: las CELDAS son cuadradas, no la grilla. Upstream
mapea `numColumns` a lo ANCHO y deja que las filas caigan con el mismo paso
(24 = 1920/80). Estirar 80x80 a la pantalla achata las celdas y duplica la
densidad vertical.

La paleta se verifico traduciendo `colorToRGB.js` a Python y comparando los
cinco stops contra la conversion propia: coinciden exacto. No hay correccion
de gamma en ningun lado, y la rampa interpola **lineal** (no smoothstep) con
los extremos sostenidos.

## Pendiente

- **Bloom.** Es la diferencia visual que queda: el original suma un high-pass
  desenfocado ANTES de la rampa (`brightness = primary + bloom`), asi que sin
  el todo cae mas abajo en la paleta y se ve mas apagado y sin halo. Son 5
  niveles de piramide x (high-pass + blur H + blur V) + combine, encadenados
  con `ShaderEffectSource`. Mecanico pero verboso.
- Empaquetarlo como plugin de Quickshell sobre una superficie layer-shell.
- Los otros presets. `operator` tiene `rippleTypeName: "box"` y por lo tanto SI
  usa el buffer de efectos; no se verifico si los ripples son derivables.

## Limitacion conocida: el reloj

`elapsed` crece sin cota y el uniform es float32. A la hora `rainTime` ronda
1400, la resolucion es ~1e-4 contra un paso por cuadro de ~0.0067: invisible.
Cerca de las 24h `rainTime` ronda 35000, la resolucion cae a ~0.002 y quedan
~3 niveles por paso: ahi la caida empieza a juddear.

No se arregla wrappeando el reloj como hace el tema enter-the-matrix, porque
`wobble` usa frecuencias irracionales (`sin(sqrt(2)x)`, `sin(sqrt(5)x)`)
justamente para que el campo no repita, y eso deja al reloj sin punto de wrap
limpio. Las salidas son resignar `wobble`, aceptar un salto cada tantas horas,
o emular doble precision en el acumulador.

## Creditos y licencia

El algoritmo de la lluvia, el atlas MSDF (`assets/matrixcode_msdf.png`) y la
paleta vienen de [Rezmason/matrix](https://github.com/Rezmason/matrix), MIT.
Ver `LICENSE.rezmason`. Este port es MIT tambien, ver `LICENSE`.

El hallazgo de que `FrameAnimation` es necesario (con `Timer` el reloj avanza
pero el `ShaderEffect` no repinta) viene del tema
[enter-the-matrix](https://github.com/tymurbogach/omarchy-enter-the-matrix-theme)
de tymurbogach, que resolvio el mismo problema antes.
