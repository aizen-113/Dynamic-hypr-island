import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string activeSource: "mpd"

    // ==========================================
    // UNIFIED OUTPUT LAYER (What Music.qml reads)
    // ==========================================
    property string title: (activeSource === "mpd") ? mpdTitle : mprisTitle
    property string artist: (activeSource === "mpd") ? mpdArtist : mprisArtist
    property string elapsedTime: (activeSource === "mpd") ? mpdElapsedTime : mprisElapsedTime
    property string totalDuration: (activeSource === "mpd") ? mpdTotalDuration : mprisTotalDuration
    property real percent: (activeSource === "mpd") ? mpdPercent : mprisPercent
    property bool isPlaying: (activeSource === "mpd") ? mpdIsPlaying : mprisIsPlaying
    
    // DEDICATED ISOLATED SLOTS (Never pollution each other!)
    property string coverPath: {
        if (activeSource === "mpd") {
            return "file:///tmp/cover_mpd.png?" + mpdCoverVersion;
        } else {
            return "file:///tmp/cover_mpris?" + mprisCoverVersion;
        }
    }

    // ==========================================
    // PUBLIC MUSIC DATA INTERFACE
    // ==========================================

    readonly property var output: ({
        title: root.title,
        artist: root.artist,
        artwork: root.coverPath,

        elapsed: root.elapsedTime,
        duration: root.totalDuration,
        progress: root.percent,

        playing: root.isPlaying,
        source: root.activeSource
    })

    // ==========================================
    // ISOLATED DATA CONTAINERS
    // ==========================================

    // MPD Container
    property string mpdTitle: "No Title"
    property string mpdArtist: "Unknown Artist"
    property string mpdElapsedTime: "0:00"
    property string mpdTotalDuration: "0:00"
    property real mpdPercent: 0
    property bool mpdIsPlaying: false
    property int mpdCoverVersion: 0

    // MPRIS Container
    property string mprisTitle: "No Title"
    property string mprisArtist: "Unknown Artist"
    property string mprisElapsedTime: "0:00"
    property string mprisTotalDuration: "0:00"
    property real mprisPercent: 0
    property bool mprisIsPlaying: false
    property int mprisCoverVersion: 0
    property string mprisTrackKey: ""
    property string mprisArtworkKey: ""
    property real mprisLengthUs: 0
    property real mprisPositionSec: 0
    property real mprisPositionUpdatedAt: 0

    // Helper: Formats seconds to MM:SS
    function formatTime(sec) {
        if (sec <= 0) return "0:00";
        let m = Math.floor(sec / 60);
        let s = sec % 60;
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    // --- CONTROLLER APIs ---
    function control(action) {
        controlProc.action = action;
        controlProc.running = true;
    }

    function seek(percentStr) {
        let pct = Math.max(0, Math.min(100, parseFloat(percentStr) || 0));

        if (root.activeSource === "mpris" && root.mprisLengthUs > 0) {
            root.mprisPositionSec =
                (root.mprisLengthUs / 1000000) * pct / 100;

            root.mprisPositionUpdatedAt = Date.now();

            root.mprisElapsedTime =
                root.formatTime(Math.floor(root.mprisPositionSec));

            root.mprisPercent = pct;
        }

        seekProc.percentStr = pct + "%";
        seekProc.running = true;
    }

    function toggleSource() {
        root.activeSource = (root.activeSource === "mpd") ? "mpris" : "mpd";
        statusProc.running = true;
        coverExtractor.running = true;
    }

    // Status fetch daemon
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            statusProc.running = true;
        }
    }

    Component.onCompleted: {
        statusProc.running = true;
        coverExtractor.running = true;
    }

    Timer {
        id: seekStatusRefresh
        interval: 300
        repeat: false

        onTriggered: {
            if (statusProc.running) {
                restart();
            } else {
                statusProc.running = true;
            }
        }
    }

    // ==========================================
    // DATA-FETCHING PROCESSES
    // ==========================================

    // 1. Dual-Source Status Parser
    Process {
        id: statusProc
        command: {
            if (root.activeSource === "mpd") {
                return ["sh", "-c", "mpc status --format '%title%\n%artist%'"];
            } else {
                return ["sh", "-c",
                    "playerctl metadata --format '{{title}}\n{{artist}}\n{{position}}\n{{mpris:length}}\n{{xesam:url}}\n{{mpris:artUrl}}' 2>/dev/null; " +
                    "playerctl status 2>/dev/null"
                ];
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n");
                
                // Parse MPD
                if (root.activeSource === "mpd") {
                    if (lines.length >= 3) {
                        root.mpdTitle = lines[0] !== "" ? lines[0] : "No Title";
                        root.mpdArtist = lines[1] !== "" ? lines[1] : "Unknown Artist";
                        
                        let statusLine = lines[2];
                        root.mpdIsPlaying = statusLine.includes("[playing]");
                        
                        if (statusLine.includes("/")) {
                            let parts = statusLine.replace(/\s+/g, " ").split(" ");
                            let timeParts = parts[2].split("/");
                            root.mpdElapsedTime = timeParts[0];
                            root.mpdTotalDuration = timeParts[1];
                            root.mpdPercent = parseFloat(parts[3].replace(/[^0-9]/g, "")) || 0;
                        }
                    } else {
                        root.mpdTitle = "Not Playing";
                        root.mpdArtist = "No Active Media";
                        root.mpdElapsedTime = "0:00";
                        root.mpdTotalDuration = "0:00";
                        root.mpdPercent = 0;
                        root.mpdIsPlaying = false;
                    }
                } 
                // Parse MPRIS
                else {
                    if (lines.length >= 7) {
                        let incomingTitle = lines[0] !== "" ? lines[0] : "No Title";
                        let incomingArtist = lines[1] !== "" ? lines[1] : "Unknown Artist";

                        let pos = Number(lines[2]);
                        let len = Number(lines[3]);

                        let mediaUrl = (lines[4] || "").trim();
                        let artUrl = (lines[5] || "").trim();
                        let status = (lines[6] || "").trim();

                        // Firefox may reuse the same MPRIS track ID.
                        // Use the actual media URL instead.
                        let trackKey = mediaUrl !== ""
                            ? mediaUrl
                            : "title:" + incomingTitle;

                        let canUpdateTrackKey =
                            mediaUrl !== "" ||
                            root.mprisTrackKey === "" ||
                            root.mprisTrackKey.startsWith("title:");

                        // Detect a new track.
                        if (canUpdateTrackKey && trackKey !== root.mprisTrackKey) {
                            root.mprisTrackKey = trackKey;
                            root.mprisLengthUs = 0;
                            root.mprisPositionSec = 0;
                            root.mprisPositionUpdatedAt = Date.now();
                            root.mprisElapsedTime = "0:00";
                            root.mprisTotalDuration = "0:00";
                            root.mprisPercent = 0;

                            root.mprisArtworkKey = "";

                            coverDelay.restart();
                        }

                        // Detect artwork changes separately.
                        if (artUrl !== "" && artUrl !== root.mprisArtworkKey) {
                            root.mprisArtworkKey = artUrl;
                            coverDelay.restart();
                        }

                        root.mprisTitle = incomingTitle;
                        root.mprisArtist = incomingArtist;
                        root.mprisIsPlaying = (status === "Playing");

                        // Preserve the last valid duration.
                        if (Number.isFinite(len) && len > 0) {
                            root.mprisLengthUs = len;
                        }

                        let lenSec = root.mprisLengthUs / 1000000;

                        // Ignore suspicious near-zero position updates.
                        if (Number.isFinite(pos) && pos >= 1000000) {
                            root.mprisPositionSec = pos / 1000000;
                            root.mprisPositionUpdatedAt = Date.now();
                        }

                        let displayPosSec = root.mprisPositionSec;

                        if (root.mprisIsPlaying && root.mprisPositionUpdatedAt > 0) {
                            displayPosSec +=
                                (Date.now() - root.mprisPositionUpdatedAt) / 1000;
                        }

                        if (lenSec > 0) {
                            displayPosSec = Math.min(displayPosSec, lenSec);

                            root.mprisElapsedTime =
                                root.formatTime(Math.floor(displayPosSec));

                            root.mprisTotalDuration = root.formatTime(lenSec);

                            root.mprisPercent = Math.max(
                                0,
                                Math.min(100, displayPosSec * 100 / lenSec)
                            );
                        }

                    }
                }
            }
        }
    }

    // 2. Playback Controller
    Process {
        id: controlProc
        property string action: ""
        command: {
            if (root.activeSource === "mpd") {
                return ["mpc", action];
            } else {
                let mprisAction = action;
                if (action === "toggle") mprisAction = "play-pause";
                return ["playerctl", mprisAction];
            }
        }
        onRunningChanged: { if (!running) statusProc.running = true; }
    }

    // 3. Timeline Seeker
    Process {
        id: seekProc
        property string percentStr: ""
        command: {
            if (root.activeSource === "mpd") {
                return ["mpc", "seek", percentStr];
            } else {
                let pct = Math.max(
                    0,
                    Math.min(100, parseInt(percentStr, 10) || 0)
                );

                let lenSec = Math.floor(root.mprisLengthUs / 1000000);
                let targetSec = Math.floor(lenSec * pct / 100);

                return ["playerctl", "position", String(targetSec)];
            }
        }
        onRunningChanged: {
            if (!running)
                seekStatusRefresh.restart();
        }
    }

    // 4. Dual-Source Cover Extractor & Downloader (Pristine isolation!)
    Process {
        id: coverExtractor
        command: {
            if (root.activeSource === "mpd") {
                return ["sh", "-c", "FILE=$(mpc --format '%file%' current | head -n1) && mpc readpicture \"$FILE\" > /tmp/cover_mpd.tmp 2>/dev/null && mv /tmp/cover_mpd.tmp /tmp/cover_mpd 2>/dev/null"];
            } else {
                return ["sh", "-c",
                    "ART_URL=$(playerctl metadata mpris:artUrl 2>/dev/null); " +
                    "MEDIA_URL=$(playerctl metadata xesam:url 2>/dev/null); " +
                    "rm -f /tmp/cover_mpris.tmp; " +
                    "if [ -n \"$ART_URL\" ]; then " +
                        "if echo \"$ART_URL\" | grep -q '^file://'; then " +
                            "cp \"${ART_URL#file://}\" /tmp/cover_mpris.tmp 2>/dev/null; " +
                        "else " +
                            "curl -fLsS \"$ART_URL\" -o /tmp/cover_mpris.tmp 2>/dev/null; " +
                        "fi; " +
                    "else " +
                        "VIDEO_ID=${MEDIA_URL#*v=}; " +
                        "VIDEO_ID=${VIDEO_ID%%&*}; " +
                        "case \"$MEDIA_URL\" in *youtu.be/*) VIDEO_ID=${MEDIA_URL##*/}; VIDEO_ID=${VIDEO_ID%%\\?*} ;; esac; " +
                        "if [ -n \"$VIDEO_ID\" ] && [ \"$VIDEO_ID\" != \"$MEDIA_URL\" ]; then " +
                            "curl -fLsS \"https://img.youtube.com/vi/$VIDEO_ID/hqdefault.jpg\" -o /tmp/cover_mpris.tmp 2>/dev/null; " +
                        "fi; " +
                    "fi; " +
                    "if [ -s /tmp/cover_mpris.tmp ]; then " +
                        "mv /tmp/cover_mpris.tmp /tmp/cover_mpris.jpg; " +
                    "fi"
                ];
            }
        }
        stdout: SplitParser {}
        onRunningChanged: {
            if (!running) {
                // Increment only the correct active version to force reload
                if (root.activeSource === "mpd") {
                    root.mpdCoverVersion++;
                } else {
                    root.mprisCoverVersion++;
                }
            }
        }
    }

    // 5. Watcher Loops
    Process {
        id: mediaWatcher
        command: {
            if (root.activeSource === "mpd") {
                return ["mpc", "idleloop", "player"];
            } else {
                return ["playerctl", "-F", "metadata"];
            }
        }
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (root.activeSource === "mpd")
                    coverDelay.restart();

                statusProc.running = true;
            }
        }
    }

    Timer {
        id: coverDelay
        interval: 500
        repeat: false

        onTriggered: {
            if (coverExtractor.running) {
                restart();
            } else {
                coverExtractor.running = true;
            }
        }
    }

    Timer {
        id: mprisProgressTimer
        interval: 250
        repeat: true

        running: root.activeSource === "mpris"
                && root.mprisLengthUs > 0

        onTriggered: {
            if (root.mprisPositionUpdatedAt <= 0)
                return;

            let len = root.mprisLengthUs / 1000000;
            let pos = root.mprisPositionSec;

            if (root.mprisIsPlaying) {
                pos += (Date.now() - root.mprisPositionUpdatedAt) / 1000;
            }

            pos = Math.max(0, Math.min(pos, len));

            root.mprisElapsedTime =
                root.formatTime(Math.floor(pos));

            root.mprisPercent = pos * 100 / len;
        }
    }
}