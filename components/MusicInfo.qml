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
    
    // 🔥 DEDICATED ISOLATED SLOTS (Never pollution each other!)
    property string coverPath: {
        if (activeSource === "mpd") {
            return "file:///tmp/cover_mpd.png?" + mpdCoverVersion;
        } else {
            return "file:///tmp/cover_mpris.png?" + mprisCoverVersion;
        }
    }

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
        seekProc.percentStr = percentStr;
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
                return ["sh", "-c", "playerctl metadata --format '{{title}}\n{{artist}}\n{{position}}\n{{mpris:length}}' 2>/dev/null && playerctl status 2>/dev/null"];
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
                    if (lines.length >= 5) {
                        root.mprisTitle = lines[0] !== "" ? lines[0] : "No Title";
                        root.mprisArtist = lines[1] !== "" ? lines[1] : "Unknown Artist";
                        
                        let pos = parseFloat(lines[2]) || 0;
                        let len = parseFloat(lines[3]) || 0;
                        let status = lines[4];
                        root.mprisIsPlaying = (status === "Playing");
                        
                        let len_sec = Math.round(len / 1000000);
                        let pos_sec = Math.round(pos);
                        
                        root.mprisElapsedTime = root.formatTime(pos_sec);
                        root.mprisTotalDuration = root.formatTime(len_sec);
                        root.mprisPercent = len_sec > 0 ? (pos_sec * 100 / len_sec) : 0;
                    } else {
                        root.mprisTitle = "Not Playing";
                        root.mprisArtist = "No Active Media";
                        root.mprisElapsedTime = "0:00";
                        root.mprisTotalDuration = "0:00";
                        root.mprisPercent = 0;
                        root.mprisIsPlaying = false;
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
                let pct = parseInt(percentStr.replace("%", "")) || 0;
                return ["sh", "-c", "LEN=$(playerctl metadata mpris:length 2>/dev/null) && LEN_SEC=$((LEN / 1000000)) && TARGET_SEC=$((LEN_SEC * " + pct + " / 100)) && playerctl position $TARGET_SEC 2>/dev/null"];
            }
        }
        onRunningChanged: { if (!running) statusProc.running = true; }
    }

    // 4. Dual-Source Cover Extractor & Downloader (Pristine isolation!)
    Process {
        id: coverExtractor
        command: {
            if (root.activeSource === "mpd") {
                return ["sh", "-c", "FILE=$(mpc --format '%file%' current | head -n1) && mpc readpicture \"$FILE\" > /tmp/cover_mpd.tmp 2>/dev/null && mv /tmp/cover_mpd.tmp /tmp/cover_mpd.png 2>/dev/null"];
            } else {
                return ["sh", "-c", "ART_URL=$(playerctl metadata mpris:artUrl 2>/dev/null) && if [ -n \"$ART_URL\" ]; then if echo \"$ART_URL\" | grep -q '^file://'; then cp \"${ART_URL#file://}\" /tmp/cover_mpris.png 2>/dev/null; else curl -s \"$ART_URL\" > /tmp/cover_mpris.tmp 2>/dev/null && mv /tmp/cover_mpris.tmp /tmp/cover_mpris.png 2>/dev/null; fi; fi"];
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
                coverDelay.restart();
                statusProc.running = true;
            }
        }
    }

    Timer { id: coverDelay; interval: 300; repeat: false; onTriggered: { coverExtractor.running = true; } }
}