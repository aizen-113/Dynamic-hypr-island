import QtQuick
import Quickshell
import Quickshell.Wayland
import "./components"

PanelWindow {
    id: root

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true

    implicitWidth: 1920
    implicitHeight: 80

    Animation {
        id: anim
    }

    Rectangle {
        id: island

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: anim.topMargin

        property bool hovered: false
        property real cpu: 0
        property real ram: 0

        width: hovered ? 420 : 180
        height: hovered ? 56 : 40

        radius: height / 2

        color: "#000000"
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

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: island.hovered = true
            onExited: island.hovered = false
        }

        Timer {
            interval: 1000
            running: island.hovered
            repeat: true

            onTriggered: {
                island.cpu = Math.random() * 100
                island.ram = Math.random() * 100
            }
        }

        // IDLE MODE
        Row {
            id: idleRow

            visible: !island.hovered

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

        // HOVER MODE
        Row {
            id: hoverRow

            visible: island.hovered

            anchors.centerIn: parent

            spacing: 14

            Text {
                text: Qt.formatDateTime(new Date(), "HH:mm")

                color: "white"
                font.pixelSize: 24
                font.bold: true
            }

            Image {
                source: "assets/rikka.png"

                height: 34
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

                anchors.verticalCenter: parent.verticalCenter
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

                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 0

                Text {
                    text: "CPU " + island.cpu.toFixed(0) + "%"
                    color: "#bbbbbb"
                    font.pixelSize: 12
                }

                Text {
                    text: "RAM " + island.ram.toFixed(0) + "%"
                    color: "#bbbbbb"
                    font.pixelSize: 12
                }
            }
        }
    }
}
