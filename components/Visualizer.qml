import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var values: []

    implicitWidth: 90
    implicitHeight: 28


    
    property string cavaConfigPath: ""

    
    Component.onCompleted: {
        let url = Qt.resolvedUrl("../cava.conf").toString();
        root.cavaConfigPath = url.replace("file://", "");
        console.log("[Dynamic Island] Resolved Cava Path: " + root.cavaConfigPath);
        cava.running = true;
    }

    Process {
        id: cava

        running: false

        command: [
            "cava",
            "-p",
            root.cavaConfigPath
        ]

        stdout: SplitParser {
            onRead: data => {
                root.values = data.trim().split(";")
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("[Dynamic Island] Cava Error: " + text.trim());
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        height: parent.height
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
                transformOrigin: Item.Center
            }
        }
    }
}
