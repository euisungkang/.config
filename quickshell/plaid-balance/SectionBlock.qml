import QtQuick
import QtQuick.Layouts

// One institution: logo header + subtotal, then its cards. A hairline divider separates sections.
ColumnLayout {
    required property var theme
    property var section
    property int index: 0
    spacing: 10
    Layout.fillWidth: true

    // Institution name -> logos/<slug>.svg; add an alias when a file is named differently
    readonly property var aliases: ({ "bank-of-america": "bofa" })
    readonly property string rawSlug: section ? section.institution.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") : ""
    readonly property string slug: aliases[rawSlug] || rawSlug

    Rectangle {
        visible: index > 0
        Layout.fillWidth: true
        Layout.bottomMargin: 10  // with spacing 10 -> same 20 above and below the divider
        implicitHeight: 1
        color: Qt.alpha(theme.c("outlineVariant", "#444444"), 0.6)
    }

    RowLayout {
        Layout.fillWidth: true
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
            text: parent.parent.section ? parent.parent.section.institution : ""
            color: theme.c("secondary", "#cccccc")
            font.pixelSize: 12
        }
        Item { Layout.fillWidth: true }
        Text {
            text: parent.parent.section ? theme.money(parent.parent.section.total) : "–"
            color: theme.c("primary", "#ffffff")
            font.pixelSize: 13
            font.bold: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 16

        Repeater {
            model: section ? section.cards : []
            CardRow {
                required property var modelData
                theme: parent.parent.theme
                card: modelData
                slug: parent.parent.slug
                multi: parent.parent.section.cards.length > 1
            }
        }
    }
}
