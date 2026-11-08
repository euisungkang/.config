import QtQuick
import QtQuick.Layouts

// One card inside a section. With a single card the section header already shows the balance,
// so only the utilization bar is drawn; with several, each gets an icon (or last four) + balance.
ColumnLayout {
    required property var theme
    property var card
    property string slug: ""
    property bool multi: false
    spacing: 5
    Layout.fillWidth: true

    readonly property real pct: card && card.limit ? Math.min(100, (card.balance + (card.pending || 0)) / card.limit * 100) : 0

    RowLayout {
        visible: multi
        Layout.fillWidth: true
        spacing: 6

        // Optional per-card icon: logos/cards/<institution-slug>-<last4>.svg (e.g. cards/chase-1234.svg)
        Image {
            id: icon
            source: multi && slug && card && card.mask ? "logos/cards/" + slug + "-" + card.mask + ".svg" : ""
            sourceSize.height: 40
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: status === Image.Ready
            Layout.preferredHeight: 16
            Layout.preferredWidth: status === Image.Ready ? implicitWidth * 16 / implicitHeight : 0
        }
        Text {
            visible: !icon.visible
            text: card && card.mask ? "··" + card.mask : ""
            color: theme.c("tertiary", "#ababab")
            font.pixelSize: 11
        }
        Item { Layout.fillWidth: true }
        Text {
            text: card ? theme.money(card.balance + (card.pending || 0)) : "–"
            color: theme.c("primary", "#ffffff")
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        visible: !!(card && card.limit)
        Layout.fillWidth: true
        implicitHeight: 8
        radius: 4
        color: theme.c("surfaceContainerHighest", "#262626")

        Rectangle {
            width: parent.width * pct / 100
            height: parent.height
            radius: 4
            color: theme.barColour(pct)
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        visible: !!(card && card.limit)
        text: card && card.limit ? Math.round(pct) + "% of " + theme.money(card.limit, true) + " limit" + (card.pending ? "  ·  " + theme.money(card.pending) + " pending" : "") : ""
        color: theme.c("tertiary", "#ababab")
        opacity: 0.8
        font.pixelSize: 11
    }
}
