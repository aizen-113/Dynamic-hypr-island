import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool expanded: false

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Timer {
        running: true
        repeat: true
        interval: 1000

        onTriggered: {
            time.text = Qt.formatDateTime(new Date(), "hh:mm")
            date.text = Qt.formatDateTime(new Date(), "dd MMM")
            day.text = Qt.formatDateTime(new Date(), "ddd")
        }
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: expanded ? 10 : 6

        Text {
            id: time

            text: Qt.formatDateTime(new Date(), "hh:mm")

            color: "white"
            font.pixelSize: expanded ? 22 : 18
            font.bold: true

            Behavior on font.pixelSize {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
        }

        Image {
            id: divider

            source: "./assets/rikka.png" // your png

            sourceSize.height: expanded ? 26 : 20
            fillMode: Image.PreserveAspectFit

            Behavior on sourceSize.height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
        }

        RowLayout {
            visible: expanded

            opacity: expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            spacing: 8

            Text {
                id: date

                text: Qt.formatDateTime(new Date(), "dd MMM")
                color: "#bbbbbb"
                font.pixelSize: 15
            }

            Text {
                id: day

                text: Qt.formatDateTime(new Date(), "ddd")
                color: "#888888"
                font.pixelSize: 15
            }
        }
    }
}
