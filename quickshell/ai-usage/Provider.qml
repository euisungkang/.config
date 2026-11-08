import QtQuick
import QtQuick.Layouts

// One provider's logo, optional label, error and usage bars. A window the provider does
// not have (Grok has no session window) is hidden.
ColumnLayout {
    id: section
    required property var theme
    property string logo
    property string label
    property var usage
    property color colour: theme.barColour(0)
    property bool expanded: true
    // Shows a Resync button in the header row
    property bool resync: false
    signal resyncRequested
    spacing: 10
    Layout.fillWidth: true

    RowLayout {
        spacing: 8
        Layout.fillWidth: true

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: section.expanded = !section.expanded
        }

        Image {
            source: section.logo
            sourceSize: Qt.size(48, 48)
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            visible: section.label !== ""
            text: section.label
            color: section.theme.c("secondary", "#cccccc")
            font.pixelSize: 12
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: section.resync
            implicitWidth: resyncLabel.implicitWidth + 20
            implicitHeight: resyncLabel.implicitHeight + 8
            radius: height / 2
            color: Qt.alpha(section.theme.c("secondary", "#cccccc"), resyncArea.pressed ? 0.35 : resyncArea.containsMouse ? 0.25 : 0.15)

            Text {
                id: resyncLabel
                anchors.centerIn: parent
                text: "Resync"
                color: section.theme.c("secondary", "#cccccc")
                font.pixelSize: 12
            }

            MouseArea {
                id: resyncArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: section.resyncRequested()
            }
        }

        Text {
            text: section.expanded ? "▾" : "▸"
            color: section.theme.c("secondary", "#cccccc")
            font.pixelSize: 14
        }
    }

    Text {
        visible: section.expanded && !!(section.usage && section.usage.error)
        text: section.usage && section.usage.error ? section.usage.error : ""
        color: section.theme.c("error", "#ff5449")
        font.pixelSize: 12
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    UsageBar {
        theme: section.theme
        colour: section.colour
        label: "Current"
        win: section.usage ? section.usage.session : null
        visible: section.expanded && !(section.usage && section.usage.session === null)
    }

    UsageBar {
        theme: section.theme
        colour: section.colour
        label: "Weekly"
        win: section.usage ? section.usage.weekly : null
        visible: section.expanded
    }
}
