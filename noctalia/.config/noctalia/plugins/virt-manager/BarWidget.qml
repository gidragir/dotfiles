import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Noctalia
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen: null
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property var pluginApi: null

  readonly property var main: (pluginApi && pluginApi.mainInstance) ? pluginApi.mainInstance : null
  readonly property int vmCount: (main && main.vmCount !== undefined) ? main.vmCount : 0
  readonly property bool hasVms: vmCount > 0

  readonly property string tooltipContent: {
    var lines = [];
    lines.push("<b>Virtual Machines</b>");
    lines.push("Active VMs: " + vmCount);
    lines.push("<font color='" + Color.mOutline + "'>Click to toggle VM panel</font>");
    return lines.join("<br/>");
  }

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: "device-desktop"
    text: root.hasVms ? root.vmCount.toString() : ""
    autoHide: false
    forceOpen: root.hasVms
    tooltipText: root.tooltipContent

    customIconColor: root.hasVms ? Color.mPrimary : Color.mOnSurfaceVariant
    customTextColor: root.hasVms ? Color.mPrimary : Color.mOnSurfaceVariant

    onClicked: {
      if (pluginApi) {
        pluginApi.togglePanel(root.screen, pill);
      }
    }
  }
}
