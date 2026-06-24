import QtQuick

Item {
    id: root

    property bool hovered: false

    implicitWidth: hovered ? 220 : 90
    implicitHeight: hovered ? 40 : 24

    Row {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: 9

            Rectangle {
                width: 4

                property real targetHeight: 8

                height: targetHeight

                radius: width

                color: "white"

                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 120

        onTriggered: {
            for (let i = 0; i < bars.children.length; i++) {
                bars.children[i].targetHeight =
                    6 + Math.random() * (root.hovered ? 26 : 12)
            }
        }
    }
}
