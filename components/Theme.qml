
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ==========================================
    // ACTIVE CAELESTIA SCHEME
    // ==========================================

    readonly property string stateDirectory: {
        const xdg = Quickshell.env("XDG_STATE_HOME");
        const home = Quickshell.env("HOME") || "";

        return (
            (xdg && xdg.length > 0)
                ? xdg
                : home + "/.local/state"
        ) + "/caelestia";
    }

    readonly property string schemePath:
        stateDirectory + "/scheme.json"

    property string schemeName: ""
    property string schemeMode: "dark"

    // ==========================================
    // SYSTEM FALLBACK
    // Used only before the Caelestia scheme loads.
    // ==========================================

    property var fallback: SystemPalette {}

    // ==========================================
    // MATERIAL 3 PALETTE
    // ==========================================

    property color background: fallback.window
    property color onBackground: fallback.windowText

    property color surface: fallback.window
    property color surfaceDim: fallback.window
    property color surfaceBright: fallback.button

    property color surfaceContainerLowest: fallback.window
    property color surfaceContainerLow: fallback.base
    property color surfaceContainer: fallback.base
    property color surfaceContainerHigh: fallback.button
    property color surfaceContainerHighest: fallback.mid

    property color onSurface: fallback.text
    property color surfaceVariant: fallback.mid
    property color onSurfaceVariant: fallback.windowText

    property color primary: fallback.highlight
    property color onPrimary: fallback.highlightedText
    property color primaryContainer: fallback.highlight
    property color onPrimaryContainer: fallback.highlightedText

    property color secondary: fallback.button
    property color onSecondary: fallback.buttonText
    property color secondaryContainer: fallback.button
    property color onSecondaryContainer: fallback.buttonText

    property color tertiary: fallback.highlight
    property color onTertiary: fallback.highlightedText
    property color tertiaryContainer: fallback.highlight
    property color onTertiaryContainer: fallback.highlightedText

    property color outline: fallback.mid
    property color outlineVariant: fallback.mid

    property color error: fallback.highlight
    property color onError: fallback.highlightedText
    property color errorContainer: fallback.highlight
    property color onErrorContainer: fallback.highlightedText

    property color shadow: fallback.window
    property color scrim: fallback.window
    property color surfaceTint: fallback.highlight

    // ==========================================
    // SCHEME PARSER
    // ==========================================

    function readColor(colours, name, defaultColor) {
        const value = colours[name];

        if (typeof value !== "string" || value.length === 0)
            return defaultColor;

        return value.startsWith("#") ? value : "#" + value;
    }

    function applyScheme(rawText) {
        try {
            const scheme = JSON.parse(rawText);
            const colours = scheme.colours || {};

            root.schemeName = scheme.name || "Unknown";
            root.schemeMode = scheme.mode || "dark";

            root.background = readColor(colours, "background", fallback.window);
            root.onBackground = readColor(colours, "onBackground", fallback.windowText);

            root.surface = readColor(colours, "surface", fallback.window);
            root.surfaceDim = readColor(colours, "surfaceDim", fallback.window);
            root.surfaceBright = readColor(colours, "surfaceBright", fallback.button);

            root.surfaceContainerLowest = readColor(colours, "surfaceContainerLowest", fallback.window);
            root.surfaceContainerLow = readColor(colours, "surfaceContainerLow", fallback.base);
            root.surfaceContainer = readColor(colours, "surfaceContainer", fallback.base);
            root.surfaceContainerHigh = readColor(colours, "surfaceContainerHigh", fallback.button);
            root.surfaceContainerHighest = readColor(colours, "surfaceContainerHighest", fallback.mid);

            root.onSurface = readColor(colours, "onSurface", fallback.text);
            root.surfaceVariant = readColor(colours, "surfaceVariant", fallback.mid);
            root.onSurfaceVariant = readColor(colours, "onSurfaceVariant", fallback.windowText);

            root.primary = readColor(colours, "primary", fallback.highlight);
            root.onPrimary = readColor(colours, "onPrimary", fallback.highlightedText);
            root.primaryContainer = readColor(colours, "primaryContainer", fallback.highlight);
            root.onPrimaryContainer = readColor(colours, "onPrimaryContainer", fallback.highlightedText);

            root.secondary = readColor(colours, "secondary", fallback.button);
            root.onSecondary = readColor(colours, "onSecondary", fallback.buttonText);
            root.secondaryContainer = readColor(colours, "secondaryContainer", fallback.button);
            root.onSecondaryContainer = readColor(colours, "onSecondaryContainer", fallback.buttonText);

            root.tertiary = readColor(colours, "tertiary", fallback.highlight);
            root.onTertiary = readColor(colours, "onTertiary", fallback.highlightedText);
            root.tertiaryContainer = readColor(colours, "tertiaryContainer", fallback.highlight);
            root.onTertiaryContainer = readColor(colours, "onTertiaryContainer", fallback.highlightedText);

            root.outline = readColor(colours, "outline", fallback.mid);
            root.outlineVariant = readColor(colours, "outlineVariant", fallback.mid);

            root.error = readColor(colours, "error", fallback.highlight);
            root.onError = readColor(colours, "onError", fallback.highlightedText);
            root.errorContainer = readColor(colours, "errorContainer", fallback.highlight);
            root.onErrorContainer = readColor(colours, "onErrorContainer", fallback.highlightedText);

            root.shadow = readColor(colours, "shadow", fallback.window);
            root.scrim = readColor(colours, "scrim", fallback.window);
            root.surfaceTint = readColor(colours, "surfaceTint", fallback.highlight);

            console.info("[Island Theme] Loaded:", root.schemeName);
        } catch (error) {
            console.warn("[Island Theme] Could not parse scheme:", error);
        }
    }

    // ==========================================
    // LIVE SCHEME WATCHER
    // ==========================================

    property var schemeFile: FileView {
        path: root.schemePath
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            root.applyScheme(text());
        }
    }
}
