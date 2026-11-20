
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Window

import "./components"
import "./components/gui"

PanelWindow {
    id: root

    color: "transparent"

    // ==========================================
    // GUI CONFIGURATION
    // ==========================================

    property string guiStyle: "notch"

    // ==========================================
    // SHARED APPLICATION STATE
    // ==========================================

    property bool expanded: false
    property bool revealed: false

    property string expandMode: "stats"

    readonly property string currentTime: clockBackend.output.time

    // Cava data comes from the backend.
    property var cavaValues: visualizerBackend.output.levels

    // Existing audio detection behaviour is preserved.
    property bool audioDetected:
        visualizerBackend.output.active

    // ==========================================
    // SHARED THEME
    // ==========================================

    Theme {
        id: islandTheme
    }

    // ==========================================
    // WINDOW CONFIGURATION
    // ==========================================

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true

    implicitWidth: 800
    implicitHeight: 350

    // ==========================================
    // WINDOW INPUT MASK
    // ==========================================

    mask: Region {
        // Visible GUI region.
        Region {
            item: guiLoader.item
                  ? guiLoader.item.maskItem
                  : null
        }

        // Invisible hover trigger for Notch.
        Region {
            x: (root.implicitWidth - 180) / 2
            y: 0

            width: root.guiStyle === "notch" ? 450 : 0
            height: root.guiStyle === "notch" ? 6 : 0
        }
    }

    // ==========================================
    // SHARED CLOCK ENGINE
    // ==========================================

    Clock {
        id: clockBackend
    }

    // ==========================================
    // MUSIC BACKEND
    // ==========================================

    MusicInfo {
        id: musicDaemon
    }

    Music {
        id: musicBackend

        engine: musicDaemon
    }

    // ==========================================
    // VISUALIZER BACKEND
    // ==========================================

    Visualizer {
        id: visualizerBackend
    }

    // ==========================================
    // SYSTEM STATS BACKEND
    // ==========================================

    SystemStats {
        id: systemStatsBackend
    }

    // ==========================================
    // DEVICE CONTROLS BACKEND
    // ==========================================

    DeviceControls {
        id: deviceControlsBackend

        // The GUI activates polling when its Controls
        // interface is opened.
        active: false
    }

    // ==========================================
    // SHARED EXPANSION CONTROL
    // ==========================================

    function toggleExpanded(button) {
        // Right click: Music mode.
        if (button === Qt.RightButton) {
            root.expandMode = "music"
        }

        // Left click: Stats mode.
        else if (button === Qt.LeftButton) {
            root.expandMode = "stats"
        }

        // Preserve the original toggle behaviour.
        root.expanded = !root.expanded

        if (root.expanded)
            root.revealed = true
    }


    // ==========================================
    // GUI CONFIGURATION LOADER
    // ==========================================

    Loader {
        id: guiLoader

        anchors.fill: parent

        source: root.guiStyle === "notch"
                ? "components/gui/Notch.qml"
                : "components/gui/Island.qml"
    }

    // ==========================================
    // SHARED STATE -> SELECTED GUI
    // ==========================================

    Binding {
        target: guiLoader.item
        property: "expanded"
        value: root.expanded
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "revealed"
        value: root.revealed
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "expandMode"
        value: root.expandMode
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "musicPlaying"
        value: root.audioDetected
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "currentTime"
        value: root.currentTime
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "cavaValues"
        value: root.cavaValues
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "music"
        value: musicDaemon
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "theme"
        value: islandTheme
        when: guiLoader.item !== null
    }

    // Backend references for the GUI.
    Binding {
        target: guiLoader.item
        property: "systemStats"
        value: systemStatsBackend
        when: guiLoader.item !== null
    }

    Binding {
        target: guiLoader.item
        property: "deviceControls"
        value: deviceControlsBackend
        when: guiLoader.item !== null
    }

    // ==========================================
    // GUI INTERACTION -> SHARED STATE
    // ==========================================

    Connections {
        target: guiLoader.item

        function onToggleRequested(button) {
            root.toggleExpanded(button)
        }

        function onRevealRequested(value) {
            root.revealed = value
        }
    }
}
