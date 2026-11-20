
import QtQuick
import ".."

Item {
    id: root

    implicitWidth: 800
    implicitHeight: 350

    // ==========================================
    // SHARED STATE
    // ==========================================

    property bool expanded: false
    property bool revealed: false
    property bool musicPlaying: false

    property string expandMode: "stats"
    property string currentTime: "00:00"

    property var cavaValues: []
    property var music: null

    property var systemStats: null
    property var deviceControls: null
    property var theme: null

    property string activePage: "stats"

    // Wi-Fi selection state.
    property string selectedWifiSsid: ""
    property string selectedWifiBssid: ""
    property string selectedWifiSecurity: ""
    property string wifiPassword: ""

    signal toggleRequested(int button)
    signal keyboardFocusRequested(bool active)
    signal revealRequested(bool value)

    property alias maskItem: notchSurface

    // ==========================================
    // FALLBACK PALETTE
    // ==========================================

    property var fallbackPalette: SystemPalette {}

    readonly property color panelColor:
        theme ? theme.surfaceContainer : fallbackPalette.window

    readonly property color cardColor:
        theme ? theme.surfaceContainerHigh : fallbackPalette.base

    readonly property color textColor:
        theme ? theme.onSurface : fallbackPalette.text

    readonly property color mutedColor:
        theme ? theme.onSurfaceVariant : fallbackPalette.windowText

    readonly property color accentColor:
        theme ? theme.primary : fallbackPalette.highlight

    readonly property color accentTextColor:
        theme ? theme.onPrimary : fallbackPalette.highlightedText

    readonly property color borderColor:
        theme ? theme.outlineVariant : fallbackPalette.mid

    // ==========================================
    // BACKEND DATA
    // ==========================================

    readonly property var statsData: systemStats
        ? systemStats.output
        : ({
            cpu: { usagePercent: 0, temperatureC: -1 },
            memory: { usedPercent: 0, usedBytes: 0, totalBytes: 0 },
            network: {
                connected: false,
                interface: "",
                downloadBytesPerSecond: 0,
                uploadBytesPerSecond: 0,
                totalTransferredBytes: 0
            },
            storage: []
        })

    readonly property var controlsData: deviceControls
        ? deviceControls.output
        : ({
            volume: { percent: 0, muted: false, available: false },
            brightness: { percent: 0, available: false },
            gammastep: {
                enabled: false,
                temperatureKelvin: 4500,
                minimumKelvin: 2500,
                maximumKelvin: 6500
            },
            wifi: {
                available: false,
                enabled: false,
                connected: false,
                connectedSsid: "",
                networks: [],
                busy: false,
                lastMessage: "",
                lastError: ""
            },
            bluetooth: {
                available: false,
                powered: false,
                discovering: false,
                pairedDevices: [],
                discoveredDevices: [],
                connectedDevices: [],
                busy: false,
                lastMessage: "",
                lastError: ""
            }
        })

    readonly property var musicData: music
        ? music.output
        : ({
            title: "No Title",
            artist: "Unknown Artist",
            artwork: "",
            elapsed: "0:00",
            duration: "0:00",
            progress: 0,
            playing: false,
            source: "mpd"
        })

    // ==========================================
    // HELPERS
    // ==========================================

    function formatBytes(value) {
        let bytes = Number(value) || 0;

        if (bytes < 0)
            bytes = 0;

        if (bytes < 1024)
            return Math.round(bytes) + " B";

        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KiB";

        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MiB";

        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
    }

    function formatRate(value) {
        return formatBytes(value) + "/s";
    }

    function pageTitle() {
        switch (root.activePage) {
        case "stats": return "System overview";
        case "music": return "Now playing";
        case "controls": return "Device controls";
        case "wifi": return "Wi-Fi";
        case "bluetooth": return "Bluetooth";
        default: return "System";
        }
    }

    function selectPage(page) {
        root.activePage = page;

        if (page !== "wifi") {
            root.selectedWifiSsid = "";
            root.selectedWifiBssid = "";
            root.selectedWifiSecurity = "";
            root.wifiPassword = "";
            root.keyboardFocusRequested(false);
        }
    }

    function selectWifiNetwork(network) {
        if (!network || !network.ssid)
            return;

        root.selectedWifiSsid = network.ssid;
        root.selectedWifiBssid = network.bssid;
        root.selectedWifiSecurity = network.security;
        root.wifiPassword = "";

        // Open networks can be connected immediately.
        if (!network.security || network.security.length === 0)
            root.connectSelectedWifi();
    }

    function connectSelectedWifi() {
        if (!root.deviceControls || !root.selectedWifiSsid)
            return;

        if (
            root.selectedWifiSecurity.length > 0 &&
            root.wifiPassword.length === 0
        ) {
            return;
        }

        root.deviceControls.connectWifi(
            root.selectedWifiSsid,
            root.wifiPassword,
            root.selectedWifiBssid
        );

        root.wifiPassword = "";
        root.keyboardFocusRequested(false);
    }

    // ==========================================
    // PAGE SELECTION
    // ==========================================

    onExpandModeChanged: {
        if (root.expanded)
            root.activePage = root.expandMode;
    }

    onExpandedChanged: {
        if (root.expanded) {
            root.activePage =
                root.expandMode === "music" ? "music" : "stats";
        } else {
            root.keyboardFocusRequested(false);
            root.wifiPassword = "";
        }
    }

    // Device-control polling runs only while a controls or
    // connectivity page is open.
    Binding {
        target: root.deviceControls
        property: "active"

        value: root.expanded && (
            root.activePage === "controls" ||
            root.activePage === "wifi" ||
            root.activePage === "bluetooth"
        )

        when: root.deviceControls !== null
    }

    // ==========================================
    // HOVER SENSOR
    // ==========================================

    MouseArea {
        id: hoverSensor

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: 450
        height: 6

        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            root.revealRequested(true)
        }

        onExited: {
            if (!root.expanded && !surfaceMouse.containsMouse)
                root.revealRequested(false)
        }
    }

    // ==========================================
    // NOTCH SURFACE
    // ==========================================

    Rectangle {
        id: notchSurface

        anchors.horizontalCenter: parent.horizontalCenter

        width: root.expanded ? 800 : 450
        height: root.expanded ? 450 : 45

        y: (root.revealed || root.expanded)
           ? 0
           : -height

        radius: 20
        topLeftRadius: 0
        topRightRadius: 0

        clip: true

        color: Qt.rgba(
            root.panelColor.r,
            root.panelColor.g,
            root.panelColor.b,
            root.expanded ? 0.97 : 0.82
        )


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

        // ======================================
        // SURFACE MOUSE HANDLER
        // ======================================

        MouseArea {
            id: surfaceMouse

            anchors.fill: parent

            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onEntered: {
                root.revealRequested(true)
            }

            onExited: {
                if (!root.expanded && !hoverSensor.containsMouse)
                    root.revealRequested(false)
            }

            onClicked: function(mouse) {
                // Clicking opens the collapsed notch.
                // Clicking empty space inside an expanded notch does nothing.
                if (!root.expanded)
                    root.toggleRequested(mouse.button)
            }
        }

        // ======================================
        // COLLAPSED DISPLAY
        // ======================================

        Row {
            anchors.centerIn: parent
            spacing: 8

            visible: !root.expanded

            Text {
                text: root.currentTime

                visible: !root.musicPlaying

                color: root.textColor

                font.pixelSize: 15
                font.bold: true

                anchors.verticalCenter: parent.verticalCenter
            }

            VisualizerBars {
                width: 90
                height: 28

                levels: root.cavaValues
                barColor: root.accentColor

                visible: root.musicPlaying
            }
        }

        // ======================================
        // EXPANDED HEADER
        // ======================================

        Row {
            id: expandedHeader

            x: 16
            y: 9

            width: parent.width - 32
            height: 30

            visible: root.expanded

            spacing: 8

            Text {
                text: root.pageTitle()

                color: root.textColor

                font.pixelSize: 16
                font.bold: true

                anchors.verticalCenter: parent.verticalCenter

                width: parent.width - 90
                elide: Text.ElideRight
            }

            Item {
                width: 82
                height: parent.height

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.currentTime

                    color: root.mutedColor

                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        // ======================================
        // PAGE NAVIGATION
        // ======================================

        Row {
            id: pageNavigation

            x: 12
            y: 47

            width: parent.width - 24
            height: 32

            spacing: 4

            visible: root.expanded

            Repeater {
                model: [
                    { key: "stats", label: "Stats" },
                    { key: "music", label: "Music" },
                    { key: "controls", label: "Controls" },
                    { key: "wifi", label: "Wi-Fi" },
                    { key: "bluetooth", label: "BT" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: (pageNavigation.width - 16) / 5
                    height: 30

                    radius: 9

                    color: root.activePage === modelData.key
                           ? root.accentColor
                           : root.cardColor

                    Text {
                        anchors.centerIn: parent

                        text: modelData.label

                        color: root.activePage === modelData.key
                               ? root.accentTextColor
                               : root.mutedColor

                        font.pixelSize: 11
                        font.bold: root.activePage === modelData.key
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            root.selectPage(modelData.key)
                        }
                    }
                }
            }
        }

        // ======================================
        // PAGE CONTENT
        // ======================================

        Flickable {
            id: pageFlickable

            x: 12
            y: 88

            width: parent.width - 24
            height: parent.height - 100

            visible: root.expanded

            clip: true

            contentWidth: width
            contentHeight: pageLoader.height

            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: pageLoader

                width: pageFlickable.width

                height: item ? item.implicitHeight : 0

                sourceComponent: {
                    switch (root.activePage) {
                    case "stats": return statsPage;
                    case "music": return musicPage;
                    case "controls": return controlsPage;
                    case "wifi": return wifiPage;
                    case "bluetooth": return bluetoothPage;
                    default: return statsPage;
                    }
                }
            }
        }

        // ======================================
        // STATS PAGE
        // ======================================

        Component {
            id: statsPage

            Item {
                width: pageFlickable.width

                implicitHeight:
                    202 + Math.max(
                        1,
                        root.statsData.storage.length
                    ) * 48

                Column {
                    anchors.fill: parent
                    spacing: 10

                    // CPU AND RAM
                    Row {
                        width: parent.width
                        height: 88
                        spacing: 10

                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 88

                            radius: 13
                            color: root.cardColor

                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 5

                                Text {
                                    text: "CPU"

                                    color: root.mutedColor
                                    font.pixelSize: 12
                                }

                                Text {
                                    text:
                                        Math.round(
                                            root.statsData.cpu.usagePercent
                                        ) + "%"

                                    color: root.textColor
                                    font.pixelSize: 23
                                    font.bold: true
                                }

                                Text {
                                    text:
                                        root.statsData.cpu.temperatureC >= 0
                                        ? root.statsData.cpu.temperatureC.toFixed(0) + "°C"
                                        : "Temperature unavailable"

                                    color: root.mutedColor
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 10) / 2
                            height: 88

                            radius: 13
                            color: root.cardColor

                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 5

                                Text {
                                    text: "Memory"

                                    color: root.mutedColor
                                    font.pixelSize: 12
                                }

                                Text {
                                    text:
                                        Math.round(
                                            root.statsData.memory.usedPercent
                                        ) + "%"

                                    color: root.textColor
                                    font.pixelSize: 23
                                    font.bold: true
                                }

                                Text {
                                    text:
                                        root.formatBytes(
                                            root.statsData.memory.usedBytes
                                        ) + " / " +
                                        root.formatBytes(
                                            root.statsData.memory.totalBytes
                                        )

                                    color: root.mutedColor
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    // NETWORK
                    Rectangle {
                        width: parent.width
                        height: 76

                        radius: 13
                        color: root.cardColor

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 7

                            Row {
                                width: parent.width

                                Text {
                                    id: networkTitle

                                    text: "Network"

                                    color: root.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Item {
                                    width: Math.max(
                                        0,
                                        parent.width -
                                        networkTitle.implicitWidth -
                                        networkInterfaceLabel.implicitWidth
                                    )

                                    height: 1
                                }

                                Text {
                                    id: networkInterfaceLabel

                                    text:
                                        root.statsData.network.connected
                                        ? root.statsData.network.interface
                                        : "Disconnected"

                                    color: root.mutedColor
                                    font.pixelSize: 10

                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                width: parent.width

                                Text {
                                    text:
                                        "↓ " + root.formatRate(
                                            root.statsData.network.downloadBytesPerSecond
                                        )

                                    color: root.textColor
                                    font.pixelSize: 12
                                }

                                Item {
                                    width: 18
                                    height: 1
                                }

                                Text {
                                    text:
                                        "↑ " + root.formatRate(
                                            root.statsData.network.uploadBytesPerSecond
                                        )

                                    color: root.textColor
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text:
                                    "Transferred: " +
                                    root.formatBytes(
                                        root.statsData.network.totalTransferredBytes
                                    )

                                color: root.mutedColor
                                font.pixelSize: 10
                            }
                        }
                    }

                    // STORAGE
                    Column {
                        width: parent.width
                        spacing: 7

                        Text {
                            text: "Storage"

                            color: root.textColor
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Repeater {
                            model: root.statsData.storage || []

                            delegate: Rectangle {
                                required property var modelData

                                width: parent.width
                                height: 48

                                radius: 10
                                color: root.cardColor

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 9
                                    spacing: 5

                                    Row {
                                        width: parent.width

                                        Text {
                                            text: modelData.mountPoint

                                            color: root.textColor
                                            font.pixelSize: 11

                                            width: parent.width * 0.55
                                            elide: Text.ElideMiddle
                                        }

                                        Text {
                                            text:
                                                Math.round(modelData.usedPercent) + "%"

                                            color: root.mutedColor
                                            font.pixelSize: 10

                                            anchors.right: parent.right
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 5

                                        radius: 3
                                        color: root.borderColor

                                        Rectangle {
                                            width:
                                                parent.width *
                                                Math.max(
                                                    0,
                                                    Math.min(
                                                        100,
                                                        modelData.usedPercent
                                                    )
                                                ) / 100

                                            height: parent.height
                                            radius: 3
                                            color: root.accentColor
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.statsData.storage.length === 0

                            text: "No storage data available"

                            color: root.mutedColor
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        // ======================================
        // MUSIC PAGE
        // ======================================

        Component {
            id: musicPage

            Item {
                width: pageFlickable.width
                implicitHeight: 222

                Column {
                    anchors.fill: parent
                    spacing: 12

                    Row {
                        width: parent.width
                        height: 98
                        spacing: 13

                        Rectangle {
                            width: 98
                            height: 98

                            radius: 12
                            color: root.cardColor

                            clip: true

                            Image {
                                anchors.fill: parent

                                source: root.musicData.artwork
                                fillMode: Image.PreserveAspectCrop

                                asynchronous: true
                                cache: true

                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent

                                text: "♪"

                                color: root.accentColor
                                font.pixelSize: 38

                                visible:
                                    !root.musicData.artwork ||
                                    root.musicData.artwork.length === 0
                            }
                        }

                        Column {
                            width: parent.width - 111
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7

                            Text {
                                text: root.musicData.title || "No Title"

                                width: parent.width

                                color: root.textColor
                                font.pixelSize: 15
                                font.bold: true

                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.musicData.artist || "Unknown Artist"

                                width: parent.width

                                color: root.mutedColor
                                font.pixelSize: 12

                                elide: Text.ElideRight
                            }

                            Text {
                                text:
                                    root.musicData.playing
                                    ? "Playing"
                                    : "Paused"

                                color: root.accentColor
                                font.pixelSize: 10
                            }
                        }
                    }

                    // Playback buttons
                    Row {
                        width: parent.width
                        height: 36

                        spacing: 12

                        Rectangle {
                            width: 48
                            height: 34
                            radius: 10
                            color: root.cardColor

                            Text {
                                anchors.centerIn: parent
                                text: "Previous"
                                color: root.textColor
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.music)
                                        root.music.control("prev")
                                }
                            }
                        }

                        Rectangle {
                            width: 48
                            height: 34
                            radius: 10
                            color: root.accentColor

                            Text {
                                anchors.centerIn: parent

                                text:
                                    root.musicData.playing
                                    ? "Ⅱ"
                                    : "▶"

                                color: root.accentTextColor
                                font.pixelSize: 17
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.music)
                                        root.music.control("toggle")
                                }
                            }
                        }

                        Rectangle {
                            width: 48
                            height: 34
                            radius: 10
                            color: root.cardColor

                            Text {
                                anchors.centerIn: parent
                                text: "Next"
                                color: root.textColor
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.music)
                                        root.music.control("next")
                                }
                            }
                        }

                        Item {
                            width: 1
                            height: 1
                        }

                        Rectangle {
                            width: 75
                            height: 34
                            radius: 10
                            color: root.cardColor

                            Text {
                                anchors.centerIn: parent

                                text: root.musicData.source || "MPD"

                                color: root.mutedColor
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.music)
                                        root.music.toggleSource()
                                }
                            }
                        }
                    }

                    // Progress
                    Column {
                        width: parent.width
                        spacing: 7

                        Rectangle {
                            id: musicProgressTrack

                            width: parent.width
                            height: 6

                            radius: 3
                            color: root.borderColor

                            Rectangle {
                                width:
                                    parent.width *
                                    Math.max(
                                        0,
                                        Math.min(100, root.musicData.progress)
                                    ) / 100

                                height: parent.height
                                radius: 3
                                color: root.accentColor
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: function(mouse) {
                                    if (root.music) {
                                        root.music.seek(
                                            Math.max(
                                                0,
                                                Math.min(
                                                    100,
                                                    mouse.x / width * 100
                                                )
                                            )
                                        )
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width

                            Text {
                                id: elapsedLabel

                                text: root.musicData.elapsed || "0:00"

                                color: root.mutedColor
                                font.pixelSize: 10
                            }

                            Item {
                                width: Math.max(
                                    0,
                                    parent.width -
                                    elapsedLabel.implicitWidth -
                                    durationLabel.implicitWidth
                                )

                                height: 1
                            }

                            Text {
                                id: durationLabel

                                text: root.musicData.duration || "0:00"

                                color: root.mutedColor
                                font.pixelSize: 10
                            }
                        }
                    }

                    VisualizerBars {
                        width: parent.width
                        height: 24

                        levels: root.cavaValues
                        barColor: root.accentColor
                    }
                }
            }
        }

        // ======================================
        // DEVICE CONTROLS PAGE
        // ======================================

        Component {
            id: controlsPage

            Item {
                width: pageFlickable.width
                implicitHeight: 292

                Column {
                    anchors.fill: parent
                    spacing: 10

                    // VOLUME
                    Rectangle {
                        width: parent.width
                        height: 82

                        radius: 12
                        color: root.cardColor

                        Text {
                            x: 13
                            y: 11

                            text: "Volume"

                            color: root.textColor
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 13
                            y: 11

                            text:
                                Math.round(
                                    root.controlsData.volume.percent
                                ) + "%"

                            color: root.mutedColor
                            font.pixelSize: 11
                        }

                        Rectangle {
                            x: 13
                            y: 42

                            width: parent.width - 26
                            height: 6

                            radius: 3
                            color: root.borderColor

                            Rectangle {
                                width:
                                    parent.width *
                                    Math.max(
                                        0,
                                        Math.min(
                                            100,
                                            root.controlsData.volume.percent
                                        )
                                    ) / 100

                                height: parent.height
                                radius: 3
                                color: root.accentColor
                            }
                        }

                        MouseArea {
                            x: 13
                            y: 32

                            width: parent.width - 26
                            height: 26

                            onPressed: function(mouse) {
                                if (root.deviceControls) {
                                    root.deviceControls.setVolume(
                                        mouse.x / width * 100
                                    )
                                }
                            }

                            onPositionChanged: function(mouse) {
                                if (pressed && root.deviceControls) {
                                    root.deviceControls.setVolume(
                                        mouse.x / width * 100
                                    )
                                }
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 13
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8

                            text:
                                root.controlsData.volume.muted
                                ? "Muted"
                                : "Click to adjust"

                            color: root.mutedColor
                            font.pixelSize: 9
                        }

                        MouseArea {
                            x: 0
                            y: 58

                            width: 90
                            height: 24

                            onClicked: {
                                if (root.deviceControls)
                                    root.deviceControls.toggleVolumeMute()
                            }
                        }
                    }

                    // BRIGHTNESS
                    Rectangle {
                        width: parent.width
                        height: 82

                        radius: 12
                        color: root.cardColor

                        Text {
                            x: 13
                            y: 11

                            text: "Brightness"

                            color: root.textColor
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 13
                            y: 11

                            text:
                                Math.round(
                                    root.controlsData.brightness.percent
                                ) + "%"

                            color: root.mutedColor
                            font.pixelSize: 11
                        }

                        Rectangle {
                            x: 13
                            y: 42

                            width: parent.width - 26
                            height: 6

                            radius: 3
                            color: root.borderColor

                            Rectangle {
                                width:
                                    parent.width *
                                    Math.max(
                                        0,
                                        Math.min(
                                            100,
                                            root.controlsData.brightness.percent
                                        )
                                    ) / 100

                                height: parent.height
                                radius: 3
                                color: root.accentColor
                            }
                        }

                        MouseArea {
                            x: 13
                            y: 32

                            width: parent.width - 26
                            height: 26

                            onPressed: function(mouse) {
                                if (root.deviceControls) {
                                    root.deviceControls.setBrightness(
                                        mouse.x / width * 100
                                    )
                                }
                            }

                            onPositionChanged: function(mouse) {
                                if (pressed && root.deviceControls) {
                                    root.deviceControls.setBrightness(
                                        mouse.x / width * 100
                                    )
                                }
                            }
                        }
                    }

                    // GAMMASTEP
                    Rectangle {
                        width: parent.width
                        height: 108

                        radius: 12
                        color: root.cardColor

                        Text {
                            x: 13
                            y: 11

                            text: "Night light"

                            color: root.textColor
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 13
                            y: 11

                            text:
                                root.controlsData.gammastep.enabled
                                ? "Enabled"
                                : "Disabled"

                            color: root.mutedColor
                            font.pixelSize: 10
                        }

                        Rectangle {
                            x: 13
                            y: 36

                            width: 42
                            height: 22

                            radius: 11

                            color:
                                root.controlsData.gammastep.enabled
                                ? root.accentColor
                                : root.borderColor

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8

                                y: 3

                                x:
                                    root.controlsData.gammastep.enabled
                                    ? 23
                                    : 3

                                color: root.accentTextColor
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.deviceControls) {
                                        root.deviceControls.setGammastepEnabled(
                                            !root.controlsData.gammastep.enabled
                                        )
                                    }
                                }
                            }
                        }

                        Text {
                            x: 68
                            y: 39

                            text:
                                root.controlsData.gammastep.temperatureKelvin +
                                " K"

                            color: root.mutedColor
                            font.pixelSize: 11
                        }

                        Rectangle {
                            x: 13
                            y: 78

                            width: parent.width - 26
                            height: 6

                            radius: 3
                            color: root.borderColor

                            Rectangle {
                                width: {
                                    const min =
                                        root.controlsData.gammastep.minimumKelvin;
                                    const max =
                                        root.controlsData.gammastep.maximumKelvin;
                                    const value =
                                        root.controlsData.gammastep.temperatureKelvin;

                                    return parent.width * (
                                        (value - min) / (max - min)
                                    );
                                }

                                height: parent.height
                                radius: 3
                                color: root.accentColor
                            }
                        }

                        MouseArea {
                            x: 13
                            y: 68

                            width: parent.width - 26
                            height: 26

                            onPressed: function(mouse) {
                                if (root.deviceControls) {
                                    const min =
                                        root.controlsData.gammastep.minimumKelvin;
                                    const max =
                                        root.controlsData.gammastep.maximumKelvin;

                                    root.deviceControls.setColorTemperature(
                                        min + mouse.x / width * (max - min)
                                    )
                                }
                            }

                            onPositionChanged: function(mouse) {
                                if (pressed && root.deviceControls) {
                                    const min =
                                        root.controlsData.gammastep.minimumKelvin;
                                    const max =
                                        root.controlsData.gammastep.maximumKelvin;

                                    root.deviceControls.setColorTemperature(
                                        min + mouse.x / width * (max - min)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // ======================================
        // WI-FI PAGE
        // ======================================

        Component {
            id: wifiPage

            Item {
                width: pageFlickable.width

                implicitHeight:
                    150 + (root.controlsData.wifi.networks.length * 58)

                Column {
                    anchors.fill: parent
                    spacing: 9

                    // RADIO STATUS
                    Rectangle {
                        width: parent.width
                        height: 66

                        radius: 12
                        color: root.cardColor

                        Text {
                            x: 12
                            y: 11

                            text:
                                root.controlsData.wifi.connected
                                ? root.controlsData.wifi.connectedSsid
                                : "Wi-Fi"

                            color: root.textColor
                            font.pixelSize: 13
                            font.bold: true

                            width: parent.width - 110
                            elide: Text.ElideRight
                        }

                        Text {
                            x: 12
                            y: 36

                            text:
                                root.controlsData.wifi.enabled
                                ? "Wireless enabled"
                                : "Wireless disabled"

                            color: root.mutedColor
                            font.pixelSize: 10
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 10

                            width: 70
                            height: 24

                            radius: 8
                            color: root.accentColor

                            Text {
                                anchors.centerIn: parent

                                text:
                                    root.controlsData.wifi.enabled
                                    ? "Turn off"
                                    : "Turn on"

                                color: root.accentTextColor
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.deviceControls) {
                                        root.deviceControls.setWifiEnabled(
                                            !root.controlsData.wifi.enabled
                                        )
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 38

                            width: 70
                            height: 20

                            radius: 7
                            color: root.borderColor

                            Text {
                                anchors.centerIn: parent

                                text: "Scan"

                                color: root.textColor
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.deviceControls)
                                        root.deviceControls.scanWifi()
                                }
                            }
                        }
                    }

                    // SELECTED NETWORK PASSWORD
                    Rectangle {
                        visible:
                            root.selectedWifiSsid.length > 0 &&
                            root.selectedWifiSecurity.length > 0

                        width: parent.width
                        height: visible ? 62 : 0

                        radius: 12
                        color: root.cardColor

                        TextInput {
                            id: wifiPasswordInput

                            x: 12
                            y: 10

                            width: parent.width - 98
                            height: 40

                            color: root.textColor
                            font.pixelSize: 12

                            echoMode: TextInput.Password
                            selectByMouse: true

                            text: root.wifiPassword

                            onTextChanged: {
                                root.wifiPassword = text;
                            }

                            onFocusChanged: {
                                if (focus)
                                    root.keyboardFocusRequested(true);
                            }

                            onAccepted: {
                                root.connectSelectedWifi();
                                focus = false;
                            }

                            Keys.onEscapePressed: {
                                focus = false;
                                root.keyboardFocusRequested(false);
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter

                                text: "Network password"

                                color: root.mutedColor
                                font.pixelSize: 12

                                visible: wifiPasswordInput.text.length === 0
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            y: 12

                            width: 76
                            height: 36

                            radius: 8
                            color: root.accentColor

                            Text {
                                anchors.centerIn: parent

                                text: "Connect"

                                color: root.accentTextColor
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    root.connectSelectedWifi();
                                    wifiPasswordInput.focus = false;
                                }
                            }
                        }
                    }

                    // NETWORK LIST
                    Text {
                        text: "Available networks"

                        color: root.textColor
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Repeater {
                        model: root.controlsData.wifi.networks || []

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 50

                            radius: 10

                            color:
                                root.selectedWifiBssid === modelData.bssid
                                ? root.cardColor
                                : "transparent"

                            border.width:
                                root.selectedWifiBssid === modelData.bssid
                                ? 1
                                : 0

                            border.color: root.accentColor

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 9

                                Column {
                                    width: parent.width - 92
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Text {
                                        text:
                                            modelData.ssid.length > 0
                                            ? modelData.ssid
                                            : "Hidden network"

                                        width: parent.width

                                        color: root.textColor
                                        font.pixelSize: 11
                                        font.bold: true

                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text:
                                            modelData.security.length > 0
                                            ? modelData.security
                                            : "Open network"

                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: modelData.signal + "%"

                                    color: root.mutedColor
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    root.selectWifiNetwork(modelData)
                                }
                            }
                        }
                    }

                    Text {
                        visible:
                            root.controlsData.wifi.networks.length === 0

                        text:
                            root.controlsData.wifi.enabled
                            ? "No networks found. Try scanning again."
                            : "Turn Wi-Fi on to find networks."

                        color: root.mutedColor
                        font.pixelSize: 11
                    }

                    Text {
                        visible:
                            root.controlsData.wifi.lastError.length > 0 ||
                            root.controlsData.wifi.lastMessage.length > 0

                        text:
                            root.controlsData.wifi.lastError.length > 0
                            ? root.controlsData.wifi.lastError
                            : root.controlsData.wifi.lastMessage

                        color:
                            root.controlsData.wifi.lastError.length > 0
                            ? (root.theme ? root.theme.error : root.mutedColor)
                            : root.mutedColor

                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }
        }

        // ======================================
        // BLUETOOTH PAGE
        // ======================================

        Component {
            id: bluetoothPage

            Item {
                width: pageFlickable.width

                implicitHeight:
                    150 +
                    root.controlsData.bluetooth.pairedDevices.length * 52 +
                    root.controlsData.bluetooth.discoveredDevices.length * 48

                Column {
                    anchors.fill: parent
                    spacing: 9

                    // ADAPTER CONTROLS
                    Rectangle {
                        width: parent.width
                        height: 66

                        radius: 12
                        color: root.cardColor

                        Text {
                            x: 12
                            y: 11

                            text:
                                root.controlsData.bluetooth.adapterName ||
                                "Bluetooth adapter"

                            color: root.textColor
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            x: 12
                            y: 36

                            text:
                                root.controlsData.bluetooth.powered
                                ? "Bluetooth is on"
                                : "Bluetooth is off"

                            color: root.mutedColor
                            font.pixelSize: 10
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 10

                            width: 70
                            height: 24

                            radius: 8
                            color: root.accentColor

                            Text {
                                anchors.centerIn: parent

                                text:
                                    root.controlsData.bluetooth.powered
                                    ? "Turn off"
                                    : "Turn on"

                                color: root.accentTextColor
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (root.deviceControls) {
                                        root.deviceControls.setBluetoothPowered(
                                            !root.controlsData.bluetooth.powered
                                        )
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            y: 38

                            width: 70
                            height: 20

                            radius: 7
                            color: root.borderColor

                            Text {
                                anchors.centerIn: parent

                                text:
                                    root.controlsData.bluetooth.discovering
                                    ? "Stop scan"
                                    : "Discover"

                                color: root.textColor
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    if (!root.deviceControls)
                                        return;

                                    if (root.controlsData.bluetooth.discovering)
                                        root.deviceControls.stopBluetoothDiscovery();
                                    else
                                        root.deviceControls.startBluetoothDiscovery();
                                }
                            }
                        }
                    }

                    // PAIRED DEVICES
                    Text {
                        text: "Paired devices"

                        color: root.textColor
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Repeater {
                        model:
                            root.controlsData.bluetooth.pairedDevices || []

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 48

                            radius: 10
                            color: root.cardColor

                            Column {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter

                                width: parent.width - 100
                                spacing: 3

                                Text {
                                    text:
                                        modelData.name.length > 0
                                        ? modelData.name
                                        : modelData.address

                                    width: parent.width

                                    color: root.textColor
                                    font.pixelSize: 11
                                    font.bold: true

                                    elide: Text.ElideRight
                                }

                                Text {
                                    text:
                                        modelData.connected
                                        ? "Connected"
                                        : "Paired"

                                    color: root.mutedColor
                                    font.pixelSize: 9
                                }
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter

                                width: 76
                                height: 28

                                radius: 8
                                color: root.accentColor

                                Text {
                                    anchors.centerIn: parent

                                    text:
                                        modelData.connected
                                        ? "Disconnect"
                                        : "Connect"

                                    color: root.accentTextColor
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: {
                                        if (!root.deviceControls)
                                            return;

                                        if (modelData.connected) {
                                            root.deviceControls.disconnectBluetooth(
                                                modelData.address
                                            );
                                        } else {
                                            root.deviceControls.connectBluetooth(
                                                modelData.address
                                            );
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible:
                            root.controlsData.bluetooth.pairedDevices.length === 0

                        text: "No paired devices"

                        color: root.mutedColor
                        font.pixelSize: 10
                    }

                    // DISCOVERED DEVICES
                    Text {
                        text: "Discovered devices"

                        color: root.textColor
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Repeater {
                        model:
                            root.controlsData.bluetooth.discoveredDevices || []

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 44

                            radius: 10
                            color: root.cardColor

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter

                                width: parent.width - 20
                                spacing: 3

                                Text {
                                    text:
                                        modelData.name.length > 0
                                        ? modelData.name
                                        : modelData.address

                                    width: parent.width

                                    color: root.textColor
                                    font.pixelSize: 11

                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "Discovered · not paired"

                                    color: root.mutedColor
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }

                    Text {
                        visible:
                            root.controlsData.bluetooth.discoveredDevices.length === 0

                        text:
                            root.controlsData.bluetooth.discovering
                            ? "Searching for devices…"
                            : "Start discovery to find nearby devices."

                        color: root.mutedColor
                        font.pixelSize: 10
                    }

                    Text {
                        visible:
                            root.controlsData.bluetooth.lastError.length > 0 ||
                            root.controlsData.bluetooth.lastMessage.length > 0

                        text:
                            root.controlsData.bluetooth.lastError.length > 0
                            ? root.controlsData.bluetooth.lastError
                            : root.controlsData.bluetooth.lastMessage

                        color: root.mutedColor
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }
        }
    }
}
