
import QtQuick

Item {
    id: root

    required property var levels
    required property color barColor

    implicitWidth: 90
    implicitHeight: 28

    Row {
        anchors.centerIn: parent
        height: parent.height
        spacing: 2

        Repeater {
            model: Math.min(root.levels.length, 20)

            Rectangle {
                required property int index

                width: 3

                height: Math.max(
                    2,
                    Number(root.levels[index]) / 3
                )

                radius: width / 2
                color: root.barColor

                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
