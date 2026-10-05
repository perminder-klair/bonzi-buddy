import QtQuick

Item {
    id: sprite
    property string pose: "idle"
    property bool reducedMotion: false
    property int tick: 0
    property bool blinking: false
    readonly property int frame: pose === "sleep" ? 6
        : pose === "celebrate" ? 7
        : pose === "wave" ? (reducedMotion ? 4 : 4 + tick % 2)
        : pose === "speak" ? (reducedMotion ? 2 : [2, 0, 2, 3, 2, 0][tick % 6])
        : blinking ? 1 : 0
    clip: true
    Image {
        id: sheet
        source: "assets/bonzi-sprites.png"
        width: sprite.width * 4
        height: sprite.height * 2
        x: -(sprite.frame % 4) * sprite.width
        y: -Math.floor(sprite.frame / 4) * sprite.height
        smooth: true
        mipmap: true
    }
    Timer {
        interval: sprite.pose === "wave" ? 280 : 150
        running: sprite.visible && !sprite.reducedMotion && (sprite.pose === "wave" || sprite.pose === "speak")
        repeat: true
        onTriggered: sprite.tick++
    }
    Timer {
        interval: 4300
        running: sprite.visible && sprite.pose === "idle" && !sprite.reducedMotion
        repeat: true
        onTriggered: { sprite.blinking = true; blinkEnd.restart() }
    }
    Timer { id: blinkEnd; interval: 140; onTriggered: sprite.blinking = false }
}
