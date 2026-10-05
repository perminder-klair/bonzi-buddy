import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root
    property bool hidden: false
    property bool sleeping: false
    property bool menuOpen: false
    property string message: ""
    property string action: "idle"
    property int jokeIndex: 0
    property int factIndex: 0
    readonly property var jokes: [
        "Why did the banana go to the doctor? It wasn't peeling well.",
        "I tried to catch some fog. I mist.",
        "Why do programmers prefer dark mode? Because light attracts bugs.",
        "My favourite key? Escape. Everyone needs a little break."
    ]
    readonly property var facts: [
        "Bananas are berries. Strawberries, botanically speaking, aren't.",
        "An octopus has three hearts.",
        "A day on Venus lasts longer than its year.",
        "I'm running right here on your desktop. No account needed."
    ]
    Settings {
        id: prefs
        category: "BonziBuddy"
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/bonzi-buddy.ini"
        property bool muted: false
        property bool reducedMotion: false
        property int petSize: 192
        property real horizontal: 0.88
        property real vertical: 0.80
        property int monitor: 0
    }
    Speech { id: voice }
    function say(text) {
        if (!text.trim()) return
        hidden = false
        sleeping = false
        action = "idle"
        voice.stop()
        message = text.slice(0, 500)
        bubbleTimer.interval = Math.max(5000, Math.min(35000, message.length * 75))
        bubbleTimer.restart()
        if (!prefs.muted) voice.say(message)
    }
    function wave() {
        say("Hello there! I'm Bonzi. Drag me somewhere cosy, or right-click me for a little company.")
        action = "wave"
        actionTimer.restart()
    }
    function sleep() {
        voice.stop()
        bubbleTimer.stop()
        message = ""
        sleeping = !sleeping
        action = "idle"
        menuOpen = false
    }
    function hide() {
        voice.stop()
        message = ""
        hidden = true
        menuOpen = false
        bubbleTimer.stop()
    }
    function mute() {
        prefs.muted = !prefs.muted
        if (prefs.muted) voice.stop()
    }
    function joke() { say(jokes[jokeIndex++ % jokes.length]) }
    function fact() { say(facts[factIndex++ % facts.length]) }
    Timer { id: bubbleTimer; onTriggered: { if (voice.speaking) restart(); else root.message = "" } }
    Timer { id: actionTimer; interval: 2200; onTriggered: root.action = "idle" }
    Timer { interval: 900; running: true; onTriggered: root.wave() }

    IpcHandler {
        target: "bonzi"
        function show(): void { root.hidden = false; root.sleeping = false }
        function hide(): void { root.hide() }
        function toggle(): void { if (root.hidden) root.hidden = false; else root.hide() }
        function wave(): void { root.wave() }
        function joke(): void { root.joke() }
        function fact(): void { root.fact() }
        function sleep(): void { root.sleep() }
        function mute(): void { root.mute() }
        function menu(): void { root.hidden = false; root.menuOpen = !root.menuOpen }
        function say(text: string): void { root.say(text) }
        function quit(): void { voice.stop(); Qt.quit() }
        function size(pixels: int): void { prefs.petSize = Math.max(112, Math.min(288, pixels)) }
        function motion(reduced: bool): void { prefs.reducedMotion = reduced }
        function move(horizontal: real, vertical: real): void {
            prefs.horizontal = Math.max(0, Math.min(1, horizontal))
            prefs.vertical = Math.max(0, Math.min(1, vertical))
        }
        function status(): string {
            return JSON.stringify({hidden: root.hidden, sleeping: root.sleeping,
                muted: prefs.muted, reducedMotion: prefs.reducedMotion,
                size: prefs.petSize, pose: pet.pose, frame: pet.frame,
                message: root.message, menu: root.menuOpen,
                x: petArea.x, y: petArea.y, width: overlay.width, height: overlay.height,
                screen: overlay.screen ? overlay.screen.name : "",
                speaking: voice.speaking, speechError: voice.error})
        }
        // App-owned rendering capture for local QA; no other windows are captured.
        function capture(path: string): void {
            scene.grabToImage(function(result) { result.saveToFile(path) })
        }
    }

    PanelWindow {
        id: overlay
        screen: Quickshell.screens[Math.min(prefs.monitor, Quickshell.screens.length - 1)]
        visible: !root.hidden
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "bonzi-buddy"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            x: petArea.x + petArea.width * 0.10
            y: petArea.y + petArea.height * 0.04
            width: petArea.width * 0.80
            height: petArea.height * 0.94
            Region {
                x: bubble.x; y: bubble.y
                width: bubble.visible ? bubble.width : 0
                height: bubble.visible ? bubble.height : 0
            }
            Region {
                x: menu.x; y: menu.y
                width: menu.visible ? menu.width : 0
                height: menu.visible ? menu.height : 0
            }
        }
        Item {
            id: scene
            anchors.fill: parent
        Item {
            id: petArea
            width: prefs.petSize; height: width
            x: 12 + prefs.horizontal * Math.max(0, overlay.width - width - 24)
            y: 48 + prefs.vertical * Math.max(0, overlay.height - height - 64)
            PetSprite {
                id: pet
                anchors.fill: parent
                reducedMotion: prefs.reducedMotion
                pose: root.sleeping ? "sleep" : root.action !== "idle" ? root.action
                    : voice.speaking ? "speak" : "idle"
                transform: Scale {
                    origin.x: pet.width / 2; origin.y: pet.height
                    yScale: breathing.value
                }
            }
            QtObject { id: breathing; property real value: 1.0 }
            SequentialAnimation {
                running: !prefs.reducedMotion && !root.hidden
                loops: Animation.Infinite
                NumberAnimation { target: breathing; property: "value"; to: 0.98; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { target: breathing; property: "value"; to: 1; duration: 1800; easing.type: Easing.InOutSine }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property real startX
                property real startY
                property bool moved: false
                onPressed: function(mouse) {
                    start = mapToItem(overlay.contentItem, mouse.x, mouse.y)
                    startX = petArea.x; startY = petArea.y; moved = false
                }
                onPositionChanged: function(mouse) {
                    if (!pressed || pressedButtons !== Qt.LeftButton) return
                    const point = mapToItem(overlay.contentItem, mouse.x, mouse.y)
                    const dx = point.x - start.x, dy = point.y - start.y
                    if (Math.abs(dx) + Math.abs(dy) > 5) moved = true
                    if (!moved) return
                    root.menuOpen = false
                    prefs.horizontal = Math.max(0, Math.min(1, (startX + dx - 12) / Math.max(1, overlay.width - petArea.width - 24)))
                    prefs.vertical = Math.max(0, Math.min(1, (startY + dy - 48) / Math.max(1, overlay.height - petArea.height - 64)))
                }
                onClicked: function(mouse) {
                    if (moved) return
                    if (mouse.button === Qt.RightButton) root.menuOpen = !root.menuOpen
                    else if (root.sleeping) root.sleep()
                    else root.wave()
                }
                onDoubleClicked: { root.action = "celebrate"; actionTimer.restart() }
            }
            Text {
                visible: root.sleeping
                text: "z z z"; color: "#e5c6ff"; font.pixelSize: 22; font.bold: true
                anchors.right: parent.right; anchors.top: parent.top
            }
        }
        Rectangle {
            id: bubble
            visible: root.message !== "" && !root.menuOpen
            width: Math.min(300, overlay.width - 24)
            height: speechText.implicitHeight + 34
            x: Math.max(12, Math.min(overlay.width - width - 12, petArea.x + petArea.width / 2 - width / 2))
            y: petArea.y >= height + 20 ? petArea.y - height - 8 : petArea.y + petArea.height + 8
            radius: 14; color: "#fffbe9"; border.color: "#6d507d"; border.width: 2
            Text {
                id: speechText
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                text: root.message; color: "#35263e"; font.pixelSize: 13
                font.family: "sans-serif"; wrapMode: Text.WordWrap
            }
            MouseArea { anchors.fill: parent; onClicked: { root.message = ""; voice.stop() } }
        }
        Rectangle {
            id: menu
            visible: root.menuOpen
            width: Math.min(284, overlay.width - 24)
            height: menuContent.implicitHeight + 28
            x: Math.max(12, Math.min(overlay.width - width - 12, petArea.x + petArea.width / 2 - width / 2))
            y: Math.max(12, Math.min(overlay.height - height - 12, petArea.y - height - 8))
            radius: 16; color: "#f223192c"; border.color: "#755285"; border.width: 1
            ColumnLayout {
                id: menuContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 9
                RowLayout {
                    Text { text: "BONZI"; color: "#f1e2ff"; font.pixelSize: 17; font.bold: true; font.letterSpacing: 2; Layout.fillWidth: true }
                    ActionButton { text: "×"; implicitWidth: 30; onClicked: root.menuOpen = false }
                }
                Text { text: root.sleeping ? "A little nap. A big dream." : "A little company for your desktop."; color: "#bc9dce"; font.pixelSize: 11 }
                RowLayout {
                    ActionButton { text: "Tell a joke"; accent: true; Layout.fillWidth: true; onClicked: { root.menuOpen = false; root.joke() } }
                    ActionButton { text: "Fun fact"; Layout.fillWidth: true; onClicked: { root.menuOpen = false; root.fact() } }
                }
                RowLayout {
                    ActionButton { text: prefs.muted ? "Unmute" : "Mute"; Layout.fillWidth: true; onClicked: root.mute() }
                    ActionButton { text: root.sleeping ? "Wake up" : "Take a nap"; Layout.fillWidth: true; onClicked: root.sleep() }
                }
                Text { text: "SIZE  ·  " + prefs.petSize + " px"; color: "#bc9dce"; font.pixelSize: 10; font.letterSpacing: 1 }
                Slider {
                    Layout.fillWidth: true; from: 112; to: 288; stepSize: 8
                    value: prefs.petSize; onMoved: prefs.petSize = value
                }
                ActionButton { text: prefs.reducedMotion ? "Motion: reduced" : "Motion: animated"; Layout.fillWidth: true; onClicked: prefs.reducedMotion = !prefs.reducedMotion }
                ActionButton {
                    visible: Quickshell.screens.length > 1
                    text: "Move to next monitor"; Layout.fillWidth: true
                    onClicked: prefs.monitor = (prefs.monitor + 1) % Quickshell.screens.length
                }
                Text {
                    visible: voice.error !== ""
                    text: "Voice unavailable · speech bubbles still work"
                    color: "#eabe8b"; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }
                RowLayout {
                    ActionButton { text: "Hide"; Layout.fillWidth: true; onClicked: root.hide() }
                    ActionButton { text: "Quit"; Layout.fillWidth: true; onClicked: { voice.stop(); Qt.quit() } }
                }
                Text { text: "Bring me back: bonzi show"; color: "#947e9d"; font.pixelSize: 10 }
            }
        }
    }
    }
}
