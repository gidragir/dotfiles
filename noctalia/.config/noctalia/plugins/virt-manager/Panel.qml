import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import "components"

FocusScope {
  id: root

  property var pluginApi: null

  // SmartPanel integration
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: Math.round(360 * Style.uiScaleRatio)
  property real contentPreferredHeight: Math.round(380 * Style.uiScaleRatio)

  readonly property var main: (pluginApi && pluginApi.mainInstance) ? pluginApi.mainInstance : null
  readonly property var runningVms: (main && main.runningVms) ? main.runningVms : []
  readonly property int vmCount: (main && main.vmCount !== undefined) ? main.vmCount : (runningVms ? runningVms.length : 0)
  readonly property bool isRefreshing: (main && main.isRefreshing) ? main.isRefreshing : false

  // Position handling
  readonly property string screenBarPosition: Settings.getBarPositionForScreen(pluginApi && pluginApi.panelOpenScreen ? pluginApi.panelOpenScreen.name : null)
  readonly property string configuredPosition: {
    var pos = (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.panelPosition)
      ? pluginApi.pluginSettings.panelPosition
      : ((pluginApi && pluginApi.manifest && pluginApi.manifest.metadata && pluginApi.manifest.metadata.defaultSettings && pluginApi.manifest.metadata.defaultSettings.panelPosition)
         ? pluginApi.manifest.metadata.defaultSettings.panelPosition
         : "follow_launcher");
    if (pos === "follow_launcher") {
      return (Settings && Settings.data && Settings.data.appLauncher && Settings.data.appLauncher.position) ? Settings.data.appLauncher.position : "top_center";
    }
    return pos;
  }

  readonly property string panelPosition: {
    var pos = configuredPosition;
    if (pos === "follow_bar") {
      if (screenBarPosition === "left" || screenBarPosition === "right")
        return "center_" + screenBarPosition;
      return screenBarPosition + "_center";
    }
    return pos;
  }

  readonly property bool panelAnchorHorizontalCenter: panelPosition === "center" || panelPosition.endsWith("_center")
  readonly property bool panelAnchorVerticalCenter:   panelPosition === "center" || panelPosition.startsWith("center_")
  readonly property bool panelAnchorTop:    panelPosition.startsWith("top_")
  readonly property bool panelAnchorBottom: panelPosition.startsWith("bottom_")
  readonly property bool panelAnchorLeft:   panelPosition !== "center" && panelPosition.endsWith("_left")
  readonly property bool panelAnchorRight:  panelPosition !== "center" && panelPosition.endsWith("_right")

  anchors.fill: parent
  focus: true

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mOutline
    border.width: Style.borderS
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      PanelHeader {
        Layout.fillWidth: true
        vmCount: root.vmCount
        isRefreshing: root.isRefreshing
        onRefreshClicked: {
          if (root.main) root.main.refresh();
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
          id: vmListView
          anchors.fill: parent
          visible: root.vmCount > 0
          clip: true
          spacing: Style.marginXS
          model: root.runningVms

          delegate: VmItem {
            width: vmListView.width
            vmId: (modelData && modelData.id !== undefined) ? String(modelData.id) : ""
            vmName: (modelData && modelData.name !== undefined) ? String(modelData.name) : ""
            vmState: (modelData && modelData.state !== undefined) ? String(modelData.state) : ""
            onConnectClicked: {
              if (root.main) {
                root.main.launchVm(vmName);
              }
            }
          }
        }

        EmptyState {
          anchors.fill: parent
          visible: root.vmCount === 0
        }
      }
    }
  }
}
