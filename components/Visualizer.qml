
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Data-only output interface
    property var output: ({
        active: false,
        levels: []
    })

    readonly property string configPath:
        Qt.resolvedUrl("../cava.conf").toString().replace("file://", "")

    function publishLevels(line) {
        const cleanLine = line.trim();

        if (cleanLine.length === 0)
            return;

        const levels = cleanLine.split(";").map(value => {
            const parsed = parseInt(value, 10);
            return Number.isFinite(parsed) ? parsed : 0;
        });

        root.output = {
            active: levels.some(value => value > 5),
            levels: levels
        };
    }

    property var process: Process {
        id: cavaProcess

        command: ["cava", "-p", root.configPath]
        running: root.configPath.length > 0

        stdout: SplitParser {
            onRead: data => root.publishLevels(data)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.log(
                        "[Visualizer Backend] " + text.trim()
                    );
                }
            }
        }
    }
}
