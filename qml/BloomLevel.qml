import QtQuick

// One level of the bloom pyramid: high-pass, horizontal blur, vertical blur.
//
// Each level's high-pass takes the PREVIOUS LEVEL'S HIGH-PASS OUTPUT, not the
// original rain: the successive downsampling is done by the ShaderEffectSource
// itself as it renders into a smaller texture, the same way upstream chains
// ever-smaller FBOs.

Item {
  id: level

  property var inputTexture            // input texture for the high-pass
  property real highPassThreshold: 0.1
  property size levelSize: Qt.size(64, 64)
  property url shaderDir: Qt.resolvedUrl("../shaders/")

  // What the next level consumes, and what combine consumes.
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
