import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// X Hub: drafts written at 5 random times a day (xhub.py plan), for review.
// Approve posts to X; Redraft sends the feedback back to the drafter. A day is done
// once all 5 of its posts are approved and posted.
ShellRoot {
    id: root

    property var colours: ({})
    property var slots: []
    property bool busy: false
    property real now: Date.now() / 1000
    // Unsaved edits and feedback, keyed by "<slot id>:<runs>", kept across reloads
    property var edits: ({})
    property var feedback: ({})

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/x-hub/xhub.py"
    readonly property string today: Qt.formatDate(new Date(now * 1000), "yyyy-MM-dd")
    readonly property var open: slots.filter(s => s.status === "review" || s.status === "drafting" || s.status === "error")
    readonly property int postedToday: slots.filter(s => s.day === today && s.status === "posted").length
    readonly property int waiting: slots.filter(s => s.status === "waiting").length
    readonly property int plannedToday: slots.filter(s => s.day === today).length
    readonly property var next: slots.filter(s => s.status === "scheduled" && s.due > now).sort((a, b) => a.due - b.due)[0] || null

    function c(name, fallback) {
        return colours[name] ? "#" + colours[name] : fallback;
    }

    function editBrief() {
        console.log("xhub: opening brief");
        Quickshell.execDetached(["foot", "nvim", Quickshell.env("HOME") + "/.local/share/x-hub/brief.md"]);
    }

    function run(args) {
        busy = true;
        runner.command = [script].concat(args);
        runner.running = true;
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

    // xhub.py is the only writer; it replaces the file atomically
    FileView {
        id: slotsFile
        path: Quickshell.env("HOME") + "/.local/state/x-hub/slots.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.slots = JSON.parse(text()); } catch (e) {}
        }
    }

    Process {
        id: runner
        stderr: StdioCollector { onStreamFinished: if (text) console.log("xhub:", text) }
        onExited: {
            root.busy = false;
            slotsFile.reload();
        }
    }

    // qs -c x-hub ipc call xhub reload
    IpcHandler {
        target: "xhub"
        function reload(): void { slotsFile.reload(); }
        function brief(): void { root.editBrief(); }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now() / 1000;
            slotsFile.reload();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors {
                top: true
                left: true
            }
            // Window is padded so the drop shadow isn't clipped
            readonly property int pad: 32
            // Offsets clear Caelestia's bar (60 px) and top border (10 px), which Ignore doesn't
            margins {
                top: 10 + 24 - pad
                left: 60 + 24 - pad
            }
            implicitWidth: card.implicitWidth + pad * 2
            implicitHeight: card.implicitHeight + pad * 2
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "x-hub"
            // Text boxes need the keyboard; it is given on click
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            Item {
                id: card
                anchors.centerIn: parent
                implicitWidth: 380
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

                ColumnLayout {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        // logos/x.svg when present, else the name
                        Image {
                            id: logo
                            source: "logos/x.svg"
                            sourceSize.height: 48
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: status === Image.Ready
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: status === Image.Ready ? implicitWidth * 20 / implicitHeight : 0
                        }
                        Text {
                            visible: !logo.visible
                            text: "X Drafts"
                            color: root.c("secondary", "#cccccc")
                            font.pixelSize: 12
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.postedToday + "/" + (root.plannedToday || 5)
                            color: root.postedToday >= 5 ? root.c("primary", "#ffffff") : root.c("onSurface", "#ffffff")
                            font.pixelSize: 20
                            font.bold: true
                        }
                    }

                    Text {
                        text: root.open.length ? "" : root.next
                            ? "All caught up · next draft " + Qt.formatDateTime(new Date(root.next.due * 1000), "h:mm AP")
                            : root.postedToday >= 5 ? "Today's 5 are posted" : "All caught up"
                        visible: text !== ""
                        color: root.c("tertiary", "#ababab")
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: root.open
                        ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 16

                            Rectangle {
                                visible: index > 0
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: Qt.alpha(root.c("outlineVariant", "#444444"), 0.6)
                            }
                            DraftCard {
                                theme: root
                                slot: modelData
                            }
                        }
                    }

                    // Footer, not header: Caelestia takes clicks within 90 px of the screen's top
                    // edge (its border plus the panels' drag zone), which the header is inside
                    RowLayout {
                        Layout.fillWidth: true
                        // Slots whose time came while a draft was staged draft once it is posted
                        Text {
                            text: [root.waiting ? root.waiting + " waiting" : "",
                                   root.open.length && root.next ? "Next draft " + Qt.formatDateTime(new Date(root.next.due * 1000), "h:mm AP") : ""]
                                .filter(t => t).join(" · ")
                            visible: text !== ""
                            color: root.c("tertiary", "#ababab")
                            opacity: 0.8
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        // The drafter reads brief.md on every draft, so edits apply from the next one
                        Pill {
                            theme: root
                            label: "Brief"
                            implicitHeight: 24
                            onClicked: root.editBrief()
                        }
                    }
                }
            }
        }
    }
}
