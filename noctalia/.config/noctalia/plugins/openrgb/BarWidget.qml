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

  readonly property var main:           pluginApi?.mainInstance ?? null
  readonly property var rgbData:        main?.rgbData ?? ({ "current": "off", "profiles": ["off"] })
  readonly property string currentProfile: rgbData?.current ?? "off"
  readonly property bool isOff:         currentProfile === "off"

  // First non-off profile in the list (used for RMB toggle)
  readonly property string firstActiveProfile: {
    var profiles = rgbData?.profiles ?? [];
    for (var i = 0; i < profiles.length; i++) {
      if (profiles[i] !== "off") return profiles[i];
    }
    return "off";
  }

  readonly property string tooltipContent: {
    var lines = [];
    lines.push("<b>RGB Lighting Control</b>");
    lines.push("Current: " + (isOff ? "Off (Stealth)" : currentProfile));
    lines.push("<font color='" + Color.mOutline + "'>LMB: Panel · RMB: Quick Off</font>");
    return lines.join("<br/>");
  }

  implicitWidth:  pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill

    screen:             root.screen
    oppositeDirection:  BarService.getPillDirection(root)
    icon:               isOff ? "bulb-off" : "bulb"
    text:               isOff ? "Off" : currentProfile
    autoHide:           false
    forceOpen:          true
    tooltipText:        root.tooltipContent

    customIconColor: isOff ? Color.mOnSurfaceVariant : Color.mPrimary
    customTextColor: isOff ? Color.mOnSurfaceVariant : Color.mPrimary

    onClicked: {
      if (pluginApi) pluginApi.togglePanel(screen, pill);
    }

    // RMB: toggle between off and the first available profile (no hardcoded "red")
    onRightClicked: {
      if (main) {
        main.applyProfile(isOff ? root.firstActiveProfile : "off");
      }
    }
  }
}
