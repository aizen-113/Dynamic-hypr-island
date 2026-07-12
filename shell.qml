import QtQuick
import Quickshell
import Quickshell.Wayland
import "./components"
import Quickshell.Io


PanelWindow {
    id: root

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true

    implicitWidth: 480
    implicitHeight: 80

    Animation {
        id: anim
    }

    MusicInfo {
        id: music
    }

    Rectangle {
        id: island

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: anim.topMargin

        property bool hovered: false
        property real cpu: 0
        property real ram: 0
        property bool musicPlaying: false
        property int coverVersion: 0
        property string coverPath: "/tmp/cover.png"

        property real prevTotal: 0
        property real prevIdle: 0

        width: hovered ? 420 : 180
        height: hovered ? 56 : 40
        layer.enabled: true
        radius: height / 2

        color: "#cc000000"
        border.width: 1
        border.color: "#dd222222"
       
        z: -1

        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: island.hovered = true
            onExited: island.hovered = false
        }

        onHoveredChanged: {
            if (hovered) {
                island.prevTotal = 0;
                island.prevIdle = 0;
                sysStatsProc.running = true;
            }
        }
        
        Process {
            id: sysStatsProc

            command: [
                "sh",
                "-c",
                "cat /proc/stat | grep '^cpu ' && cat /proc/meminfo | grep -E 'MemTotal|MemAvailable'"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n");
                    if (lines.length >= 3) {
                        // --- Parse CPU lines ---
                        let cpuParts = lines[0].replace(/\s+/g, ' ').split(' ');
                        let user = parseFloat(cpuParts[1]) || 0;
                        let nice = parseFloat(cpuParts[2]) || 0;
                        let system = parseFloat(cpuParts[3]) || 0;
                        let idle = parseFloat(cpuParts[4]) || 0;
                        let iowait = parseFloat(cpuParts[5]) || 0;
                        let irq = parseFloat(cpuParts[6]) || 0;
                        let softirq = parseFloat(cpuParts[7]) || 0;
                        let steal = parseFloat(cpuParts[8]) || 0;

                        let total = user + nice + system + idle + iowait + irq + softirq + steal;
                        let idleTime = idle + iowait;

                        if (island.prevTotal > 0) {
                            let diffTotal = total - island.prevTotal;
                            let diffIdle = idleTime - island.prevIdle;
                            if (diffTotal > 0) {
                                // Set island.cpu to actual usage percent!
                                island.cpu = Math.max(0, Math.min(100, ((diffTotal - diffIdle) / diffTotal) * 100));
                            }
                        }
                        island.prevTotal = total;
                        island.prevIdle = idleTime;

                        // --- Parse Memory lines ---
                        let totalMem = 0;
                        let availMem = 0;
                        for (let i = 1; i < lines.length; i++) {
                            if (lines[i].includes("MemTotal:")) {
                                totalMem = parseFloat(lines[i].replace(/[^0-9]/g, '')) || 0;
                            } else if (lines[i].includes("MemAvailable:")) {
                                availMem = parseFloat(lines[i].replace(/[^0-9]/g, '')) || 0;
                            }
                        }
                        if (totalMem > 0) {
                            // Set island.ram to actual memory usage percent!
                            island.ram = Math.max(0, Math.min(100, ((totalMem - availMem) / totalMem) * 100));
                        }
                    }
                }
            }
        }

        Timer {
            interval: 1000
            running: island.hovered
            repeat: true

            onTriggered: {
                sysStatsProc.running = true;
            }
        }

        Process {
            id: musicCheck

            command: [
                "sh",
                "-c",
                "mpc status | grep '\\[playing\\]'"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    island.musicPlaying = text.length > 0
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true

            onTriggered: {
                musicCheck.running = true
            }
        }


        Timer {
             id: updateCover

             interval: 150
             repeat: false

             onTriggered: {
                 island.coverVersion++
             }
        }

        Timer {
            id: coverDelay
            interval: 400
            repeat: false
        
            onTriggered: {
                coverExtractor.running = true
                
                updateCover.restart()
            }
        }

        Process {
            id: coverExtractor

            command: [
                "sh",
                "-c",
                "FILE=$(mpc --format '%file%' current | head -n1) && mpc readpicture \"$FILE\" > /tmp/cover.tmp && mv /tmp/cover.tmp /tmp/cover.png"
            ]

            running: true

            stdout: SplitParser {}

        }

        Process {
            id: mpdWatcher

            command: ["mpc", "idleloop", "player"]
            running: true

            stdout: SplitParser {
                onRead: data => {
                    coverDelay.restart()
                }
            }
        }

 

      


        // IDLE MODE
        Row {
            id: idleRow

            visible: !island.hovered && !island.musicPlaying

            anchors.centerIn: parent

            spacing: 10

            Text {
                text: Qt.formatDateTime(new Date(), "HH:mm")
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }

            Image {
                source: "assets/rikka.png"

                height: 26
                width: height * (sourceSize.width / sourceSize.height)

                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
            }
        }

        Visualizer {
            anchors.centerIn: parent
            visible: !island.hovered && island.musicPlaying
        }

        // HOVER MODE
        Row {
            id: hoverRow

            visible: island.hovered
            anchors.centerIn: parent

            // ===== MUSIC HOVER =====
            Row {
                visible: island.musicPlaying

                spacing: 12
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 42
                    height: 42
                    radius: 8
                    clip: true

                    Image {
                        id: coverImage

                        anchors.fill: parent
                        cache: false

                        source: "file:///tmp/cover.png?" + island.coverVersion

                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        mipmap: true
                    }
                }

                Item {
                    width: 90
                    height: 30

                    Visualizer {
                        anchors.centerIn: parent
                    }
                }

                Rectangle {
                    width: 1
                    height: 28
                    color: "#444444"
                }

                Column {
                    width: 180
                    spacing: 2

                    Text {
                        text: music.title

                        color: "white"
                        font.pixelSize: 14
                        font.bold: true

                        width: parent.width
                        elide: Text.ElideRight
                    }

                    Text {
                        text: music.artist

                        color: "#aaaaaa"
                        font.pixelSize: 12

                        width: parent.width
                        elide: Text.ElideRight
                    }
                }
            }

            // ===== NORMAL HOVER =====
            Row {
                visible: !island.musicPlaying

                spacing: 14

                Text {
                    text: Qt.formatDateTime(new Date(), "HH:mm")

                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                }

                Image {
                    source: "assets/rikka.png"

                    height: 38
                    width: height * (sourceSize.width / sourceSize.height)

                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                Rectangle {
                    width: 1
                    height: 26
                    color: "#444444"
                }

                Column {
                    spacing: 0

                    Text {
                        text: Qt.formatDateTime(new Date(), "ddd")
                        color: "#dddddd"
                        font.pixelSize: 14
                    }

                    Text {
                        text: Qt.formatDateTime(new Date(), "dd MMM")
                        color: "#999999"
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    width: 1
                    height: 26
                    color: "#444444"
                }

                Column {
                    spacing: 2

                    Row {
                        spacing: 4

                        Text {
                            text: "CPU"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 12
                        }

                        Text {
                            text: island.cpu.toFixed(0) + "%"
                            color: "#bbbbbb"
                            font.pixelSize: 12
                        }
                    }

                    Row {
                        spacing: 4

                        Text {
                            text: "RAM"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 12
                        }

                        Text {
                            text: island.ram.toFixed(0) + "%"
                            color: "#bbbbbb"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
