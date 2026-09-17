# omarchy-matrix-rain

Port nativo de la lluvia digital de [Rezmason/matrix](https://github.com/Rezmason/matrix)
a un shader de Qt Quick, para usarla como fondo de escritorio sin pagar el
costo de un navegador.

**Estado: lluvia y bloom funcionando. Queda una diferencia de brillo en los
medios tonos, identificada pero sin confirmar (ver Fidelidad).**

```bash
tools/build-shaders.sh      # compila shaders/*.frag a .qsb (solo si tocas un .frag)
tools/preview.sh            # vista previa en una ventana
tools/preview.sh --ambos    # el port y el original de Rezmason, lado a lado
qml6 dev/main.qml           # equivalente a preview.sh, directo
```

Super+F pone en pantalla completa la ventana enfocada.

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

## La cadena

```
rain -> piramide de 5 niveles (high-pass -> blur H -> blur V) -> combine -> palette
```

El bloom no se compone encima del color: se SUMA al brillo antes de mirar la
rampa (`brightness = primary + bloom`), asi que un glifo brillante no solo gana
halo sino que trepa en la paleta.

Cada nivel de la piramide hace high-pass de la salida del high-pass del nivel
anterior, y el downsample lo hace el `ShaderEffectSource` al renderizar a una
textura mas chica. Un detalle de upstream que confunde: en `bloomPass.js` pasan
`height: viewportWidth` y `width: viewportHeight`, cruzados. No es un bug — con
el cruce el offset da exactamente un texel. Aca se pasa el texel directo.

## Fidelidad

Medido contra el original a igual tamaño (1600x900), **ambos offscreen**: el
port con `Item.grabToImage()` y Rezmason con `chromium --headless=new
--screenshot`. Ni ventanas ni gestor de ventanas de por medio, asi que es
reproducible. Ver `tools/COMPARACION.md`.

| metrica | original | port | delta |
|---|---|---|---|
| balance de color R/G | 0.3825 | 0.3843 | **+0.5%** |
| balance de color B/G | 0.2422 | 0.2404 | **-0.7%** |
| brillo de picos (p99) | 0.9333 | 0.9569 | +2.5% |
| brillo medio | 0.1213 | 0.1126 | **-7.2%** |
| fraccion casi negra | 0.5634 | 0.6082 | +8.0% |
| paso de grilla | 20 px / 45 filas | 20 px / 45 filas | igual |

Color y geometria practicamente clavados. Queda ~7% menos de brillo medio y un
8% mas de negro puro: al original le sobra un resplandor tenue repartido que al
port le falta. Con una varianza entre cuadros de ~5%, eso esta apenas por
encima del ruido.

### Lo que NO era

Durante un tiempo la brecha parecia del -28%, y se atribuyo a que upstream trae
`resolution: 0.75` en sus defaults — renderiza el canvas al 75% y deja que el
navegador lo escale, suavizando los glifos.

**Medido, esa hipotesis es falsa.** Aplicar 0.75 empeora todo:

| | media | color R/G | color B/G |
|---|---|---|---|
| `resolution 1.00` | -7.2% | +0.5% | -0.7% |
| `resolution 0.75` | -15.3% | -6.2% | -13.4% |

El razonamiento estaba bien; lo que estaba mal es DONDE cae el escalado.
Upstream corre la cadena entera a esa fraccion y el navegador escala la imagen
FINAL (`canvas.width = clientWidth * dpr * resolution`, con el canvas estirado
por CSS). Aca solo baja la textura de lluvia y la paleta sigue a resolucion
completa, asi que el escalado cae ANTES del mapeo de color en vez de despues:
en vez de suavizar el color final, pierde cobertura de glifo antes de la rampa.

Por eso `resolution` quedo en `1.0` y es una palanca de rendimiento, no de
fidelidad. Para que 0.75 fuera fiel habria que envolver la cadena completa
(palette incluida) en un `ShaderEffectSource` y escalar recien la salida.

Buena parte del -28% original tampoco era real: venia de comparar capturas de
ventana de tamaños distintos, antes de tener medicion determinista.

## Proveedor y maquinaria

Este repo es **solo el proveedor**: los shaders, el atlas, la paleta y el
marcador. Lo que los monta en algun lado — plugin de Quickshell, daemon de
wallpaper, instalador de un tema — vive afuera y lee `provider.json`.

La division es deliberada, copiada del tema
[enter-the-matrix](https://github.com/tymurbogach/omarchy-enter-the-matrix-theme):
un segundo proveedor (otra lluvia, otro efecto) no deberia obligar a tocar una
linea de la maquinaria.

```
omarchy-matrix-rain     <- este repo: el efecto
  provider.json           declara shaders, atlas, paleta, marcador, defaults
  shaders/  assets/  qml/

omarchy-matrix-theme    <- consumidor: instala el marcador en su carpeta de
                           fondos, aporta colores de terminal, backgrounds, etc.
```

### Hosts posibles

| Host | Multipaso | Que corre |
|---|---|---|
| Quickshell (`ShaderEffect`) | si | la cadena completa, con bloom |
| hyprglaze, shaderbg, neowall, wallrs | no | solo `rain` (sin bloom) |
| Shadertoy | si (buffers) | la cadena completa |

Por eso los uniforms usan los nombres de Shadertoy (`iTime`, `iResolution`):
el mismo shader corre en todos, y el que no soporte multipaso usa la etapa
`rain` sola. Se pierde el bloom, no la lluvia.

### Como se selecciona como fondo en Omarchy

`assets/matrix-rain.live.png` hace tres cosas a la vez:

1. es la **miniatura** en el switcher de fondos,
2. seleccionarlo es lo que **enciende** la lluvia en vivo — el consumidor mira
   el nombre del fondo actual y busca el marcador `.live.`,
3. si nada esta corriendo, es lo que ves: un **fondo estatico** decente.

Va a `~/.config/omarchy/backgrounds/<slug>/`, que Omarchy lista antes que los
del tema (`omarchy-theme-bg-next` ordena por ruta, y `.config` < `.local`).

El marcador es `.live.` y no `-live-` a proposito: enter-the-matrix usa ese
otro, y si estan los dos instalados encenderia su lluvia junto con la nuestra.


## Pendiente

- Confirmar el efecto de `resolution: 0.75` con una captura pareada valida.
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
