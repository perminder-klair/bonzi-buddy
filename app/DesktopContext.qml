import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: context
    required property var preferences
    readonly property string fixture: Quickshell.env("BONZI_CONTEXT_FIXTURE")
    property var snapshot: ({})
    property double receivedAt: 0
    property double now: Date.now()
    readonly property bool stale: now - receivedAt > 12000
    readonly property var desktop: {
        if (stale) return ({})
        const source = snapshot.desktop || {}
        let result = {available: source.available, fullscreen: source.fullscreen, blockedApp: source.blockedApp}
        if (preferences.windowsEnabled) {
            for (const key of ["app", "workspace", "side", "monitor", "rect", "cursor"]) result[key] = source[key]
            if (preferences.windowTitles) result.title = source.title
        }
        return result
    }
    readonly property var system: preferences.systemEnabled && !stale ? (snapshot.system || {}) : ({})
    readonly property var dnd: preferences.dndQuiet && !stale ? snapshot.dnd : null
    readonly property var media: !preferences.mediaEnabled ? ({}) : fixture
        ? (stale ? ({}) : snapshot.media || {}) : mediaLoader.item ? mediaLoader.item.snapshot : ({})
    readonly property bool idle: preferences.idleEnabled && (fixture ? !stale && !!snapshot.idle : idleMonitor.isIdle)
    readonly property var collectorCommand: {
        let args = ["python3", Quickshell.shellPath("../bin/context.py")]
        if (fixture) return args.concat(["--fixture", fixture])
        if (preferences.windowsEnabled) args.push("--windows")
        if (preferences.windowTitles && preferences.windowsEnabled) args.push("--titles")
        if (preferences.fullscreenQuiet || preferences.hideFullscreen) args.push("--fullscreen")
        if (preferences.focusApps.trim()) args.push("--blocked-apps", preferences.focusApps)
        if (preferences.systemEnabled) args.push("--system")
        if (preferences.dndQuiet) args.push("--dnd")
        return args
    }
    onCollectorCommandChanged: {
        snapshot = ({}); receivedAt = 0
        collector.running = false
        restart.restart()
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: context.now = Date.now() }
    Timer {
        id: restart; interval: 250
        onTriggered: {
            if (collector.running) { restart(); return }
            collector.command = context.collectorCommand
            collector.running = true
        }
    }
    Process {
        id: collector
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    context.snapshot = JSON.parse(data)
                    context.receivedAt = Date.now()
                    context.now = Date.now()
                } catch (_) { console.warn("Invalid context sample ignored") }
            }
        }
        onExited: { context.receivedAt = 0; restart.interval = 2000; restart.restart() }
    }
    Loader { id: mediaLoader; active: context.preferences.mediaEnabled && !context.fixture; source: "MediaContext.qml" }
    IdleMonitor {
        id: idleMonitor
        enabled: context.preferences.idleEnabled && !context.fixture
        timeout: context.preferences.idleSeconds
        respectInhibitors: true
    }
    Component.onCompleted: restart.restart()
}
