
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    readonly property bool revealed: idleBackend.output.revealed

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

    Idle {
        id: idleBackend

        expanded: root.expanded
    }

    // ==========================================
    // WINDOW CONFIGURATION
    // ==========================================

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true

    implicitWidth: 460
    implicitHeight: 160

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

            width: root.guiStyle === "notch" ? 180 : 0
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
    // System Stats BACKEND
    // ==========================================

    SystemStats {
        id: systemStatsBackend
    }

    // ==========================================
    // Device Controls BACKEND
    // ==========================================

    DeviceControls {
        id: deviceControlsBackend

        // Temporary: enable polling for testing.
        // Later this will depend on the selected Controls page.
        active: true
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
            idleBackend.setRevealed(true)
    }

    onExpandedChanged: {
        focusGrab.active = root.expanded
    }

    HyprlandFocusGrab {
        id: focusGrab

        windows: [root]

        // Clicking outside closes the expanded interface.
        onCleared: {
            root.expanded = false
            idleBackend.setRevealed(false)
        }
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

    // ==========================================
    // GUI INTERACTION -> SHARED STATE
    // ==========================================

    Connections {
        target: guiLoader.item

        function onToggleRequested(button) {
            root.toggleExpanded(button)
        }

        function onRevealRequested(value) {
            idleBackend.setRevealed(value)
        }
    }

}
