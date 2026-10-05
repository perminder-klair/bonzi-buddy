import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: speech
    readonly property bool speaking: worker.running
    property string pending: ""
    property string error: ""
    property bool cancelled: false
    function say(text) {
        speech.stop()
        error = ""
        pending = text
        launch.start()
    }
    function stop() {
        pending = ""
        launch.stop()
        cancelled = true
        if (worker.running) worker.running = false
    }
    Timer {
        id: launch
        interval: 50
        repeat: true
        onTriggered: {
            if (worker.running) return
            if (speech.pending) {
                const text = speech.pending
                speech.pending = ""
                speech.cancelled = false
                worker.command = ["flite", "-voice", "kal", "--setf", "int_f0_target_mean=135", "-t", text]
                worker.running = true
            }
            launch.stop()
        }
    }
    Process {
        id: worker
        onExited: function(exitCode, exitStatus) {
            if (!speech.cancelled && (exitCode !== 0 || exitStatus !== 0)) {
                speech.error = "Local speech could not play. Check that flite and desktop audio are available."
                console.warn(speech.error)
            }
        }
    }
    Component.onDestruction: stop()
}
