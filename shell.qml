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

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true

    WlrLayershell.keyboardFocus: island.expanded ? KeyboardFocus.OnDemand : KeyboardFocus.None
    

    implicitWidth: 460
    implicitHeight: 160

    // Dynamic click-through mask
    mask: Region {
        item: island
    }

    // ------------------------------------------
    // THE MUSIC DAEMON ENGINE (Model & Controller)
    // ------------------------------------------
    MusicInfo {
        id: musicDaemon
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
        
        property bool musicPlaying: musicDaemon.mpdIsPlaying
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