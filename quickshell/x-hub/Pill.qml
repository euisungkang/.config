import QtQuick

// A rounded text button; primary is filled with the accent colour.
Rectangle {
    id: pill
    required property var theme
    property string label
    property bool primary: false
    signal clicked
    implicitWidth: pillText.implicitWidth + 28
    implicitHeight: 30
    radius: 15
    opacity: enabled ? 1 : 0.5
    color: primary ? theme.c("primary", "#ffffff")
                   : Qt.alpha(theme.c("secondaryContainer", "#333333"), pillArea.containsMouse ? 1 : 0.8)

    Text {
        id: pillText
        anchors.centerIn: parent
        text: pill.label
        color: pill.primary ? theme.c("onPrimary", "#000000") : theme.c("onSecondaryContainer", "#ffffff")
        font.pixelSize: 12
        font.bold: true
    }
    MouseArea {
        id: pillArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: pill.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
