import QtQuick
import QtQuick.Layouts

ColumnLayout {
    required property var theme
    property var acct
    spacing: 5
    Layout.fillWidth: true

    // Institution name -> logos/<slug>.svg; add an alias when a file is named differently
    readonly property var aliases: ({})
    readonly property string rawSlug: acct && acct.institution ? acct.institution.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") : ""
    readonly property string slug: aliases[rawSlug] || rawSlug
    readonly property bool hasCash: !!acct && !!acct.cash
    readonly property bool hasGain: !!acct && acct.gain !== null && acct.gain !== undefined

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 5
        spacing: 6

        Image {
            id: logo
            source: parent.parent.slug ? "logos/" + parent.parent.slug + ".svg" : ""
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: status === Image.Ready
            Layout.preferredHeight: 20
            Layout.preferredWidth: status === Image.Ready ? implicitWidth * 20 / implicitHeight : 0
        }
        Text {
            visible: !logo.visible
            text: parent.parent.acct ? parent.parent.acct.institution : ""
            color: theme.c("secondary", "#cccccc")
            font.pixelSize: 12
        }
        Text {
            text: parent.parent.acct ? parent.parent.acct.label : ""
            color: theme.c("tertiary", "#ababab")
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            text: parent.parent.acct ? theme.money(parent.parent.acct.value) : "–"
            color: theme.c("primary", "#ffffff")
            font.pixelSize: 13
            font.bold: true
        }
    }

    Text {
        visible: parent.hasGain
        text: parent.hasGain ? (parent.acct.gain >= 0 ? "+" : "−") + theme.money(Math.abs(parent.acct.gain)) + "  (" + (parent.acct.gain_pct >= 0 ? "+" : "−") + Math.abs(parent.acct.gain_pct).toFixed(1) + "%)  " + (parent.acct.gain_since ? "since " + new Date(parent.acct.gain_since + "T12:00:00").toLocaleDateString(Qt.locale("en_US"), "MMM d") : "all time") + (parent.acct.gain_since === undefined && parent.acct.basis_coverage < 1 ? "  ·  partial" : "") : ""
        color: parent.hasGain && parent.acct.gain < 0 ? theme.c("error", "#ff5449") : theme.c("primary", "#ffffff")
        font.pixelSize: 11
    }

    Text {
        visible: parent.hasCash
        text: parent.hasCash ? theme.money(parent.acct.cash) + " cash holding" : ""
        color: theme.c("tertiary", "#ababab")
        opacity: 0.8
        font.pixelSize: 11
    }
}
