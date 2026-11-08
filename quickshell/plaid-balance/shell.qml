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
    // Amounts are blurred until the pointer is over the card
    property bool revealed: false
    readonly property var alerts: {
        const a = data && data.alerts ? data.alerts.slice() : [];
        if (testAlert) a.unshift({ institution: "Chase", state: "expired", text: "Test: sign in again", test: true });
        return a;
    }

    // Cards grouped by institution (data.cards is already sorted by amount owed)
    readonly property var sections: {
        const bySection = {}, out = [];
        for (const card of (data && data.cards ? data.cards : [])) {
            const key = card.institution || "Other";
            if (!bySection[key]) { bySection[key] = { institution: key, cards: [], total: 0 }; out.push(bySection[key]); }
            bySection[key].cards.push(card);
            bySection[key].total += card.balance + (card.pending || 0);
        }
        return out;
    }

    function c(name, fallback) {
        return colours[name] ? "#" + colours[name] : fallback;
    }

    function relink(institution, transactions) {
        relinker.institution = institution;
        relinker.transactions = !!transactions;
        relinker.running = true;
    }

    function money(v, whole) {
        if (v === null || v === undefined) return "–";
        return "$" + v.toLocaleString(Qt.locale("en_US"), "f", whole ? 0 : 2);
    }

    function barColour(pct) {
        if (pct >= 90) return c("error", "#ff5449");
        if (pct >= 30) return c("tertiary", "#e0b050");
        return c("primary", "#ffffff");
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
        id: fetcher
        command: [Quickshell.env("HOME") + "/.config/quickshell/plaid-balance/plaid-balance.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.data = JSON.parse(text); } catch (e) {}
            }
        }
    }

    Process {
        id: relinker
        property string institution: ""
        property bool transactions: false
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/plaid-balance/plaid-link.py"]
            .concat(transactions ? ["--transactions"] : []).concat(["--update", institution])
        stdout: StdioCollector { onStreamFinished: console.log("relink out:", text) }
        stderr: StdioCollector { onStreamFinished: console.log("relink err:", text) }
        onExited: (code, status) => {
            console.log("relink exited", code, status);
            root.testAlert = false;
            fetcher.command = [fetcher.command[0], "--force"];
            fetcher.running = true;
        }
    }

    // Force a fresh fetch (bypasses the script's cache): qs -c plaid-balance ipc call balances refresh
    IpcHandler {
        target: "balances"
        // Toggle a fake alert button to preview its look: qs -c plaid-balance ipc call balances testAlert
        function testAlert(): void { root.testAlert = !root.testAlert; }
        function refresh(): void { fetcher.command = [fetcher.command[0], "--force"]; fetcher.running = true; }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetcher.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors {
                top: true
                right: true
            }
            // Window is padded so the drop shadow isn't clipped
            readonly property int pad: 32
            // Sits below the investments widget: 24 (screen edge) + 333 (its card height) + 16 (gap).
            // Raise investHeight if that widget grows.
            readonly property int investHeight: 333
            margins {
                top: 24 + investHeight + 16 - pad
                right: 24 - pad
            }
            implicitWidth: card.implicitWidth + pad * 2
            implicitHeight: card.implicitHeight + pad * 2
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "plaid-balance"

            Item {
                id: card
                anchors.centerIn: parent

                HoverHandler { onHoveredChanged: root.revealed = hovered }
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

                        // Everything is blurred until the pointer is over the card
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: 48
                            blurMultiplier: 1.2
                            blur: root.revealed ? 0 : 1
                            Behavior on blur { NumberAnimation { duration: 200 } }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Credit Cards"
                                color: root.c("secondary", "#cccccc")
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: !!(root.data && root.data.cards)
                                text: root.data && root.data.cards ? root.money(root.data.total) : ""
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

                        Repeater {
                            model: root.alerts
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 17
                                color: Qt.alpha(modelData.state === "expired" ? root.c("error", "#ff5449") : root.c("tertiary", "#e0b050"), area.containsMouse ? 0.35 : 0.22)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.text + " →"
                                    color: modelData.state === "expired" ? root.c("error", "#ff5449") : root.c("tertiary", "#e0b050")
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                MouseArea {
                                    id: area
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("alert clicked:", modelData.institution);
                                        root.relink(modelData.institution, modelData.transactions);
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.sections
                            SectionBlock {
                                required property var modelData
                                required property int index
                                theme: root
                                section: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
