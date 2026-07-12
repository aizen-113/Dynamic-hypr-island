import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool musicPlaying: false

    implicitWidth: 400
    implicitHeight: 110

    // Monochrome Stats
    property real cpu: 0
    property real ram: 0
    property real vol: 50
    property real bri: 50

    property real prevTotal: 0
    property real prevIdle: 0

    // Time States
    property string hours: Qt.formatDateTime(new Date(), "HH")
    property string minutes: Qt.formatDateTime(new Date(), "mm")

    // Core Active Timer: Only ticks when the island is expanded!
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.hours = Qt.formatDateTime(new Date(), "HH")
            root.minutes = Qt.formatDateTime(new Date(), "mm")
            
            if (root.musicPlaying) {
                titleProc.running = true;
                artistProc.running = true;
            } else {
                sysStatsProc.running = true;
                volProc.running = true;
                briProc.running = true;
            }
        }
    }

    Component.onCompleted: {
        if (root.musicPlaying) {
            titleProc.running = true;
            artistProc.running = true;
            coverExtractor.running = true;
        } else {
            sysStatsProc.running = true;
            volProc.running = true;
            briProc.running = true;
        }
    }

    // ==========================================
    // SYSTEM STATS PROCESSES
    // ==========================================

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

                    if (root.prevTotal > 0) {
                        let diffTotal = total - root.prevTotal;
                        let diffIdle = idleTime - root.prevIdle;
                        if (diffTotal > 0) {
                            root.cpu = Math.max(0, Math.min(100, ((diffTotal - diffIdle) / diffTotal) * 100));
                        }
                    }
                    root.prevTotal = total;
                    root.prevIdle = idleTime;

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
                        root.ram = Math.max(0, Math.min(100, ((totalMem - availMem) / totalMem) * 100));
                    }
                }
            }
        }
    }

    // Volume Getter
    Process {
        id: volProc
        command: [
            "sh",
            "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseFloat(text.trim());
                if (!isNaN(v)) root.vol = Math.max(0, Math.min(100, v));
            }
        }
    }

    // Volume Setter
    Process {
        id: volSetter
        running: false
        command: []
    }

    // Brightness Getter
    Process {
        id: briProc
        command: [
            "sh",
            "-c",
            "brightnessctl -m | cut -d, -f4 | sed 's/%//'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let b = parseFloat(text.trim());
                if (!isNaN(b)) root.bri = Math.max(0, Math.min(100, b));
            }
        }
    }

    // Brightness Setter
    Process {
        id: briSetter
        running: false
        command: []
    }



    Column {
        id: clockCol
        anchors.left: parent.left
        anchors.leftMargin: 24 // Slightly adjusted for curved box symmetry
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        spacing: -8 

        Text {
            text: root.hours
            color: "white"
            font.pixelSize: 30 // Bumper size!
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "•••"
            color: "#333333"
            font.pixelSize: 15
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: root.minutes
            color: "#666666" // Sleek dark gray
            font.pixelSize: 30 // Bumper size!
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

 
    Row {
        id: statsRow
        anchors.left: clockCol.right
        anchors.leftMargin: 16 // Sticking tightly to the clock!
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12


        Column {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 6 // Super thin!
                height: 64 // Tall and elegant!
                color: "#111111"
                radius: 3
                border.width: 1
                border.color: "#1c1a1a"

                Rectangle {
                    width: parent.width
                    height: parent.height * (root.cpu / 100)
                    color: "white"
                    radius: 3
                    anchors.bottom: parent.bottom

                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: "CPU"
                color: "#666666"
                font.pixelSize: 8
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Column {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 6 // Super thin!
                height: 64 // Tall and elegant!
                color: "#111111"
                radius: 3
                border.width: 1
                border.color: "#1c1a1a"

                Rectangle {
                    width: parent.width
                    height: parent.height * (root.ram / 100)
                    color: "white"
                    radius: 3
                    anchors.bottom: parent.bottom

                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: "RAM"
                color: "#666666"
                font.pixelSize: 8
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Rectangle {
        id: mainSeparator
        width: 3
        height: 70
        color: "#1a1a1a"
        anchors.left: statsRow.right
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
    }
    Column {
        id: statsSlidersCol
        visible: !root.musicPlaying
        anchors.left: mainSeparator.right
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        width: 180
        spacing: 14 // Vertical gap between sliders

        // Volume Slider (Horizontal!)
        Row {
            width: parent.width
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: "VOL"
                color: "white"
                font.pixelSize: 9
                font.bold: true
                width: 24
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                height: 8
                color: "#111111"
                radius: 4
                border.width: 1
                border.color: "#1a1a1a"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64 // Dynamically scales to fill remaining width

                Rectangle {
                    height: parent.height
                    width: parent.width * (root.vol / 100)
                    color: "white"
                    radius: 4

                    Behavior on width {
                        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                    }
                }

                // Drag adjust volume
                MouseArea {
                    anchors.fill: parent
                    
                    function updateVol(mouseX) {
                        let pct = Math.max(0, Math.min(100, Math.round((mouseX / parent.width) * 100)));
                        root.vol = pct;
                        volSetter.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct + "%"];
                        volSetter.running = true;
                    }

                    onPressed: function(mouse) { updateVol(mouse.x); }
                    onPositionChanged: function(mouse) { updateVol(mouse.x); }
                }
            }

            Text {
                text: root.vol.toFixed(0) + "%"
                color: "#666666"
                font.pixelSize: 9
                font.bold: true
                width: 24
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Brightness Slider (Horizontal!)
        Row {
            width: parent.width
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: "BRI"
                color: "white"
                font.pixelSize: 9
                font.bold: true
                width: 24
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                height: 8
                color: "#111111"
                radius: 4
                border.width: 1
                border.color: "#1a1a1a"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64 // Dynamically scales to fill remaining width

                Rectangle {
                    height: parent.height
                    width: parent.width * (root.bri / 100)
                    color: "white"
                    radius: 4

                    Behavior on width {
                        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                    }
                }

                // Drag adjust brightness
                MouseArea {
                    anchors.fill: parent
                    
                    function updateBri(mouseX) {
                        let pct = Math.max(0, Math.min(100, Math.round((mouseX / parent.width) * 100)));
                        root.bri = pct;
                        briSetter.command = ["brightnessctl", "set", pct + "%"];
                        briSetter.running = true;
                    }

                    onPressed: function(mouse) { updateBri(mouse.x); }
                    onPositionChanged: function(mouse) { updateBri(mouse.x); }
                }
            }

            Text {
                text: root.bri.toFixed(0) + "%"
                color: "#666666"
                font.pixelSize: 9
                font.bold: true
                width: 24
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}