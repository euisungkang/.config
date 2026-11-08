import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

ShellRoot {
    id: root

    property var colours: ({})
    property var data: null
    property bool testAlert: false
    readonly property var alerts: {
        const a = data && data.alerts ? data.alerts.slice() : [];
        if (testAlert) a.unshift({ institution: "SoFi", state: "expired", text: "Test: sign in again" });
        return a;
    }
    readonly property string dir: Quickshell.env("HOME") + "/.config/quickshell"

    function c(name, fallback) {
        return colours[name] ? "#" + colours[name] : fallback;
    }

    function money(v, whole) {
        if (v === null || v === undefined) return "–";
        return "$" + v.toLocaleString(Qt.locale("en_US"), "f", whole ? 0 : 2);
    }

    // args: ["--invest"] to link a new account, ["--update", "Fidelity"] to re-authenticate one
    function link(args) {
        linker.args = args;
        linker.running = true;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.colours = JSON.parse(text()).colours; } catch (e) {}
        }
    }

    Process {
        id: fetcher
        command: [root.dir + "/plaid-invest/plaid-invest.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.data = JSON.parse(text); } catch (e) {}
            }
        }
    }

    Process {
        id: updater
        command: [root.dir + "/plaid-invest/invest-update"]
    }

    Process {
        id: linker
        property var args: []
        command: ["python3", root.dir + "/plaid-balance/plaid-link.py"].concat(args)
        stdout: StdioCollector { onStreamFinished: console.log("link out:", text) }
        stderr: StdioCollector { onStreamFinished: console.log("link err:", text) }
        onExited: (code, status) => {
            console.log("link exited", code, status);
            root.testAlert = false;
            fetcher.command = [root.dir + "/plaid-invest/plaid-invest.py", "--force"];
            fetcher.running = true;
        }
    }

    // qs -c plaid-invest ipc call invest refresh
    IpcHandler {
        target: "invest"
        function refresh(): void { fetcher.command = [root.dir + "/plaid-invest/plaid-invest.py", "--force"]; fetcher.running = true; }
        function link(): void { root.link(["--invest"]); }
        // Re-read hand-entered balances (cheap: Plaid data comes from the cache)
        function reload(): void { fetcher.command = [root.dir + "/plaid-invest/plaid-invest.py"]; fetcher.running = true; }
        // Toggle a fake alert button to preview its look: qs -c plaid-invest ipc call invest testAlert
        function testAlert(): void { root.testAlert = !root.testAlert; }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetcher.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            // Everything is blurred until the pointer is over this monitor's card
            property bool revealed: false
            anchors {
                top: true
                right: true
            }
            // Window is padded so the drop shadow isn't clipped. Top-right, above the credit card widget
            readonly property int pad: 32
            margins {
                top: 24 - pad
                right: 24 - pad
            }
            implicitWidth: card.implicitWidth + pad * 2
            implicitHeight: card.implicitHeight + pad * 2
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "plaid-invest"

            Item {
                id: card
                anchors.centerIn: parent

                HoverHandler { onHoveredChanged: win.revealed = hovered }
                implicitWidth: 300
                implicitHeight: content.implicitHeight + 40
                width: implicitWidth
                height: implicitHeight

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
                        Layout.fillWidth: true
                        spacing: 20

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: 48
                            blurMultiplier: 1.2
                            blur: win.revealed ? 0 : 1
                            Behavior on blur { NumberAnimation { duration: 200 } }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Investments"
                                color: root.c("secondary", "#cccccc")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: !!(root.data && root.data.accounts && root.data.accounts.length)
                                text: root.data ? root.money(root.data.total) : ""
                                color: root.c("primary", "#ffffff")
                                font.pixelSize: 20
                                font.bold: true
                            }
                        }

                        Text {
                            visible: !!(root.data && root.data.error)
                            text: root.data && root.data.error ? root.data.error : ""
                            color: root.c("error", "#ff5449")
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        // Re-auth buttons
                        Repeater {
                            model: root.alerts
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 17
                                color: Qt.alpha(modelData.state === "expired" ? root.c("error", "#ff5449") : root.c("tertiary", "#e0b050"), alertArea.containsMouse ? 0.35 : 0.22)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.text + " →"
                                    color: modelData.state === "expired" ? root.c("error", "#ff5449") : root.c("tertiary", "#e0b050")
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                MouseArea {
                                    id: alertArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.link(["--update", modelData.institution])
                                }
                            }
                        }

                        // Payday check: shown from the 2nd / 16th until the manual balances are confirmed
                        Rectangle {
                            visible: !!(root.data && root.data.manual_due)
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 17
                            color: Qt.alpha(root.c("tertiary", "#e0b050"), updateArea.containsMouse ? 0.35 : 0.22)
                            Text {
                                anchors.centerIn: parent
                                text: updater.running ? "Updating…" : "Update 401(k) & HSA →"
                                color: root.c("tertiary", "#e0b050")
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                id: updateArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !updater.running
                                onClicked: updater.running = true
                            }
                        }

                        Repeater {
                            model: root.data && root.data.accounts ? root.data.accounts : []
                            AccountRow {
                                required property var modelData
                                theme: root
                                acct: modelData
                            }
                        }

                        // Link an account (Fidelity, SoFi, ...). Run once per institution.
                        /*
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 17
                            color: Qt.alpha(root.c("tertiary", "#e0b050"), linkArea.containsMouse ? 0.35 : 0.22)
                            Text {
                                anchors.centerIn: parent
                                text: root.data && root.data.empty ? "Link an account →" : "+ Link another account"
                                color: root.c("tertiary", "#e0b050")
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                id: linkArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.link(["--invest"])
                            }
                        }
                        */
                    }
                }
            }
        }
    }
}
