
import QtQuick

QtObject {
    id: root

    // ==========================================
    // ENGINE CONNECTION
    // ==========================================

    property var engine: null

    // ==========================================
    // PUBLIC DATA INTERFACE
    // Consumed by the GUI configurations.
    // ==========================================

    readonly property var output: {
        if (!root.engine) {
            return {
                title: "No Title",
                artist: "Unknown Artist",
                coverPath: "",
                elapsedTime: "0:00",
                totalDuration: "0:00",
                percent: 0,
                isPlaying: false,
                activeSource: "mpd"
            };
        }

        return {
            title: root.engine.title,
            artist: root.engine.artist,
            coverPath: root.engine.coverPath,
            elapsedTime: root.engine.elapsedTime,
            totalDuration: root.engine.totalDuration,
            percent: root.engine.percent,
            isPlaying: root.engine.isPlaying,
            activeSource: root.engine.activeSource
        };
    }

    // ==========================================
    // PLAYBACK COMMAND INTERFACE
    // GUI requests actions; backend forwards them.
    // ==========================================

    function control(action) {
        if (!root.engine)
            return;

        if (
            action !== "prev" &&
            action !== "next" &&
            action !== "toggle"
        )
            return;

        root.engine.control(action);
    }

    // ==========================================
    // SEEK INTERFACE
    // ==========================================

    function seek(percent) {
        if (!root.engine)
            return;

        const requested = Number(
            String(percent).replace("%", "")
        );

        if (!Number.isFinite(requested))
            return;

        const value = Math.max(
            0,
            Math.min(100, requested)
        );

        root.engine.seek(value + "%");
    }

    // ==========================================
    // SOURCE SWITCHING
    // ==========================================

    function toggleSource() {
        if (!root.engine)
            return;

        root.engine.toggleSource();
    }
}
