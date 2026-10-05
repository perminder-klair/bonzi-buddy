import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: panel
    required property var buddy
    required property var preferences
    required property var context
    property int tab: 0
    radius: 16; color: "#fa23192c"; border.color: "#755285"; border.width: 1
    function percent(value) { return value === undefined || value === null ? "Unavailable" : Math.round(value) + "%" }
    function setPersonality(index) {
        preferences.personality = ["quiet", "balanced", "chatty"][index]
        preferences.cooldownSeconds = [600, 120, 30][index]
    }
    component Caption: Text {
        color: "#b9a0c9"; font.pixelSize: 10; font.letterSpacing: 1
        Layout.fillWidth: true; topPadding: 8
    }
    component Reading: ColumnLayout {
        property string label
        property string value
        spacing: 3
        Text { text: parent.label; color: "#aa8fbc"; font.pixelSize: 10 }
        Text { text: parent.value; color: "#f2e6ff"; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.PlainText }
    }
    component Rule: RowLayout {
        property string label
        property string preference
        Text { text: parent.label; color: "#eadcf5"; font.pixelSize: 12; Layout.fillWidth: true }
        ComboBox {
            model: ["none", "dance", "wave", "speak", "sleep"]
            currentIndex: Math.max(0, model.indexOf(panel.preferences[parent.preference]))
            onActivated: panel.preferences[parent.preference] = currentText
            implicitWidth: 115
        }
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 10
        RowLayout {
            Text { text: "BONZI"; color: "#f1e2ff"; font.pixelSize: 17; font.bold: true; font.letterSpacing: 2; Layout.fillWidth: true }
            Text { text: panel.context.fixture ? "SIMULATED" : "LOCAL"; color: "#c7a5e8"; font.pixelSize: 9 }
            ActionButton { text: "×"; implicitWidth: 30; onClicked: panel.buddy.menuOpen = false }
        }
        RowLayout {
            Repeater {
                model: ["Buddy", "Awareness", "Status", "Reactions"]
                ActionButton { required property int index; required property string modelData; text: modelData; accent: panel.tab === index; Layout.fillWidth: true; onClicked: panel.tab = index }
            }
        }
        Text {
            text: panel.buddy.focusReason ? "Quiet · " + panel.buddy.focusReason : "A little company for your desktop."
            color: panel.buddy.focusReason ? "#efc688" : "#bc9dce"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: parent.width; spacing: 10
                ColumnLayout {
                    visible: panel.tab === 0; Layout.fillWidth: true; spacing: 10
                    RowLayout {
                        ActionButton { text: "Tell a joke"; accent: true; Layout.fillWidth: true; onClicked: { panel.buddy.menuOpen = false; panel.buddy.joke() } }
                        ActionButton { text: "Fun fact"; Layout.fillWidth: true; onClicked: { panel.buddy.menuOpen = false; panel.buddy.fact() } }
                    }
                    RowLayout {
                        ActionButton { text: panel.preferences.muted ? "Unmute" : "Mute"; Layout.fillWidth: true; onClicked: panel.buddy.mute() }
                        ActionButton { text: panel.buddy.sleeping ? "Wake up" : "Take a nap"; Layout.fillWidth: true; onClicked: panel.buddy.sleep() }
                    }
                    Caption { text: "SIZE · " + panel.preferences.petSize + " px" }
                    Slider { Layout.fillWidth: true; from: 112; to: 288; stepSize: 8; value: panel.preferences.petSize; onMoved: panel.preferences.petSize = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "Reduced motion"; checked: panel.preferences.reducedMotion; onToggled: value => panel.preferences.reducedMotion = value }
                    Caption { text: "MOVEMENT" }
                    ComboBox {
                        Layout.fillWidth: true; model: ["Stay put", "Follow active monitor", "Avoid active windows"]
                        currentIndex: ["stay", "follow", "avoid"].indexOf(panel.preferences.movement)
                        onActivated: panel.preferences.movement = ["stay", "follow", "avoid"][currentIndex]
                    }
                    Text { text: "Automatic movement needs window awareness. Avoidance pauses near your pointer and while this panel is open; moves are at least 30 seconds apart."; color: "#a38cb0"; font.pixelSize: 10; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    Caption { text: "PERSONALITY" }
                    ComboBox {
                        Layout.fillWidth: true; model: ["Quiet", "Balanced", "Chatty"]
                        currentIndex: ["quiet", "balanced", "chatty"].indexOf(panel.preferences.personality)
                        onActivated: panel.setPersonality(currentIndex)
                    }
                    Reading { label: "Automatic reactions"; value: panel.preferences.personality === "quiet" ? "Off · manual actions still work" : "At most once every " + panel.preferences.cooldownSeconds + " seconds" }
                    ActionButton { text: "Move to next monitor"; visible: panel.buddy.screenCount > 1; Layout.fillWidth: true; onClicked: { panel.preferences.movement = "stay"; panel.preferences.monitor = (panel.preferences.monitor + 1) % panel.buddy.screenCount } }
                }
                ColumnLayout {
                    visible: panel.tab === 1; Layout.fillWidth: true
                    Caption { text: "AWARENESS" }
                    PreferenceToggle { Layout.fillWidth: true; text: "Windows"; description: "App, workspace, monitor and window position"; checked: panel.preferences.windowsEnabled; onToggled: value => panel.preferences.windowsEnabled = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "Media"; description: "Playback state, player, artist and track"; checked: panel.preferences.mediaEnabled; onToggled: value => panel.preferences.mediaEnabled = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "System health"; description: "CPU, RAM, home disk, power and link state"; checked: panel.preferences.systemEnabled; onToggled: value => panel.preferences.systemEnabled = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "Idle awareness"; description: "Time without input; never records keystrokes"; checked: panel.preferences.idleEnabled; onToggled: value => panel.preferences.idleEnabled = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "Notifications · deferred"; description: "No notification content is read"; enabled: false }
                    Caption { text: "FOCUS MODE" }
                    PreferenceToggle { Layout.fillWidth: true; text: "Silence during fullscreen"; checked: panel.preferences.fullscreenQuiet; onToggled: value => panel.preferences.fullscreenQuiet = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "Hide during fullscreen"; checked: panel.preferences.hideFullscreen; onToggled: value => panel.preferences.hideFullscreen = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "Respect Do Not Disturb"; description: "Reads only Omarchy's on/off setting"; checked: panel.preferences.dndQuiet; onToggled: value => panel.preferences.dndQuiet = value }
                    Text { text: "Quiet apps · exact app classes, comma-separated"; color: "#b9a0c9"; font.pixelSize: 10 }
                    TextField { Layout.fillWidth: true; placeholderText: "e.g. kitty, org.obsproject.Studio"; text: panel.preferences.focusApps; selectByMouse: true; onEditingFinished: panel.preferences.focusApps = text.trim() }
                    Caption { text: "PRIVACY" }
                    PreferenceToggle { Layout.fillWidth: true; text: "Read window titles"; description: "Off by default. Titles can contain document names."; checked: panel.preferences.windowTitles; onToggled: value => panel.preferences.windowTitles = value }
                    PreferenceToggle { Layout.fillWidth: true; text: "Read notification bodies · deferred"; enabled: false }
                    Text { text: "All processing stays on this computer. No activity history is saved. Focus mode can read minimal fullscreen/app-match state even with window awareness off."; color: "#a38cb0"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                }
                ColumnLayout {
                    visible: panel.tab === 2; Layout.fillWidth: true; spacing: 14
                    Caption { text: "WHAT BUDDY CAN CURRENTLY SEE" }
                    Reading { label: "Context collector"; value: panel.context.stale ? "Unavailable / reconnecting" : "Live · local updates" }
                    Reading { label: "Active app"; value: !panel.preferences.windowsEnabled ? "Window awareness off" : panel.context.desktop.available ? panel.context.desktop.app || "Desktop" : "Unavailable" }
                    Reading { label: "Window title"; value: !panel.preferences.windowTitles ? "Private · access off" : !panel.preferences.windowsEnabled ? "Window awareness off" : panel.context.desktop.title || "No title" }
                    Reading { label: "Position / workspace"; value: !panel.preferences.windowsEnabled ? "Off" : (panel.context.desktop.side || "Unknown") + " · workspace " + (panel.context.desktop.workspace || "—") + " · " + (panel.context.desktop.monitor ? panel.context.desktop.monitor.name : "no monitor") }
                    Reading { label: "Focus / idle"; value: (panel.buddy.focusReason || "Available") + " · " + (panel.context.idle ? "idle" : "active") }
                    Reading { label: "Do Not Disturb"; value: !panel.preferences.dndQuiet ? "Not monitored" : panel.context.dnd === true ? "On" : panel.context.dnd === false ? "Off" : "Unavailable" }
                    Reading { label: "Media"; value: !panel.preferences.mediaEnabled ? "Off" : panel.context.media.available ? (panel.context.media.playing ? "Playing · " : "Paused · ") + panel.context.media.player + "\n" + (panel.context.media.title || "Unknown track") + (panel.context.media.artist ? " — " + panel.context.media.artist : "") : "No compatible player" }
                    Reading { label: "CPU / RAM"; value: !panel.preferences.systemEnabled ? "Off" : panel.percent(panel.context.system.cpu) + " CPU · " + panel.percent(panel.context.system.memory ? panel.context.system.memory.percent : null) + " RAM" }
                    Reading { label: "Home filesystem"; value: !panel.preferences.systemEnabled ? "Off" : panel.context.system.disk ? panel.context.system.disk.freeGiB + " GiB free · " + panel.percent(panel.context.system.disk.percent) + " used" : "Unavailable" }
                    Reading { label: "Power / network"; value: !panel.preferences.systemEnabled ? "Off" : (panel.context.system.battery ? panel.context.system.battery.percent + "% · " + panel.context.system.battery.state : "No battery reported") + "\n" + (panel.context.system.networkLink === undefined ? "Network unknown" : panel.context.system.networkLink ? "Network link up (internet not tested)" : "No active network link") }
                    Reading { label: "Last reaction"; value: panel.buddy.lastReaction || "None yet" }
                    Reading { label: "Notifications"; value: "Not connected" }
                }
                ColumnLayout {
                    visible: panel.tab === 3; Layout.fillWidth: true; spacing: 12
                    Caption { text: "WHEN THIS HAPPENS → DO THIS" }
                    Rule { Layout.fillWidth: true; label: "Music starts"; preference: "musicRule" }
                    Rule { Layout.fillWidth: true; label: "You become idle"; preference: "idleRule" }
                    Rule { Layout.fillWidth: true; label: "Active app changes"; preference: "appRule" }
                    Rule { Layout.fillWidth: true; label: "Sustained system pressure"; preference: "healthRule" }
                    Text { text: "Rules use enabled awareness sources and respect focus mode, manual sleep, and cooldowns. Quiet personality disables automatic reactions. Idle sleep wakes when you return. Dances last 3.6 seconds, with varied moves."; color: "#a38cb0"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    Caption { text: "MINIMUM SECONDS BETWEEN REACTIONS" }
                    SpinBox { from: 10; to: 3600; stepSize: 10; value: panel.preferences.cooldownSeconds; onValueModified: panel.preferences.cooldownSeconds = value }
                    Caption { text: "IDLE AFTER (SECONDS)" }
                    SpinBox { from: 30; to: 3600; stepSize: 30; value: panel.preferences.idleSeconds; onValueModified: panel.preferences.idleSeconds = value }
                    Reading { label: "Health threshold"; value: "CPU or RAM ≥90%, home disk <2 GiB free, or discharging battery ≤15%, sustained for 30 seconds." }
                }
            }
        }
        RowLayout {
            ActionButton { text: "Hide"; Layout.fillWidth: true; onClicked: panel.buddy.hide() }
            ActionButton { text: "Quit"; Layout.fillWidth: true; onClicked: panel.buddy.quit() }
        }
    }
}
