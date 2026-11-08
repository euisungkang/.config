pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    readonly property var dpiPresets: [400, 800, 1600, 3200, 6400]

    spacing: Tokens.spacing.medium
    width: Tokens.sizes.bar.audioWidth

    Component.onCompleted: Razer.refresh()

    StyledText {
        text: Razer.connected ? Razer.name : "No Razer device found"
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    StyledText {
        visible: Razer.connected && Razer.battery >= 0
        text: `Battery: ${Razer.battery}%${Razer.charging ? " (charging)" : ""}`
    }

    StyledText {
        visible: Razer.connected && Razer.pollRate > 0
        text: `Polling rate: ${Razer.pollRate} Hz`
    }

    StyledText {
        visible: Razer.connected && Razer.dpi > 0
        Layout.topMargin: Tokens.spacing.medium
        text: `DPI: ${Razer.dpi}`
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    RowLayout {
        visible: Razer.connected && Razer.dpi > 0
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        Repeater {
            model: root.dpiPresets.filter(d => d <= Razer.maxDpi)

            TextButton {
                required property int modelData

                Layout.fillWidth: true
                isToggle: true
                checked: Razer.dpi === modelData
                internalChecked: checked
                horizontalPadding: Tokens.padding.small
                text: String(modelData)
                onClicked: Razer.set("dpi", modelData)
            }
        }
    }

    StyledText {
        visible: Razer.connected
        Layout.topMargin: Tokens.spacing.medium
        text: `Brightness: ${Razer.brightness}%`
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    StyledSlider {
        visible: Razer.connected
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3
        interactionOnMove: false
        value: Razer.brightness / 100
        onInteraction: v => Razer.set("brightness", Math.round(v * 100))
    }
}
