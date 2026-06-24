import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var values: []

    implicitWidth: 90
    implicitHeight: 28

    Process {
        id: cava

        running: true

        command: [
            "cava",
            "-p",
            "/home/aizen/caelestia-mods/island/cava.conf"
        ]

        stdout: SplitParser {
            onRead: data => {
                root.values = data.trim().split(";")
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Math.min(root.values.length, 20)

            Rectangle {
                required property int index

                width: 3

                height: {
                    const v = parseInt(root.values[index]) || 0
                    return Math.max(2, v / 3)
                }

                radius: width / 2

                color: "white"

                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
