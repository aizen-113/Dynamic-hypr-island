import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: 380
    implicitHeight: 110 // Scaled down to match Expanded.qml's exact height!

    property var cavaValues: []
    property var music



    Column {
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.bottomMargin: 8
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 12 // Even, clean vertical spacing

        // ------------------------------------------
        // ROW 1: [cover][title]      [visualizer]
        // ------------------------------------------
        Item {
            width: parent.width
            height: 36

            // Left: Album Cover
            Rectangle {
                id: coverRect
                width: 36
                height: 36
                radius: 6
                clip: true
                color: "#111111"
                border.width: 1
                border.color: "#1a1a1a"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    cache: false
                    source: music.coverPath 
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }
            }

            // Middle: Track & Artist Info (Strictly capped to 180px to prevent overlaps!)
            Column {
                id: titleCol
                anchors.left: coverRect.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 180 
                spacing: 1

                Text {
                    text: music.title
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                    width: parent.width
                    elide: Text.ElideRight // Cleanly cuts off long titles with '...'
                }

                Text {
                    text: music.artist
                    color: "#666666"
                    font.pixelSize: 9
                    font.bold: true
                    width: parent.width
                    elide: Text.ElideRight
                }
            }

            // Right: Bouncing Visualizer (Pushed perfectly to the right edge!)
            Row {
                id: visualizerRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.bottomMargin: 20
                width: 90
                height: 27
                spacing: 2

                Repeater {
                    model: Math.min(root.cavaValues.length, 16) // 16 elegant bars

                    Rectangle {
                        width: 3
                        height: {
                            let v = parseInt(root.cavaValues[index]) || 0;
                            return Math.max(1, v / 6);
                        }
                        color: "white"
                        radius: 1
                        anchors.bottom: parent.bottom // Rises upwards!
                    }
                }
            }
        }

        // ------------------------------------------
        // ROW 2: PROGRESS BAR TIMELINE
        // ------------------------------------------
        Row {
            width: parent.width
            height: 12
            spacing: 8

            Text {
                text: music.elapsedTime
                color: "#444444"
                font.pixelSize: 8
                font.bold: true
                width: 24
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                height: 3
                color: "#111111"
                radius: 1.5
                border.width: 1
                border.color: "#1a1a1a"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64
                clip: true 

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, music.percent / 100))
                    color: "white"
                    radius: 1.5
                }

                MouseArea {
                    anchors.fill: parent
                    
                    function updateSeek(mouseX) {
                        let pct = Math.max(0, Math.min(100, Math.round((mouseX / parent.width) * 100)));
                        music.seek(pct + "%");
                    }

                    onPressed: function(mouse) { updateSeek(mouse.x); }
                    onPositionChanged: function(mouse) { updateSeek(mouse.x); }
                }
            }

            Text {
                text: music.totalDuration
                color: "#444444"
                font.pixelSize: 8
                font.bold: true
                width: 24
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ------------------------------------------
        // ROW 3: CONTROLS & SOURCE SELECTOR
        // ------------------------------------------
        Item {
            width: parent.width
            height: 20

            Row {
                anchors.centerIn: parent
                spacing: 36
                height: parent.height

                Text {
                    text: "⏮"
                    color: "white"
                    font.pixelSize: 20
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: prevMouse.pressed ? 0.4 : 1.0
                    MouseArea {
                        id: prevMouse; anchors.fill: parent
                        onClicked: { music.control("prev"); }
                    }
                }

                Text {
                    text: music.isPlaying ? "⏸" : "▶"
                    color: "white"
                    font.pixelSize: 21
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: playMouse.pressed ? 0.4 : 1.0
                    MouseArea {
                        id: playMouse; anchors.fill: parent
                        onClicked: { music.control("toggle"); }
                    }
                }

                Text {
                    text: "⏭"
                    color: "white"
                    font.pixelSize: 20
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: nextMouse.pressed ? 0.4 : 1.0
                    MouseArea {
                        id: nextMouse; anchors.fill: parent
                        onClicked: { music.control("next"); }
                    }
                }
            }

            Rectangle {
                visible: music.isPlaying || music.title !== "Not Playing"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 14
                color: "#111111"
                radius: 3
                border.width: 1
                border.color: "#1c1a1a"

                Text {
                    text: music.activeSource.toUpperCase()
                    color: "#888888"
                    font.pixelSize: 8
                    font.bold: true
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        music.toggleSource();
                    }
                }
            }
        }
    }
}