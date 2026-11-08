import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    signal clicked

    implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    implicitHeight: implicitWidth

    // Dim while no Razer device is reachable
    opacity: Razer.connected ? 1 : 0.4

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: parent.implicitWidth + Tokens.padding.small
        implicitHeight: implicitWidth
        radius: Tokens.rounding.full
        onClicked: root.clicked()
    }

    Image {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: width
        source: Qt.resolvedUrl("../../../assets/razer.svg")
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
