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

    implicitWidth: 1920
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
        property string coverPath: "/tmp/cover.jpg"

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
        
        Timer {
            interval: 1000
            running: true
            repeat: true

            onTriggered: {
                musicCheck.running = true
            }
        }

        Timer {
             interval: 3000
             running: true
             repeat: true

             onTriggered: {
                 console.log("updating cover")
                 coverExtractor.running = false
                 coverExtractor.running = true
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

        Process {
            id: coverExtractor

            command: [
                "sh",
                "-c",
                "FILE=$(mpc --format '%file%' current | head -n1) && mpc readpicture \"$FILE\" > /tmp/cover.jpg"
            ]

            running: true

            stdout: SplitParser {}
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

                Rectangle {
                    width: 42
                    height: 42
                    radius: 8
                    clip: true

                    Image {
                        id: coverImage

                        anchors.fill: parent

                        source: "file:///tmp/cover.jpg?" + Date.now()

                        cache: false

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
