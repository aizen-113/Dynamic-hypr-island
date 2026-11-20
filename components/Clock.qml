
import QtQuick

QtObject {
    id: root

    // ==========================================
    // CLOCK STATE
    // ==========================================

    property string time: ""
    property string hour: ""
    property string minute: ""

    property string date: ""
    property string day: ""

    // ==========================================
    // PUBLIC DATA INTERFACE
    // ==========================================

    readonly property var output: ({
        time: root.time,
        hour: root.hour,
        minute: root.minute,
        date: root.date,
        day: root.day
    })

    // ==========================================
    // CLOCK UPDATER
    // ==========================================

    function updateClock() {
        const now = new Date();

        root.time = Qt.formatDateTime(now, "HH:mm");
        root.hour = Qt.formatDateTime(now, "HH");
        root.minute = Qt.formatDateTime(now, "mm");

        root.date = Qt.formatDateTime(now, "dd MMM");
        root.day = Qt.formatDateTime(now, "ddd");
    }

    Component.onCompleted: {
        root.updateClock();
    }

    property var updateTimer: Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            root.updateClock();
        }
    }
}
