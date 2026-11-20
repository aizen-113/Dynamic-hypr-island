
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ==========================================
    // CPU DATA
    // ==========================================

    property real cpu: 0
    property real cpuTempC: -1

    property real prevTotal: 0
    property real prevIdle: 0

    // ==========================================
    // MEMORY DATA
    // ==========================================

    property real ram: 0
    property real ramUsedBytes: 0
    property real ramTotalBytes: 0

    // ==========================================
    // NETWORK DATA
    // ==========================================

    property string networkInterface: ""

    property real downloadBps: 0
    property real uploadBps: 0

    property real downloadedTotalBytes: 0
    property real uploadedTotalBytes: 0

    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real prevNetworkSampleAt: 0
    property string prevNetworkInterface: ""

    property bool networkConnected: false

    // ==========================================
    // STORAGE DATA
    // ==========================================

    property var storageDevices: []

    // ==========================================
    // PUBLIC DATA INTERFACE
    // ==========================================

    readonly property var output: ({
        cpu: {
            usagePercent: root.cpu,
            temperatureC: root.cpuTempC
        },

        memory: {
            usedPercent: root.ram,
            usedBytes: root.ramUsedBytes,
            totalBytes: root.ramTotalBytes
        },

        network: {
            connected: root.networkConnected,
            interface: root.networkInterface,

            downloadBytesPerSecond: root.downloadBps,
            uploadBytesPerSecond: root.uploadBps,

            downloadedTotalBytes: root.downloadedTotalBytes,
            uploadedTotalBytes: root.uploadedTotalBytes,

            totalTransferredBytes:
                root.downloadedTotalBytes +
                root.uploadedTotalBytes,

            counterScope: "interface-lifetime"
        },

        storage: root.storageDevices
    })

    // ==========================================
    // REFRESH CONTROLLER
    // ==========================================

    function refresh() {
        if (!root.cpuMemProcess.running)
            root.cpuMemProcess.running = true;

        if (!root.temperatureProcess.running)
            root.temperatureProcess.running = true;

        if (!root.networkProcess.running)
            root.networkProcess.running = true;

        if (!root.storageProcess.running)
            root.storageProcess.running = true;
    }

    // ==========================================
    // 1. CPU + RAM PROCESS
    // ==========================================

    property var cpuMemProcess: Process {
        id: cpuMemProcessObject

        command: [
            "sh",
            "-c",
            "cat /proc/stat | grep '^cpu ' && " +
            "cat /proc/meminfo | grep -E 'MemTotal|MemAvailable'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");

                if (lines.length < 3)
                    return;

                // CPU calculation
                const cpuParts = lines[0]
                    .replace(/\s+/g, " ")
                    .trim()
                    .split(" ");

                const user = Number(cpuParts[1]) || 0;
                const nice = Number(cpuParts[2]) || 0;
                const system = Number(cpuParts[3]) || 0;
                const idle = Number(cpuParts[4]) || 0;
                const iowait = Number(cpuParts[5]) || 0;
                const irq = Number(cpuParts[6]) || 0;
                const softirq = Number(cpuParts[7]) || 0;
                const steal = Number(cpuParts[8]) || 0;

                const total =
                    user + nice + system + idle +
                    iowait + irq + softirq + steal;

                const idleTime = idle + iowait;

                if (root.prevTotal > 0) {
                    const diffTotal = total - root.prevTotal;
                    const diffIdle = idleTime - root.prevIdle;

                    if (diffTotal > 0) {
                        root.cpu = Math.max(
                            0,
                            Math.min(
                                100,
                                ((diffTotal - diffIdle) / diffTotal) * 100
                            )
                        );
                    }
                }

                root.prevTotal = total;
                root.prevIdle = idleTime;

                // RAM calculation
                let totalMem = 0;
                let availMem = 0;

                for (let i = 1; i < lines.length; i++) {
                    const parts = lines[i].trim().split(/\s+/);

                    if (parts[0] === "MemTotal:") {
                        totalMem = Number(parts[1]) || 0;
                    }

                    if (parts[0] === "MemAvailable:") {
                        availMem = Number(parts[1]) || 0;
                    }
                }

                if (totalMem > 0) {
                    const usedMem = Math.max(0, totalMem - availMem);

                    root.ram = Math.max(
                        0,
                        Math.min(100, usedMem * 100 / totalMem)
                    );

                    // /proc/meminfo reports kB.
                    root.ramTotalBytes = totalMem * 1024;
                    root.ramUsedBytes = usedMem * 1024;
                }
            }
        }
    }

    // ==========================================
    // 2. CPU TEMPERATURE PROCESS
    // ==========================================

    property var temperatureProcess: Process {
        id: temperatureProcessObject

        command: [
            "sh",
            "-c",

            "for h in /sys/class/hwmon/hwmon*; do " +
                "[ -r \"$h/name\" ] || continue; " +
                "name=$(cat \"$h/name\" 2>/dev/null); " +

                "for input in \"$h\"/temp*_input; do " +
                    "[ -r \"$input\" ] || continue; " +

                    "value=$(cat \"$input\" 2>/dev/null); " +
                    "labelFile=\"${input%_input}_label\"; " +
                    "label=''; " +

                    "if [ -r \"$labelFile\" ]; then " +
                        "label=$(cat \"$labelFile\" 2>/dev/null); " +
                    "fi; " +

                    "printf 'H|%s|%s|%s\\n' \"$name\" \"$label\" \"$value\"; " +
                "done; " +
            "done; " +

            "for zone in /sys/class/thermal/thermal_zone*; do " +
                "[ -r \"$zone/temp\" ] || continue; " +

                "type=$(cat \"$zone/type\" 2>/dev/null); " +
                "value=$(cat \"$zone/temp\" 2>/dev/null); " +

                "printf 'Z|%s||%s\\n' \"$type\" \"$value\"; " +
            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let bestTemperature = -1;
                let bestScore = -1;

                const lines = text.trim().split("\n");

                for (const line of lines) {
                    const parts = line.split("|");

                    if (parts.length < 4)
                        continue;

                    const kind = parts[0];
                    const name = parts[1].toLowerCase();
                    const label = parts[2].toLowerCase();

                    const raw = Number(parts[3]);

                    if (!Number.isFinite(raw))
                        continue;

                    // hwmon and thermal sysfs values use millidegrees C.
                    const temp = raw / 1000;

                    if (temp < -20 || temp > 150)
                        continue;

                    let score = -1;

                    if (kind === "Z") {
                        if (name.includes("x86_pkg_temp"))
                            score = 120;
                        else if (name.includes("cpu"))
                            score = 100;
                        else if (name.includes("soc"))
                            score = 60;
                    } else {
                        if (name.includes("coretemp"))
                            score = 70;

                        if (name.includes("k10temp"))
                            score = 70;

                        if (name.includes("cpu"))
                            score = Math.max(score, 80);

                        if (
                            label.includes("package") ||
                            label.includes("physical id")
                        ) {
                            score += 50;
                        }

                        if (label.includes("tctl"))
                            score += 45;
                        else if (label.includes("tdie"))
                            score += 40;

                        if (label.includes("core"))
                            score += 20;

                        if (label.includes("cpu"))
                            score += 45;
                    }

                    // Prefer a package-level sensor.
                    // If only core temperatures are present,
                    // prefer the hottest core.
                    if (
                        score > bestScore ||
                        (score === bestScore && temp > bestTemperature)
                    ) {
                        bestScore = score;
                        bestTemperature = temp;
                    }
                }

                root.cpuTempC = bestScore >= 0
                    ? bestTemperature
                    : -1;
            }
        }
    }

    // ==========================================
    // 3. NETWORK PROCESS
    // ==========================================

    property var networkProcess: Process {
        id: networkProcessObject

        command: [
            "sh",
            "-c",

            "iface=$(ip -o route show default 2>/dev/null | " +
                "awk 'NR == 1 { for (i = 1; i <= NF; i++) " +
                "if ($i == \"dev\") { print $(i + 1); exit } }'); " +

            "if [ -z \"$iface\" ]; then " +
                "iface=$(ip -6 -o route show default 2>/dev/null | " +
                "awk 'NR == 1 { for (i = 1; i <= NF; i++) " +
                "if ($i == \"dev\") { print $(i + 1); exit } }'); " +
            "fi; " +

            "if [ -n \"$iface\" ]; then " +
                "base=\"/sys/class/net/$iface/statistics\"; " +

                "if [ -r \"$base/rx_bytes\" ] && " +
                   "[ -r \"$base/tx_bytes\" ]; then " +

                    "rx=$(cat \"$base/rx_bytes\"); " +
                    "tx=$(cat \"$base/tx_bytes\"); " +

                    "printf '%s|%s|%s\\n' \"$iface\" \"$rx\" \"$tx\"; " +
                "fi; " +
            "fi"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();

                if (line.length === 0) {
                    root.networkConnected = false;
                    root.downloadBps = 0;
                    root.uploadBps = 0;

                    root.prevNetworkInterface = "";
                    root.prevNetworkSampleAt = 0;
                    return;
                }

                const parts = line.split("|");

                if (parts.length < 3)
                    return;

                const iface = parts[0];
                const rx = Number(parts[1]);
                const tx = Number(parts[2]);

                if (
                    !Number.isFinite(rx) ||
                    !Number.isFinite(tx)
                )
                    return;

                const now = Date.now();

                root.networkConnected = true;
                root.networkInterface = iface;

                // Calculate rates only when the interface
                // and both counters are continuous.
                if (
                    root.prevNetworkInterface === iface &&
                    root.prevNetworkSampleAt > 0 &&
                    rx >= root.prevRxBytes &&
                    tx >= root.prevTxBytes
                ) {
                    const elapsed =
                        (now - root.prevNetworkSampleAt) / 1000;

                    if (elapsed > 0) {
                        root.downloadBps =
                            (rx - root.prevRxBytes) / elapsed;

                        root.uploadBps =
                            (tx - root.prevTxBytes) / elapsed;
                    }
                } else {
                    // First sample or interface/counter reset.
                    root.downloadBps = 0;
                    root.uploadBps = 0;
                }

                // Kernel interface counters.
                root.downloadedTotalBytes = rx;
                root.uploadedTotalBytes = tx;

                root.prevRxBytes = rx;
                root.prevTxBytes = tx;

                root.prevNetworkInterface = iface;
                root.prevNetworkSampleAt = now;
            }
        }
    }

    // ==========================================
    // 4. STORAGE PROCESS
    // ==========================================

    property var storageProcess: Process {
        id: storageProcessObject

        command: [
            "df",
            "-B1",
            "-P",
            "-l",
            "--output=source,size,used,avail,pcent,target",
            "-x", "tmpfs",
            "-x", "devtmpfs",
            "-x", "squashfs",
            "-x", "overlay",
            "-x", "efivarfs",
            "-x", "proc",
            "-x", "sysfs",
            "-x", "cgroup",
            "-x", "cgroup2"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");

                const devices = [];

                // Skip the df header.
                for (let i = 1; i < lines.length; i++) {
                    const fields = lines[i].trim().split(/\s+/);

                    if (fields.length < 6)
                        continue;

                    const device = fields[0];

                    const total = Number(fields[1]);
                    const used = Number(fields[2]);
                    const available = Number(fields[3]);

                    const percent = Number(
                        fields[4].replace("%", "")
                    );

                    const mountPoint = fields
                        .slice(5)
                        .join(" ")
                        .replace(/\\040/g, " ");

                    if (
                        !Number.isFinite(total) ||
                        !Number.isFinite(used) ||
                        !Number.isFinite(available) ||
                        total <= 0
                    )
                        continue;

                    devices.push({
                        device: device,
                        mountPoint: mountPoint,

                        totalBytes: total,
                        usedBytes: used,
                        availableBytes: available,

                        usedPercent: percent
                    });
                }

                // Replace the complete array to notify consumers.
                root.storageDevices = devices;
            }
        }
    }

    // ==========================================
    // POLLING
    // ==========================================

    property var pollTimer: Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            root.refresh();
        }
    }

    property var storageTimer: Timer {
        interval: 15000
        running: true
        repeat: true

        onTriggered: {
            if (!root.storageProcess.running)
                root.storageProcess.running = true;
        }
    }

    Component.onCompleted: {
        root.refresh();
        console.log("[SystemStats] Backend started");
    }
}
