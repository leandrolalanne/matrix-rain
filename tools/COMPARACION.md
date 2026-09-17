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

## Lo que deberia hacerse

Sacar al gestor de ventanas del medio y renderizar offscreen a un tamaño fijo:
Chromium con `--headless=new --screenshot --window-size=W,H` (sin
`--disable-gpu`, que mata el WebGL) y el QML con una plataforma offscreen. Es
determinista y no depende de que workspace este libre. No esta hecho.
