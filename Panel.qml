import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "miharekar.studio-display-auto-brightness"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var brightnessService: null
  readonly property string contentFont: bar ? bar.fontFamily : Style.font.family

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(14)

        Text {
          width: parent.width
          text: "Studio Display"
          color: root.barForeground
          font.family: root.contentFont
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Repeater {
          model: [
            ["AMBIENT", root.brightnessService?.lux?.toFixed(0) + " lux"],
            ["BRIGHTNESS", (root.brightnessService?.brightness ?? "--") + "%"],
            ["DISPLAY", root.brightnessService?.monitor || "Waiting"]
          ]

          Row {
            required property var modelData
            width: content.width

            Text {
              width: parent.width * 0.36
              text: modelData[0]
              color: Qt.darker(root.barForeground, 1.5)
              font.family: root.contentFont
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width * 0.64
              text: modelData[1]
              color: root.barForeground
              font.family: root.contentFont
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideLeft
            }
          }
        }

        Text {
          visible: root.brightnessService?.error !== ""
          width: parent.width
          text: root.brightnessService?.error || ""
          color: root.bar?.urgent || root.barForeground
          font.family: root.contentFont
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          text: "SENSOR"
          color: Qt.darker(root.barForeground, 1.5)
          font.family: root.contentFont
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        Row {
          spacing: Style.space(8)
          Repeater {
            model: ["rear", "front"]
            Button {
              required property string modelData
              text: modelData === "rear" ? "Back" : "Front"
              selected: root.brightnessService?.sensorSide === modelData
              foreground: root.barForeground
              fontFamily: root.contentFont
              focusable: true
              onClicked: root.brightnessService?.setSensorSide(modelData)
            }
          }
        }

        Text {
          text: "PREFERENCE"
          color: Qt.darker(root.barForeground, 1.5)
          font.family: root.contentFont
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        Row {
          spacing: Style.space(8)
          Repeater {
            model: ["dim", "balanced", "bright"]
            Button {
              required property string modelData
              text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
              selected: root.brightnessService?.profile === modelData
              foreground: root.barForeground
              fontFamily: root.contentFont
              focusable: true
              onClicked: root.brightnessService?.setProfile(modelData)
            }
          }
        }

        Button {
          width: parent.width
          text: root.brightnessService?.paused ? "Resume" : "Pause"
          iconText: root.brightnessService?.paused ? "󰐊" : "󰏤"
          foreground: root.barForeground
          fontFamily: root.contentFont
          focusable: true
          bordered: true
          onClicked: root.brightnessService?.setPaused(!root.brightnessService.paused)
        }
      }
    }
  }
}
