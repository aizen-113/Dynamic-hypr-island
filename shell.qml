import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "./components"
import Quickshell.Io
import QtQuick.Window



PanelWindow {
    id: root

    color: "transparent"

    property var cavaValues: []
    property string cavaConfigPath: ""
    property bool cavaActive: musicDaemon.mpdisPlaying

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true

    implicitWidth: 460
    implicitHeight: 160

    // Dynamic click-through mask
    mask: Region {
        item: island
    }

    property bool audioDetected: {
        for (let i = 0; i < cavaValues.length; i++) {
            if ((parseInt(cavaValues[i], 10) || 0) > 5)
                return true
        }
        return false
    }

    // ------------------------------------------
    // THE MUSIC DAEMON ENGINE (Model & Controller)
    // ------------------------------------------
    MusicInfo {
        id: musicDaemon

        Component.onCompleted: {
            const url = Qt.resolvedUrl("cava.conf").toString()
            root.cavaConfigPath = url.replace("file://", "")
        }

        Process {
            id: cavaProcess

            command: ["cava", "-p", root.cavaConfigPath]

            running: true

            stdout: SplitParser {
                onRead: data => {
                    root.cavaValues = data.trim().split(";")
                }
            }

            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.length > 0)
                        console.log("[Dynamic Island] Cava Error: " + text.trim())
                }
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [ root ] // Tell it to watch this PanelWindow!

        // When you click outside, Hyprland automatically clears the grab!
        onCleared: {
            island.expanded = false;
        }
    }

    Rectangle {
        id: island

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 17

        property bool expanded: false
        
        property bool musicPlaying: root.audioDetected
        property string expandMode: "stats"

        width: expanded ? 380 : 180
        height: expanded ? (expandMode === "music" ? 140 : 110) : 40
        radius: 20

        clip: true
        focus: true

        color: expanded ? "#fc000000" : "#a6000000"
        border.width: 1
        border.color: "#222222"

        // Transitions
        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        onExpandedChanged: {
            if (expanded) {
                focusGrab.active = true;
            } else {
                focusGrab.active = false;
            }
        }
        
        // COLLAPSED CLOCK
        property string currentTime: Qt.formatDateTime(new Date(), "HH:mm")

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                island.currentTime = Qt.formatDateTime(new Date(), "HH:mm")
            }
        }

        // MOUSE CLICK ROUTER
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton // Handles Left & Right Click!

            onClicked: function(mouse) {
                // 1. Right Click opens/toggles Music Mode
                if (mouse.button === Qt.RightButton) {
                    island.expandMode = "music";
                    island.expanded = !island.expanded;
                } 
                // 2. Left Click opens/toggles Stats Mode
                else if (mouse.button === Qt.LeftButton) {
                    island.expandMode = "stats";
                    island.expanded = !island.expanded;
                }
            }
        }

        // ==========================================
        // COLLAPSED MODES
        // ==========================================

        // Idle clock
        Row {
            id: idleRow
            visible: !island.expanded && !island.musicPlaying
            anchors.centerIn: parent

            Text {
                text: island.currentTime
                color: "white"
                font.pixelSize: 15
                font.bold: true
            }
        }

        // Collapsed mini visualizer
        Visualizer {
            anchors.centerIn: parent
            values: root.cavaValues
            visible: !island.expanded && island.musicPlaying
        }

        // ==========================================
        // DYNAMIC EXPANDED COMPONENTS
        // ==========================================

        Expanded {
            id: expandedView
            anchors.centerIn: parent

            visible: opacity > 0
            
            opacity: (island.expanded && island.expandMode === "stats") ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 200 // Fades in smoothly over 200ms
                    easing.type: Easing.OutQuad
                }
            }
        }

        Music {
            id: musicView
            anchors.centerIn: parent
            cavaValues: root.cavaValues
            music: musicDaemon // Pass the daemon
            
            visible: opacity > 0
            opacity: (island.expanded && island.expandMode === "music") ? 1.0 : 0.0
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
