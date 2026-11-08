import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One open slot: the draft (editable), its character count, a feedback box, and
// Redraft / Approve. While drafting it shows only a status line; after a failed
// draft, the error and a Retry button.
ColumnLayout {
    id: card
    required property var theme
    property var slot
    readonly property string key: slot ? slot.id + ":" + slot.runs : ""
    readonly property bool reviewing: !!slot && slot.status === "review"
    readonly property int count: body.text.trim().length
    spacing: 8
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: slot ? Qt.formatDateTime(new Date(slot.due * 1000), "ddd h:mm AP") : ""
            color: theme.c("secondary", "#cccccc")
            font.pixelSize: 11
        }
        Text {
            visible: !!slot && slot.attempts.length > 0
            text: slot ? "· draft " + (slot.attempts.length + 1) : ""
            color: theme.c("tertiary", "#ababab")
            font.pixelSize: 11
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: reviewing
            text: count + "/280"
            color: count > 280 ? theme.c("error", "#ff5449") : theme.c("tertiary", "#ababab")
            font.pixelSize: 11
        }
        Text {
            visible: !!slot && slot.status === "drafting"
            text: "Drafting…"
            color: theme.c("tertiary", "#e0b050")
            font.pixelSize: 11
        }
    }

    Rectangle {
        visible: reviewing
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight
        radius: 12
        color: theme.c("surfaceContainerHighest", "#262626")
        border.width: body.activeFocus ? 1 : 0
        border.color: theme.c("primary", "#ffffff")

        TextArea {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            padding: 10
            wrapMode: TextEdit.Wrap
            color: theme.c("onSurface", "#ffffff")
            selectionColor: theme.c("primary", "#ffffff")
            selectedTextColor: theme.c("onPrimary", "#000000")
            font.pixelSize: 13
            background: null
            // Keep in-progress edits across reloads of slots.json; a redraft (new runs) starts clean
            text: theme.edits[card.key] !== undefined ? theme.edits[card.key] : (card.slot && card.slot.text ? card.slot.text : "")
            onTextChanged: if (activeFocus) theme.edits[card.key] = text
        }
    }

    Text {
        visible: !!slot && !!slot.error
        text: slot && slot.error ? slot.error : ""
        color: theme.c("error", "#ff5449")
        font.pixelSize: 11
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    Rectangle {
        visible: reviewing
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 17
        color: Qt.alpha(theme.c("surfaceContainerHighest", "#262626"), 0.7)
        border.width: feedback.activeFocus ? 1 : 0
        border.color: theme.c("outline", "#888888")

        TextField {
            id: feedback
            anchors.fill: parent
            leftPadding: 14
            rightPadding: 14
            placeholderText: "Feedback for a redraft…"
            placeholderTextColor: theme.c("outline", "#888888")
            color: theme.c("onSurface", "#ffffff")
            font.pixelSize: 12
            background: null
            text: theme.feedback[card.key] || ""
            onTextChanged: if (activeFocus) theme.feedback[card.key] = text
            onAccepted: theme.run(["reject", card.slot.id, "--text", body.text, text])
        }
    }

    RowLayout {
        visible: !!slot && (slot.status === "review" || slot.status === "error")
        Layout.fillWidth: true
        spacing: 8

        Item { Layout.fillWidth: true }
        // Redraft rewrites this post from the text as edited, with the feedback; Reject
        // topic starts a new one
        Pill {
            visible: card.reviewing
            theme: card.theme
            label: "Reject topic"
            enabled: !theme.busy
            onClicked: theme.run(["discard", card.slot.id, feedback.text])
        }
        Pill {
            theme: card.theme
            label: card.reviewing ? "Redraft" : "Retry"
            enabled: !theme.busy
            onClicked: theme.run(["reject", card.slot.id, "--text", body.text, feedback.text])
        }
        Pill {
            visible: card.reviewing
            theme: card.theme
            primary: true
            label: "Approve & post"
            enabled: !theme.busy && card.count > 0 && card.count <= 280
            onClicked: theme.run(["approve", card.slot.id, body.text])
        }
    }
}
