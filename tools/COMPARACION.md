# Como comparar contra el original (y como NO)

La fidelidad de este port se midio comparando capturas contra Rezmason corriendo
en Chromium. Documentar el protocolo importa porque el metodo obvio da resultados
falsos, y me comi varios.

## Metricas

Sobre el canal verde de la captura:

| Metrica | Que dice |
|---|---|
| `tinte_rg`, `tinte_bg` | suma(R)/suma(G) y suma(B)/suma(G). **La mejor señal**: es la paleta, y es casi inmune al cuadro que toque. |
| `p99` | brillo de los picos: los cursores. |
| `p50`, `media` | cuanto resplandor tenue hay repartido. Sensible al bloom. |
| `negro` | fraccion de pixeles casi negros. |
| paso de grilla | autocorrelacion del perfil de brillo por fila -> px por celda. |

## Las tres trampas

**1. Capturar el monitor en vez de la ventana.** `visibility: Window.FullScreen`
no siempre gana: Hyprland tila la ventana igual, y entonces `grim -o <monitor>`
captura Nautilus y una terminal. Una medicion asi dio -55% de brillo, que era
puro escritorio. Capturar SIEMPRE con `grim -g "$(geometria de la ventana)"` y
verificar la geometria despues del sleep, no antes.

**2. Comparar capturas de corridas distintas.** El tamaño del tile que da
Hyprland cambia segun que mas haya en el workspace, y el tamaño cambia las
metricas (el glifo escala con el ancho). Dos corridas de la MISMA config dieron
0.1197 y 0.0911 de media solo por eso. Port y original tienen que capturarse
**seguidos, en la misma corrida**, y hay que verificar que la geometria coincida
antes de comparar.

**3. Olvidar que el campo esta animado.** Entre cuadros de una misma corrida las
metricas se mueven ~5%. Cualquier diferencia menor a eso es ruido.

## El metodo que funciona

Sacar al gestor de ventanas del medio. Las dos puntas se capturan offscreen y
el resultado es reproducible:

```bash
# el port
qml6 dev/grab.qml -- salida.png 1280 720 8 1.0     # ancho alto settle resolution

# la referencia (tools/preview.sh la clona a .cache/ la primera vez)
cd .cache/rezmason && python3 -m http.server 8731 --bind 127.0.0.1 &
chromium --headless=new --window-size=1600,900 --virtual-time-budget=10000 \
  --screenshot=orig.png "http://127.0.0.1:8731/?version=classic"
```

La referencia no vive en este repo: es una herramienta de medicion, no parte del
producto. `tools/preview.sh` la clona a demanda a `.cache/`, que esta ignorado.

Dos advertencias:

**El tamaño que pide el QML no es el que sale.** `grabToImage` multiplica por el
devicePixelRatio de la pantalla, y ni `QT_SCALE_FACTOR`, ni
`QT_ENABLE_HIGHDPI_SCALING=0`, ni `QT_SCREEN_SCALE_FACTORS=1` lo evitan (probados
los tres). Con dpr 1.25, pedir 1280x720 da 1600x900. No es problema: alcanza con
pedirle a Chromium el tamaño que efectivamente salio, porque `numColumns` se
reparte sobre el ancho en los dos y el canvas interno queda igual.

**Chromium headless cae a WebGL por software** (SwiftShader). El resultado se ve
correcto y la matematica del shader es la misma, pero conviene tenerlo presente
como posible fuente de diferencias chicas.
