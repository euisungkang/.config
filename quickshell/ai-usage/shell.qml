import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

ShellRoot {
    id: root

    property var colours: ({})
    property var claude: null
    property var claudeWork: null
    property var grok: null
    property date now: new Date()
    // ["--force"] makes usage.py skip its cache and rate-limit backoff
    property var fetchFlags: []

    function refresh(force) {
        fetchFlags = force ? ["--force"] : [];
        claudeFetcher.running = true;
        claudeWorkFetcher.running = true;
        grokFetcher.running = true;
    }

    function c(name, fallback) {
        return colours[name] ? "#" + colours[name] : fallback;
    }

    function resetText(iso) {
        if (!iso) return "";
        const ms = new Date(iso) - now;
        if (ms <= 0) return "resetting…";
        const mins = Math.round(ms / 60000);
        const d = Math.floor(mins / 1440);
        const h = Math.floor((mins % 1440) / 60);
        const m = mins % 60;
        if (d > 0) return "resets in " + d + "d " + h + "h";
        if (h > 0) return "resets in " + h + "h " + m + "m";
        return "resets in " + m + "m";
    }

    function barColour(pct) {
        // if (pct >= 90) return c("error", "#ff5449");
        // if (pct >= 70) return c("tertiary", "#e0b050");
        // return c("primary", "#ffffff");
        return "#D97757"
    }

    // Caelestia's current palette
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.colours = JSON.parse(text()).colours; } catch (e) {}
        }
    }

    Process {
        id: claudeFetcher
        command: [Quickshell.env("HOME") + "/.config/quickshell/ai-usage/usage.py", "claude"].concat(root.fetchFlags)
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.claude = JSON.parse(text); } catch (e) {}
            }
        }
    }

    Process {
        id: claudeWorkFetcher
        command: [Quickshell.env("HOME") + "/.config/quickshell/ai-usage/usage.py", "claude-work"].concat(root.fetchFlags)
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.claudeWork = JSON.parse(text); } catch (e) {}
            }
        }
    }

    Process {
        id: grokFetcher
        command: [Quickshell.env("HOME") + "/.config/quickshell/ai-usage/usage.py", "grok"].concat(root.fetchFlags)
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.grok = JSON.parse(text); } catch (e) {}
            }
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh(false)
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
        screen: modelData
            anchors {
                bottom: true
                left: true
            }
            // Window is padded so the drop shadow isn't clipped
            readonly property int pad: 32
            // Offsets clear Caelestia's bar (60 px) and bottom border (10 px), which Ignore doesn't
            margins {
                bottom: 10 + 24 - pad
                left: 60 + 24 - pad
            }
            implicitWidth: card.implicitWidth + pad * 2
            implicitHeight: card.implicitHeight + pad * 2
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // Bottom sits above the wallpaper (Background) so the compositor can blur it
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "ai-usage"

            Item {
                id: card
                anchors.centerIn: parent
                // implicitWidth: 250
                implicitWidth: 300
                implicitHeight: content.implicitHeight + 40
                width: implicitWidth
                height: implicitHeight

                // Mirrors the desktop clock: m3surface plate at 50% alpha, blurred behind by a
                // Hyprland layerrule (see hypr-user.conf), soft drop shadow
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.c("shadow", "#000000")
                    shadowOpacity: 0.5
                    shadowBlur: 10
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 28
                    color: Qt.alpha(root.c("surface", "#0e0e0e"), 0.5)
                }

                RowLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 0

                    ColumnLayout {
                        id: col
                        Layout.fillWidth: true
                        spacing: 20

                        Provider {
                            theme: root
                            logo: "claude.svg"
                            usage: root.claude
                            resync: true
                            onResyncRequested: root.refresh(true)
                        }

                        Provider {
                            theme: root
                            logo: "claude.svg"
                            label: "Alt"
                            usage: root.claudeWork
                        }

                        Provider {
                            theme: root
                            logo: "grok.svg"
                            usage: root.grok
                            colour: root.c("primary", "#ffffff")
                        }
                    }
                }
            }
        }
    }
}
