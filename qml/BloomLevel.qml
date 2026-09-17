import QtQuick

// Un nivel de la piramide de bloom: high-pass, blur horizontal, blur vertical.
//
// El high-pass de cada nivel toma la SALIDA DEL HIGH-PASS del nivel anterior,
// no la lluvia original: asi el downsample sucesivo lo hace el propio
// ShaderEffectSource al renderizar a una textura mas chica, igual que el
// original encadenando FBOs cada vez menores.

Item {
  id: level

  property var inputTexture            // textura de entrada del high-pass
  property real highPassThreshold: 0.1
  property size levelSize: Qt.size(64, 64)
  property url shaderDir: Qt.resolvedUrl("../shaders/")

  // Lo que consume el nivel siguiente, y lo que consume el combine.
  readonly property alias highPassTexture: hpSource
  readonly property alias output: vBlurSource

  readonly property size texel: Qt.size(1.0 / Math.max(1, levelSize.width),
                                        1.0 / Math.max(1, levelSize.height))

  ShaderEffect {
    id: hp
    anchors.fill: parent
    fragmentShader: level.shaderDir + "highpass.frag.qsb"
    property variant src: level.inputTexture
    property real highPassThreshold: level.highPassThreshold
  }
  ShaderEffectSource {
    id: hpSource
    sourceItem: hp
    textureSize: level.levelSize
    hideSource: true
    live: true
    smooth: true
    visible: false
  }

  ShaderEffect {
    id: hBlur
    anchors.fill: parent
    fragmentShader: level.shaderDir + "blur.frag.qsb"
    property variant src: hpSource
    property size direction: Qt.size(1, 0)
    property size texelSize: level.texel
  }
  ShaderEffectSource {
    id: hBlurSource
    sourceItem: hBlur
    textureSize: level.levelSize
    hideSource: true
    live: true
    smooth: true
    visible: false
  }

  ShaderEffect {
    id: vBlur
    anchors.fill: parent
    fragmentShader: level.shaderDir + "blur.frag.qsb"
    property variant src: hBlurSource
    property size direction: Qt.size(0, 1)
    property size texelSize: level.texel
  }
  ShaderEffectSource {
    id: vBlurSource
    sourceItem: vBlur
    textureSize: level.levelSize
    hideSource: true
    live: true
    smooth: true
    visible: false
  }
}
