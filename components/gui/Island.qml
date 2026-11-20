
import QtQuick
import ".."

Item {
    id: root

    implicitWidth: 460
    implicitHeight: 160

    property bool expanded: false
    property bool revealed: false
    property bool musicPlaying: false

    property string expandMode: "stats"
    property string currentTime: "00:00"

    property var cavaValues: []
    property var music

    signal toggleRequested(int button)

    property alias maskItem: islandSurface

    Rectangle {
        id: islandSurface

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 17

        width: root.expanded ? 380 : 180
        height: root.expanded
                ? (root.expandMode === "music" ? 140 : 110)
                : 40

        radius: 20

        clip: true
        focus: true

        color: root.expanded ? "#fc000000" : "#a6000000"

        border.width: 1
        border.color: "#222222"

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

        // Click router
        MouseArea {
            anchors.fill: parent

            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: function(mouse) {
                root.toggleRequested(mouse.button)
            }
        }

        // Idle clock
        Row {
            visible: !root.expanded && !root.musicPlaying
            anchors.centerIn: parent

            Text {
                text: root.currentTime
                color: "white"
                font.pixelSize: 15
                font.bold: true
            }
        }

        // Collapsed visualizer
        Visualizer {
            anchors.centerIn: parent

            values: root.cavaValues

            visible: !root.expanded && root.musicPlaying
        }

        // Existing expanded stats GUI
        Expanded {
            id: expandedView

            anchors.centerIn: parent

            visible: opacity > 0

            opacity: (
                root.expanded &&
                root.expandMode === "stats"
            ) ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }

        // Existing expanded music GUI
        Music {
            id: musicView

            anchors.centerIn: parent

            cavaValues: root.cavaValues
            music: root.music

            visible: opacity > 0

            opacity: (
                root.expanded &&
                root.expandMode === "music"
            ) ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
