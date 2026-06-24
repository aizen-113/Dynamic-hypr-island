import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string title: ""
    property string artist: ""

    Process {
        id: titleProc

        command: ["mpc", "--format", "%title%"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.title = text.split("\n")[0]
            }
        }
    }

    Process {
        id: artistProc

        command: ["mpc", "--format", "%artist%"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.artist = text.split("\n")[0]
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            titleProc.running = true
            artistProc.running = true
        }
    }
}
