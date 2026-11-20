
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ==============================================
    // PROVIDER LIFECYCLE
    // ==============================================

    // Keep false unless the Controls page is active.
    property bool active: false

    // ==============================================
    // 1. AUDIO / VOLUME
    // ==============================================

    property real volume: 50
    property bool volumeMuted: false
    property bool volumeAvailable: false

    property real requestedVolume: 50
    property real volumeCommandValue: 50

    property bool requestedMute: false

    // ==============================================
    // 2. DISPLAY / BRIGHTNESS
    // ==============================================

    property real brightness: 50
    property bool brightnessAvailable: false

    property real requestedBrightness: 50
    property real brightnessCommandValue: 50

    // ==============================================
    // 3. GAMMASTEP
    // ==============================================

    property bool gammastepEnabled: false
    property int colorTemperatureKelvin: 4500

    readonly property int minTemperatureKelvin: 2500
    readonly property int maxTemperatureKelvin: 6500

    property string gammastepLastError: ""

    property var gammastepCommand: []
    property var queuedGammastepCommand: []
    property bool gammastepCommandQueued: false

    // ==============================================
    // 4. WI-FI
    // ==============================================

    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property bool wifiConnected: false

    property string wifiInterface: ""
    property string wifiConnectionName: ""
    property string wifiConnectedSsid: ""

    property var wifiNetworks: []

    property bool wifiRescanRequested: false
    property bool wifiConnectionBusy: false

    property string wifiLastMessage: ""
    property string wifiLastError: ""

    // Temporary connection data.
    // Password is deliberately excluded from output.
    property string pendingWifiSsid: ""
    property string pendingWifiPassword: ""
    property string pendingWifiUuid: ""
    property string wifiOperation: ""

    property var wifiConnectionCommand: ["nmcli"]

    // ==============================================
    // 5. BLUETOOTH
    // ==============================================

    property bool bluetoothAvailable: false
    property bool bluetoothPowered: false
    property bool bluetoothDiscovering: false

    property string bluetoothAdapterName: ""

    property bool bluetoothBusy: false
    property bool bluetoothScanAfterPower: false

    property string bluetoothLastMessage: ""
    property string bluetoothLastError: ""

    property var bluetoothKnownRaw: []
    property var bluetoothPairedRaw: []
    property var bluetoothConnectedRaw: []

    property var bluetoothDevices: []
    property var bluetoothPairedDevices: []
    property var bluetoothDiscoveredDevices: []
    property var bluetoothConnectedDevices: []

    property var bluetoothCommand: ["bluetoothctl", "show"]

    // ==============================================
    // PUBLIC DATA INTERFACE
    // ==============================================

    readonly property var output: ({

        volume: {
            percent: root.volume,
            muted: root.volumeMuted,
            available: root.volumeAvailable,
            minimum: 0,
            maximum: 100
        },

        brightness: {
            percent: root.brightness,
            available: root.brightnessAvailable,
            minimum: 0,
            maximum: 100
        },

        gammastep: {
            enabled: root.gammastepEnabled,
            temperatureKelvin: root.colorTemperatureKelvin,
            minimumKelvin: root.minTemperatureKelvin,
            maximumKelvin: root.maxTemperatureKelvin,
            lastError: root.gammastepLastError
        },

        wifi: {
            available: root.wifiAvailable,
            enabled: root.wifiEnabled,
            connected: root.wifiConnected,

            interface: root.wifiInterface,
            connectionName: root.wifiConnectionName,
            connectedSsid: root.wifiConnectedSsid,

            networks: root.wifiNetworks,

            busy: root.wifiConnectionBusy,
            lastMessage: root.wifiLastMessage,
            lastError: root.wifiLastError
        },

        bluetooth: {
            available: root.bluetoothAvailable,
            powered: root.bluetoothPowered,
            discovering: root.bluetoothDiscovering,

            adapterName: root.bluetoothAdapterName,

            devices: root.bluetoothDevices,
            pairedDevices: root.bluetoothPairedDevices,
            discoveredDevices: root.bluetoothDiscoveredDevices,
            connectedDevices: root.bluetoothConnectedDevices,

            busy: root.bluetoothBusy,
            lastMessage: root.bluetoothLastMessage,
            lastError: root.bluetoothLastError
        }
    })

    // ==============================================
    // COMMON HELPERS
    // ==============================================

    function clampPercent(value) {
        const n = Number(value);

        if (!Number.isFinite(n))
            return null;

        return Math.max(0, Math.min(100, n));
    }

    function startProcess(processObject) {
        if (processObject && !processObject.running)
            processObject.running = true;
    }

    // ==============================================
    // VOLUME API
    // ==============================================

    function setVolume(value) {
        const pct = root.clampPercent(value);

        if (pct === null)
            return;

        root.volume = pct;
        root.requestedVolume = pct;

        if (!volumeSetter.running) {
            root.volumeCommandValue = pct;
            volumeSetter.running = true;
        }
    }

    function setVolumeMuted(muted) {
        root.requestedMute = Boolean(muted);
        startProcess(muteSetter);
    }

    function toggleVolumeMute() {
        root.setVolumeMuted(!root.volumeMuted);
    }

    function refreshVolume() {
        startProcess(volumeGetter);
    }

    // ==============================================
    // BRIGHTNESS API
    // ==============================================

    function setBrightness(value) {
        const pct = root.clampPercent(value);

        if (pct === null)
            return;

        root.brightness = pct;
        root.requestedBrightness = pct;

        if (!brightnessSetter.running) {
            root.brightnessCommandValue = pct;
            brightnessSetter.running = true;
        }
    }

    function refreshBrightness() {
        startProcess(brightnessGetter);
    }

    // ==============================================
    // GAMMASTEP API
    // ==============================================

    function runGammastep(command) {
        root.queuedGammastepCommand = command;

        if (!gammastepProcess.running) {
            root.gammastepCommand = command;
            root.gammastepCommandQueued = false;
            gammastepProcess.running = true;
        } else {
            root.gammastepCommandQueued = true;
        }
    }

    function setGammastepEnabled(enabled) {
        root.gammastepEnabled = Boolean(enabled);

        if (root.gammastepEnabled) {
            root.runGammastep([
                "gammastep",
                "-m", "wayland",
                "-O", String(root.colorTemperatureKelvin)
            ]);
        } else {
            root.runGammastep([
                "gammastep",
                "-m", "wayland",
                "-x"
            ]);
        }
    }

    function setColorTemperature(kelvin) {
        const n = Number(kelvin);

        if (!Number.isFinite(n))
            return;

        root.colorTemperatureKelvin = Math.round(
            Math.max(
                root.minTemperatureKelvin,
                Math.min(root.maxTemperatureKelvin, n)
            )
        );

        if (root.gammastepEnabled) {
            root.runGammastep([
                "gammastep",
                "-m", "wayland",
                "-O", String(root.colorTemperatureKelvin)
            ]);
        }
    }

    // ==============================================
    // WI-FI PARSERS
    // ==============================================

    function parseWifiNetworks(rawText) {
        const result = [];

        let current = null;

        const lines = rawText.split("\n");

        function finishRecord() {
            if (current !== null)
                result.push(current);
        }

        for (const rawLine of lines) {
            const line = rawLine.trim();

            if (line.length === 0)
                continue;

            const separator = line.indexOf(":");

            if (separator < 0)
                continue;

            const key = line.slice(0, separator).trim();
            const value = line.slice(separator + 1).trim();

            if (key === "IN-USE") {
                finishRecord();

                current = {
                    inUse: value === "*",
                    ssid: "",
                    bssid: "",
                    signal: 0,
                    security: ""
                };

                continue;
            }

            if (current === null)
                continue;

            if (key === "SSID")
                current.ssid = value;

            else if (key === "BSSID")
                current.bssid = value;

            else if (key === "SIGNAL")
                current.signal = Number(value) || 0;

            else if (key === "SECURITY")
                current.security = value;
        }

        finishRecord();

        return result;
    }

    function parseWifiDeviceStatus(rawText) {
        const records = [];

        let current = {};

        for (const rawLine of rawText.split("\n")) {
            const line = rawLine.trim();

            const separator = line.indexOf(":");

            if (separator < 0)
                continue;

            const key = line.slice(0, separator).trim();
            const value = line.slice(separator + 1).trim();

            if (key === "GENERAL.DEVICE") {
                if (current.device)
                    records.push(current);

                current = {
                    device: value,
                    type: "",
                    state: "",
                    connection: ""
                };

                continue;
            }

            if (key === "GENERAL.TYPE")
                current.type = value;

            else if (key === "GENERAL.STATE")
                current.state = value;

            else if (key === "GENERAL.CONNECTION")
                current.connection = value;
        }

        if (current.device)
            records.push(current);

        const wifi = records.find(
            device => device.type.toLowerCase() === "wifi"
        );

        if (!wifi) {
            root.wifiInterface = "";
            root.wifiConnectionName = "";
            root.wifiConnected = false;
            return;
        }

        root.wifiInterface = wifi.device;
        root.wifiConnectionName = wifi.connection;

        const state = wifi.state.toLowerCase();

        root.wifiConnected =
            /^\s*100\s+\(connected\)/i.test(state) ||
            state === "connected";
    }

    // ==============================================
    // WI-FI REFRESH
    // ==============================================

    function refreshWifi(forceScan) {
        if (forceScan === true)
            root.wifiRescanRequested = true;

        startProcess(wifiRadioGetter);
        startProcess(wifiDeviceGetter);
        startProcess(wifiNetworksGetter);
    }

    function scanWifi() {
        root.refreshWifi(true);
    }

    function setWifiEnabled(enabled) {
        root.requestedWifiEnabled = Boolean(enabled);
        startProcess(wifiRadioSetter);
    }

    function connectWifi(ssid, password, bssid) {
        const network = String(ssid || "").trim();

        if (network.length === 0)
            return;

        const args = [
            "nmcli",
            "device",
            "wifi",
            "connect",
            network
        ];

        const secret = String(password || "");

        if (secret.length > 0)
            args.push("password", secret);

        const accessPoint = String(bssid || "").trim();

        if (accessPoint.length > 0)
            args.push("bssid", accessPoint);

        root.pendingWifiSsid = network;
        root.pendingWifiPassword = secret;
        root.wifiOperation = "connect";

        root.startWifiOperation(args);
    }

    function connectSavedWifi(uuid) {
        const value = String(uuid || "").trim();

        if (value.length === 0)
            return;

        root.pendingWifiUuid = value;
        root.wifiOperation = "saved";

        root.startWifiOperation([
            "nmcli",
            "connection",
            "up",
            "uuid",
            value
        ]);
    }

    function disconnectWifi() {
        if (root.wifiInterface.length === 0)
            return;

        root.wifiOperation = "disconnect";

        root.startWifiOperation([
            "nmcli",
            "device",
            "disconnect",
            root.wifiInterface
        ]);
    }

    function startWifiOperation(args) {
        if (wifiConnectionProcess.running)
            return;

        root.wifiLastMessage = "";
        root.wifiLastError = "";
        root.wifiConnectionCommand = args;
        root.wifiConnectionBusy = true;

        wifiConnectionProcess.running = true;
    }

    // ==============================================
    // WI-FI PROCESSES
    // ==============================================

    property bool requestedWifiEnabled: false

    property var wifiRadioGetter: Process {
        id: wifiRadioGetter

        running: false

        command: [
            "nmcli",
            "-t",
            "-f", "WIFI",
            "general"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const status = text.trim().toLowerCase();

                if (status === "enabled" || status === "disabled") {
                    root.wifiAvailable = true;
                    root.wifiEnabled = status === "enabled";
                }
            }
        }
    }

    property var wifiDeviceGetter: Process {
        id: wifiDeviceGetter

        running: false

        command: [
            "nmcli",
            "--mode", "multiline",
            "--fields",
            "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION",
            "device",
            "show"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseWifiDeviceStatus(text);
            }
        }
    }

    property var wifiNetworksGetter: Process {
        id: wifiNetworksGetter

        running: false

        command: [
            "nmcli",
            "--mode", "multiline",
            "--fields",
            "IN-USE,SSID,BSSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list",
            "--rescan",
            root.wifiRescanRequested ? "yes" : "no"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiNetworks =
                    root.parseWifiNetworks(text);

                const activeNetwork = root.wifiNetworks.find(
                    network => network.inUse
                );

                root.wifiConnectedSsid = activeNetwork
                    ? activeNetwork.ssid
                    : "";
            }
        }

        onRunningChanged: {
            if (!running)
                root.wifiRescanRequested = false;
        }
    }

    property var wifiRadioSetter: Process {
        id: wifiRadioSetter

        running: false

        command: [
            "nmcli",
            "radio",
            "wifi",
            root.requestedWifiEnabled ? "on" : "off"
        ]

        onRunningChanged: {
            if (!running)
                root.refreshWifi(false);
        }
    }

    property var wifiConnectionProcess: Process {
        id: wifiConnectionProcess

        running: false

        command: root.wifiConnectionCommand

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiLastMessage = text.trim();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.wifiLastError = text.trim();
            }
        }

        onRunningChanged: {
            if (!running) {
                root.wifiConnectionBusy = false;

                // Clear temporary credentials and command arguments.
                root.pendingWifiPassword = "";
                root.pendingWifiSsid = "";
                root.pendingWifiUuid = "";

                root.wifiConnectionCommand = ["nmcli"];

                root.refreshWifi(false);
            }
        }
    }

    // ==============================================
    // BLUETOOTH PARSERS
    // ==============================================

    function parseBluetoothDevices(rawText) {
        const result = [];

        for (const rawLine of rawText.split("\n")) {
            const line = rawLine.trim();

            const match = line.match(
                /^Device\s+([0-9A-Fa-f:]{17})\s*(.*)$/
            );

            if (!match)
                continue;

            result.push({
                address: match[1].toUpperCase(),
                name: match[2].trim()
            });
        }

        return result;
    }

    function rebuildBluetoothDevices() {
        const merged = {};

        function addDevices(list, flag) {
            for (const device of list) {
                const address = device.address.toUpperCase();

                if (!merged[address]) {
                    merged[address] = {
                        address: address,
                        name: device.name,
                        paired: false,
                        connected: false,
                        discovered: false
                    };
                }

                if (device.name.length > 0)
                    merged[address].name = device.name;

                merged[address][flag] = true;
            }
        }

        addDevices(root.bluetoothKnownRaw, "discovered");
        addDevices(root.bluetoothPairedRaw, "paired");
        addDevices(root.bluetoothConnectedRaw, "connected");

        const devices = Object.keys(merged)
            .map(address => merged[address])
            .sort((a, b) => a.name.localeCompare(b.name));

        root.bluetoothDevices = devices;

        root.bluetoothPairedDevices =
            devices.filter(device => device.paired);

        root.bluetoothDiscoveredDevices =
            devices.filter(device => !device.paired);

        root.bluetoothConnectedDevices =
            devices.filter(device => device.connected);
    }

    // ==============================================
    // BLUETOOTH REFRESH
    // ==============================================

    function refreshBluetooth() {
        startProcess(bluetoothAdapterGetter);
        startProcess(bluetoothDevicesGetter);
        startProcess(bluetoothPairedGetter);
        startProcess(bluetoothConnectedGetter);
    }

    function runBluetoothCommand(command) {
        if (bluetoothActionProcess.running)
            return false;

        root.bluetoothLastMessage = "";
        root.bluetoothLastError = "";

        root.bluetoothCommand = command;
        root.bluetoothBusy = true;

        bluetoothActionProcess.running = true;

        return true;
    }

    // ==============================================
    // BLUETOOTH POWER
    // ==============================================

    function setBluetoothPowered(enabled) {
        const value = Boolean(enabled);

        if (!value)
            root.bluetoothScanAfterPower = false;

        root.runBluetoothCommand([
            "bluetoothctl",
            "power",
            value ? "on" : "off"
        ]);
    }

    // ==============================================
    // BLUETOOTH DISCOVERY
    // ==============================================

    function startBluetoothDiscovery() {
        if (bluetoothActionProcess.running)
            return;

        // Ensure the adapter is powered before scanning.
        if (!root.bluetoothPowered) {
            root.bluetoothScanAfterPower = true;

            root.runBluetoothCommand([
                "bluetoothctl",
                "power",
                "on"
            ]);

            return;
        }

        root.runBluetoothCommand([
            "bluetoothctl",
            "scan",
            "on"
        ]);
    }

    function stopBluetoothDiscovery() {
        root.bluetoothScanAfterPower = false;

        root.runBluetoothCommand([
            "bluetoothctl",
            "scan",
            "off"
        ]);
    }

    // ==============================================
    // BLUETOOTH CONNECTIONS
    // ==============================================

    function connectBluetooth(address) {
        const mac = String(address || "").toUpperCase();

        if (!/^[0-9A-F]{2}(:[0-9A-F]{2}){5}$/.test(mac))
            return false;

        const isPaired = root.bluetoothPairedDevices.some(
            device => device.address === mac
        );

        // This initial version only connects paired devices.
        if (!isPaired) {
            root.bluetoothLastError =
                "Device is not paired yet.";

            return false;
        }

        return root.runBluetoothCommand([
            "bluetoothctl",
            "connect",
            mac
        ]);
    }

    function disconnectBluetooth(address) {
        const mac = String(address || "").toUpperCase();

        if (!/^[0-9A-F]{2}(:[0-9A-F]{2}){5}$/.test(mac))
            return false;

        return root.runBluetoothCommand([
            "bluetoothctl",
            "disconnect",
            mac
        ]);
    }

    // ==============================================
    // BLUETOOTH PROCESSES
    // ==============================================

    property var bluetoothAdapterGetter: Process {
        id: bluetoothAdapterGetter

        running: false

        command: [
            "bluetoothctl",
            "show"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const textValue = text;

                root.bluetoothAvailable =
                    /Controller\s+[0-9A-F:]{17}/i.test(textValue);

                const powered = textValue.match(
                    /^\s*Powered:\s*(yes|no)/im
                );

                const discovering = textValue.match(
                    /^\s*Discovering:\s*(yes|no)/im
                );

                const name = textValue.match(
                    /^\s*Name:\s*(.+)$/im
                );

                if (powered)
                    root.bluetoothPowered =
                        powered[1].toLowerCase() === "yes";

                if (discovering)
                    root.bluetoothDiscovering =
                        discovering[1].toLowerCase() === "yes";

                if (name)
                    root.bluetoothAdapterName = name[1].trim();
            }
        }
    }

    property var bluetoothDevicesGetter: Process {
        id: bluetoothDevicesGetter

        running: false

        command: [
            "bluetoothctl",
            "devices"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothKnownRaw =
                    root.parseBluetoothDevices(text);

                root.rebuildBluetoothDevices();
            }
        }
    }

    property var bluetoothPairedGetter: Process {
        id: bluetoothPairedGetter

        running: false

        command: [
            "bluetoothctl",
            "devices",
            "Paired"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothPairedRaw =
                    root.parseBluetoothDevices(text);

                root.rebuildBluetoothDevices();
            }
        }
    }

    property var bluetoothConnectedGetter: Process {
        id: bluetoothConnectedGetter

        running: false

        command: [
            "bluetoothctl",
            "devices",
            "Connected"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothConnectedRaw =
                    root.parseBluetoothDevices(text);

                root.rebuildBluetoothDevices();
            }
        }
    }

    property var bluetoothActionProcess: Process {
        id: bluetoothActionProcess

        running: false

        command: root.bluetoothCommand

        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothLastMessage = text.trim();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.bluetoothLastError = text.trim();
            }
        }

        onRunningChanged: {
            if (running)
                return;

            root.bluetoothBusy = false;

            if (root.bluetoothScanAfterPower) {
                root.bluetoothScanAfterPower = false;

                root.runBluetoothCommand([
                    "bluetoothctl",
                    "scan",
                    "on"
                ]);

                return;
            }

            root.refreshBluetooth();
        }
    }

    // ==============================================
    // GAMMASTEP PROCESS
    // ==============================================

    property var gammastepProcess: Process {
        id: gammastepProcess

        running: false

        command: root.gammastepCommand

        stdout: StdioCollector {
            onStreamFinished: {
                root.gammastepLastError = "";
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.gammastepLastError = text.trim();
            }
        }

        onRunningChanged: {
            if (running)
                return;

            if (root.gammastepCommandQueued) {
                root.gammastepCommand =
                    root.queuedGammastepCommand;

                root.gammastepCommandQueued = false;

                running = true;
            }
        }
    }

    // ==============================================
    // VOLUME PROCESSES
    // ==============================================

    property var volumeGetter: Process {
        id: volumeGetter

        running: false

        command: [
            "wpctl",
            "get-volume",
            "@DEFAULT_AUDIO_SINK@"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(
                    /Volume:\s*([0-9]*\.?[0-9]+)/
                );

                if (!match)
                    return;

                const value = Number(match[1]);

                if (!Number.isFinite(value))
                    return;

                root.volume = Math.max(
                    0,
                    Math.min(100, value * 100)
                );

                root.volumeMuted = text.includes("[MUTED]");
                root.volumeAvailable = true;
            }
        }
    }

    property var volumeSetter: Process {
        id: volumeSetter

        running: false

        command: [
            "wpctl",
            "set-volume",
            "@DEFAULT_AUDIO_SINK@",
            String(Math.round(root.volumeCommandValue)) + "%"
        ]

        onRunningChanged: {
            if (running)
                return;

            if (root.requestedVolume !== root.volumeCommandValue) {
                root.volumeCommandValue = root.requestedVolume;
                running = true;
            } else {
                root.refreshVolume();
            }
        }
    }

    property var muteSetter: Process {
        id: muteSetter

        running: false

        command: [
            "wpctl",
            "set-mute",
            "@DEFAULT_AUDIO_SINK@",
            root.requestedMute ? "1" : "0"
        ]

        onRunningChanged: {
            if (!running)
                root.refreshVolume();
        }
    }

    // ==============================================
    // BRIGHTNESS PROCESSES
    // ==============================================

    property var brightnessGetter: Process {
        id: brightnessGetter

        running: false

        command: [
            "sh",
            "-c",
            "brightnessctl -m | cut -d, -f4 | sed 's/%//'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = Number(text.trim());

                if (!Number.isFinite(value))
                    return;

                root.brightness = Math.max(
                    0,
                    Math.min(100, value)
                );

                root.brightnessAvailable = true;
            }
        }
    }

    property var brightnessSetter: Process {
        id: brightnessSetter

        running: false

        command: [
            "brightnessctl",
            "set",
            String(Math.round(root.brightnessCommandValue)) + "%"
        ]

        onRunningChanged: {
            if (running)
                return;

            if (
                root.requestedBrightness !==
                root.brightnessCommandValue
            ) {
                root.brightnessCommandValue =
                    root.requestedBrightness;

                running = true;
            } else {
                root.refreshBrightness();
            }
        }
    }

    // ==============================================
    // MASTER REFRESH
    // ==============================================

    function refresh() {
        if (!root.active)
            return;

        root.refreshVolume();
        root.refreshBrightness();
        root.refreshWifi(false);
        root.refreshBluetooth();
    }

    // ==============================================
    // POLLING
    // ==============================================

    property var pollTimer: Timer {
        interval: 5000
        running: root.active
        repeat: true

        onTriggered: {
            root.refresh();
        }
    }

    onActiveChanged: {
        if (root.active) {
            root.refresh();
        } else if (root.bluetoothDiscovering) {
            root.stopBluetoothDiscovery();
        }
    }
}
