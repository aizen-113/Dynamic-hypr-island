
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

    property alias maskItem: notchSurface

    // Invisible hover trigger at the screen's top edge
    MouseArea {
        id: hoverSensor

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: 180
        height: 6

        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            root.revealed = true
        }

        onExited: {
            if (!root.expanded && !surfaceMouse.containsMouse)
                root.revealed = false
        }
    }

    Rectangle {
        id: notchSurface

        anchors.horizontalCenter: parent.horizontalCenter

        width: root.expanded ? 380 : 180
        height: root.expanded ? 110 : 40

        y: (root.revealed || root.expanded)
           ? 0
           : -height + 6

        radius: 20
        topLeftRadius: 0
        topRightRadius: 0

        clip: true

        color: root.expanded ? "#fc000000" : "#a6000000"

        border.width: 1
        border.color: "#222222"

        Behavior on y {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: surfaceMouse

            anchors.fill: parent

            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: {
                root.revealed = true
            }

            onExited: {
                if (!root.expanded && !hoverSensor.containsMouse)
                    root.revealed = false
            }

            onClicked: function(mouse) {
                root.toggleRequested(mouse.button)
            }
        }

        // Collapsed display
        Row {
            anchors.centerIn: parent
            spacing: 8

            visible: !root.expanded

            Text {
                text: root.currentTime

                visible: !root.musicPlaying

                color: "white"

                font.pixelSize: 15
                font.bold: true

                anchors.verticalCenter: parent.verticalCenter
            }

            Visualizer {
                width: 90
                height: 28

                values: root.cavaValues

                visible: root.musicPlaying
            }
        }

        // Expanded area intentionally empty for now.
    }
}
