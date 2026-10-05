import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property int vmCount: 0
  property bool isRefreshing: false

  signal refreshClicked()

  implicitHeight: 40

  RowLayout {
    anchors.fill: parent
    spacing: Style.marginS

    NIcon {
      icon: "device-desktop"
      pointSize: Style.fontSizeL
      color: Color.mPrimary
    }

    NText {
      text: "Virtual Machines"
      pointSize: Style.fontSizeL
      font.weight: Font.Bold
      color: Color.mOnSurface
    }

    Rectangle {
      visible: root.vmCount > 0
      radius: Style.radiusS
      color: Color.mPrimary
      implicitWidth: countText.implicitWidth + Style.marginS * 2
      implicitHeight: countText.implicitHeight + Style.marginXS

      NText {
        id: countText
        anchors.centerIn: parent
        text: root.vmCount.toString()
        pointSize: Style.fontSizeS
        font.weight: Font.Bold
        color: Color.mOnPrimary
      }
    }

    Item {
      Layout.fillWidth: true
    }

    NIconButton {
      icon: "refresh"
      tooltipText: "Refresh"
      baseSize: 30
      enabled: !root.isRefreshing
      onClicked: root.refreshClicked()
    }
  }
}
