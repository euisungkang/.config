pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("modules/bar/razer/razer_ctl.py")

    property bool connected
    property string name
    property int battery: -1
    property bool charging
    property int dpi
    property int maxDpi
    property int pollRate
    property int brightness

    function refresh(): void {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function set(setting: string, value: int): void {
        if (setProc.running)
            return;
        setProc.command = ["python3", script, "set", setting, String(value)];
        setProc.running = true;
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc

        command: ["python3", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    d = {};
                }
                root.connected = d.connected ?? false;
                root.name = d.name ?? "";
                root.battery = d.battery ?? -1;
                root.charging = d.charging ?? false;
                root.dpi = d.dpi ?? 0;
                root.maxDpi = d.maxDpi ?? 0;
                root.pollRate = d.pollRate ?? 0;
                root.brightness = d.brightness ?? 0;
            }
        }
    }

    Process {
        id: setProc

        onExited: root.refresh()
    }
}
