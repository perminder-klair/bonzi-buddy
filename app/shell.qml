import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "ReactionRules.js" as Rules

ShellRoot {
    id: root
    property bool hidden: false
    property bool sleeping: false
    property bool menuOpen: false
    property string message: ""
    property string action: "idle"
    property bool autoSleep: false
    property bool dancing: false
    property double danceUntil: 0
    property double lastReactionAt: 0
    property string lastReaction: ""
    property double dragUntil: 0
    property bool dragging: false
    property var parkedPosition: null
    property double lastAvoidAt: 0
    property int danceVariant: 0
    property bool wasPlaying: false
    property bool wasIdle: false
    property string previousApp: ""
    property double pressureSince: 0
    property bool pressureReported: false
    readonly property int screenCount: Quickshell.screens.length
    readonly property string focusReason: sensors.stale && (prefs.fullscreenQuiet || prefs.dndQuiet || prefs.focusApps)
        ? "Checking focus" : Rules.focusReason(sensors.desktop, sensors.dnd, prefs)
    readonly property bool fullscreenHidden: prefs.hideFullscreen && !!sensors.desktop.fullscreen
    readonly property var chosenScreen: {
        if (prefs.windowsEnabled && prefs.movement === "follow" && sensors.desktop.monitor) {
            for (let i = 0; i < Quickshell.screens.length; i++)
                if (Quickshell.screens[i].name === sensors.desktop.monitor.name) return Quickshell.screens[i]
        }
        return Quickshell.screens[Math.max(0, Math.min(prefs.monitor, Quickshell.screens.length - 1))]
    }
    onFocusReasonChanged: {
        if (focusReason) { voice.stop(); message = ""; action = "idle"; dancing = false }
    }
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
        location: Quickshell.env("BONZI_SETTINGS_FILE") || StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/bonzi-buddy.ini"
        property bool muted: false
        property bool reducedMotion: false
        property int petSize: 192
        property real horizontal: 0.88
        property real vertical: 0.80
        property int monitor: 0
        property bool windowsEnabled: true
        property bool mediaEnabled: true
        property bool systemEnabled: true
        property bool idleEnabled: true
        property bool windowTitles: false
        property bool fullscreenQuiet: true
        property bool hideFullscreen: true
        property bool dndQuiet: true
        property string focusApps: ""
        property string movement: "stay"
        property string personality: "balanced"
        property int cooldownSeconds: 120
        property int idleSeconds: 300
        property string musicRule: "dance"
        property string idleRule: "sleep"
        property string appRule: "none"
        property string healthRule: "speak"
    }
    Speech { id: voice }
    DesktopContext { id: sensors; preferences: prefs }
    function quit() { voice.stop(); Qt.quit() }
    function settingsSnapshot() {
        let result = {}
        for (const key of ["windowsEnabled", "mediaEnabled", "systemEnabled", "idleEnabled", "windowTitles", "fullscreenQuiet", "hideFullscreen", "dndQuiet", "focusApps", "movement", "personality", "cooldownSeconds", "idleSeconds", "musicRule", "idleRule", "appRule", "healthRule"]) result[key] = prefs[key]
        return result
    }
    function setOption(name, value) {
        const booleans = ["windowsEnabled", "mediaEnabled", "systemEnabled", "idleEnabled", "windowTitles", "fullscreenQuiet", "hideFullscreen", "dndQuiet"]
        if (booleans.indexOf(name) >= 0) {
            if (value !== "true" && value !== "false") return "Expected true or false"
            prefs[name] = value === "true"
        } else if (name === "movement") {
            if (["stay", "follow", "avoid"].indexOf(value) < 0) return "Expected stay, follow or avoid"
            prefs.movement = value
        } else if (name === "personality") {
            if (["quiet", "balanced", "chatty"].indexOf(value) < 0) return "Expected quiet, balanced or chatty"
            prefs.personality = value
            prefs.cooldownSeconds = value === "quiet" ? 600 : value === "balanced" ? 120 : 30
        } else if (["musicRule", "idleRule", "appRule", "healthRule"].indexOf(name) >= 0) {
            if (["none", "dance", "wave", "speak", "sleep"].indexOf(value) < 0) return "Unknown reaction"
            prefs[name] = value
        } else if (name === "cooldownSeconds" || name === "idleSeconds") {
            const number = Number(value), minimum = name === "idleSeconds" ? 30 : 10
            if (!Number.isInteger(number) || number < minimum || number > 3600) return "Value outside allowed range"
            prefs[name] = number
        } else if (name === "focusApps") prefs.focusApps = value.trim().slice(0, 500)
        else return "Unknown setting"
        return "ok"
    }
    function react(event, rule, text) {
        if (rule === "none" || !Rules.canReact({hidden: hidden || menuOpen, sleeping: sleeping,
            focus: focusReason, personality: prefs.personality, last: lastReactionAt,
            now: Date.now(), cooldown: prefs.cooldownSeconds})) return
        lastReactionAt = Date.now()
        lastReaction = event + " → " + rule
        if (rule === "sleep") { voice.stop(); sleeping = true; autoSleep = event === "You become idle"; message = "" }
        else if (rule === "dance") { dancing = true; danceVariant = (danceVariant + 1) % 3; danceUntil = Date.now() + 3600 }
        else if (rule === "wave") { action = "wave"; actionTimer.restart() }
        else if (rule === "speak") say(text)
    }
    function observe() {
        if (!sensors.stale && !sensors.idle && autoSleep) { sleeping = false; autoSleep = false }
        if (prefs.personality === "quiet") dancing = false
        const playing = !!sensors.media.playing
        if (!playing || !prefs.mediaEnabled || prefs.personality === "quiet" || prefs.musicRule !== "dance") {
            if (danceUntil === 0) dancing = false
        }
        if (danceUntil && Date.now() > danceUntil) dancing = false
        if (sensors.stale) return
        if (prefs.movement !== "avoid" || !prefs.windowsEnabled) parkedPosition = null
        else if (Rules.canAvoid({menu: menuOpen, dragging: dragging, hovered: petMouse.containsMouse,
            now: Date.now(), dragUntil: dragUntil, lastMove: lastAvoidAt, sampleAge: Date.now() - sensors.receivedAt,
            cursor: sensors.desktop.cursor, x: petArea.x, y: petArea.y, size: petArea.width})) {
            const desktop = sensors.desktop
            if (desktop.monitor && overlay.screen && desktop.monitor.name === overlay.screen.name) {
                const current = {x: petArea.x, y: petArea.y}
                const next = Rules.avoidWindow(current, petArea.width, {width: overlay.width, height: overlay.height}, desktop.rect)
                if (next.x !== current.x || next.y !== current.y) { parkedPosition = next; lastAvoidAt = Date.now() }
            }
        }
        if (playing && !wasPlaying) react("Music starts", prefs.musicRule, "You've got music playing. I'll keep you company.")
        if (sensors.idle && !wasIdle) react("You become idle", prefs.idleRule, "Time for a little break.")
        const app = sensors.desktop.app || ""
        if (prefs.windowsEnabled && app && previousApp && app !== previousApp)
            react("Active app changes", prefs.appRule, "You've switched to " + app + ".")
        wasPlaying = playing; wasIdle = sensors.idle; previousApp = app
        const system = sensors.system
        const pressure = prefs.systemEnabled && ((system.cpu !== null && system.cpu >= 90)
            || (system.memory && system.memory.percent >= 90)
            || (system.disk && system.disk.freeGiB < 2)
            || (system.battery && system.battery.percent <= 15 && system.battery.state === "Discharging"))
        if (!pressure) { pressureSince = 0; pressureReported = false }
        else if (!pressureSince) pressureSince = Date.now()
        else if (!pressureReported && Date.now() - pressureSince >= 30000) {
            const before = lastReactionAt
            react("Sustained system pressure", prefs.healthRule, "Your system could use some attention. Have a look at my status panel.")
            pressureReported = lastReactionAt !== before
        }
    }
    Timer { interval: 500; running: true; repeat: true; onTriggered: root.observe() }
    function say(text) {
        if (!text.trim()) return
        hidden = false
        sleeping = false
        autoSleep = false
        action = "idle"
        voice.stop()
        message = text.slice(0, 500)
        bubbleTimer.interval = Math.max(5000, Math.min(35000, message.length * 75))
        bubbleTimer.restart()
        if (!prefs.muted && !focusReason) voice.say(message)
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
        autoSleep = false
        sleeping = !sleeping
        dancing = false
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
    Timer { interval: 1200; running: true; onTriggered: { if (!root.focusReason && prefs.personality !== "quiet") root.wave() } }

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
        function quit(): void { root.quit() }
        function option(name: string, value: string): string { return root.setOption(name, value) }
        function panel(tab: int): void { root.hidden = false; root.menuOpen = true; menu.tab = Math.max(0, Math.min(3, tab)) }
        function size(pixels: int): void { prefs.petSize = Math.max(112, Math.min(288, pixels)) }
        function motion(reduced: bool): void { prefs.reducedMotion = reduced }
        function move(horizontal: real, vertical: real): void {
            root.parkedPosition = null
            root.dragUntil = Date.now() + 30000
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
                speaking: voice.speaking, speechError: voice.error,
                focusReason: root.focusReason, fullscreenHidden: root.fullscreenHidden,
                dancing: root.dancing, lastReaction: root.lastReaction,
                preferences: root.settingsSnapshot(),
                context: {stale: sensors.stale, simulated: !!sensors.fixture, desktop: sensors.desktop,
                    system: sensors.system, media: sensors.media, idle: sensors.idle, dnd: sensors.dnd}})
        }
        // App-owned rendering capture for local QA; no other windows are captured.
        function capture(path: string): void {
            scene.grabToImage(function(result) { result.saveToFile(path) })
        }
    }

    PanelWindow {
        id: overlay
        screen: root.chosenScreen
        visible: !root.hidden && (!root.fullscreenHidden || root.menuOpen)
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "bonzi-buddy"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
            readonly property var homePosition: ({x: 12 + prefs.horizontal * Math.max(0, overlay.width - width - 24), y: 48 + prefs.vertical * Math.max(0, overlay.height - height - 64)})
            readonly property var safePosition: root.parkedPosition && prefs.movement === "avoid" && !root.dragging ? root.parkedPosition : homePosition
            x: Math.max(12, Math.min(overlay.width - width - 12, safePosition.x))
            y: Math.max(16, Math.min(overlay.height - height - 16, safePosition.y))
            PetSprite {
                id: pet
                anchors.fill: parent
                reducedMotion: prefs.reducedMotion
                danceVariant: root.danceVariant
                pose: root.sleeping ? "sleep" : root.action !== "idle" ? root.action
                    : voice.speaking ? "speak" : root.dancing && !root.focusReason ? "dance" : "idle"
                rotation: danceMotion.angle
                transform: Scale {
                    origin.x: pet.width / 2; origin.y: pet.height
                    yScale: breathing.value
                }
            }
            QtObject { id: danceMotion; property real angle: 0 }
            SequentialAnimation {
                running: pet.pose === "dance" && !prefs.reducedMotion && overlay.visible
                loops: Animation.Infinite
                onRunningChanged: { if (!running) danceMotion.angle = 0 }
                NumberAnimation { target: danceMotion; property: "angle"; to: root.danceVariant === 1 ? -4 : -7; duration: 420; easing.type: Easing.InOutSine }
                NumberAnimation { target: danceMotion; property: "angle"; to: root.danceVariant === 1 ? 4 : 7; duration: 420; easing.type: Easing.InOutSine }
            }
            QtObject { id: breathing; property real value: 1.0 }
            SequentialAnimation {
                running: !prefs.reducedMotion && overlay.visible
                loops: Animation.Infinite
                NumberAnimation { target: breathing; property: "value"; to: 0.98; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { target: breathing; property: "value"; to: 1; duration: 1800; easing.type: Easing.InOutSine }
            }
            MouseArea {
                id: petMouse
                hoverEnabled: true
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
                    prefs.horizontal = Math.max(0, Math.min(1, (startX - 12) / Math.max(1, overlay.width - petArea.width - 24)))
                    prefs.vertical = Math.max(0, Math.min(1, (startY - 48) / Math.max(1, overlay.height - petArea.height - 64)))
                    root.parkedPosition = null
                    root.dragging = true
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
                onReleased: { root.dragging = false; root.parkedPosition = null; root.dragUntil = Date.now() + 30000 }
                onCanceled: root.dragging = false
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
        ContextPanel {
            id: menu
            buddy: root; preferences: prefs; context: sensors
            visible: root.menuOpen
            width: Math.min(390, overlay.width - 24)
            height: Math.min(580, overlay.height - 24)
            x: Math.max(12, Math.min(overlay.width - width - 12, petArea.x + petArea.width / 2 - width / 2))
            y: Math.max(12, Math.min(overlay.height - height - 12, petArea.y - height - 8))
        }
        }
    }
}
