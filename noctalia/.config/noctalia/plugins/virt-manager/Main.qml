import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null

  property var runningVms: []
  property int vmCount: runningVms ? runningVms.length : 0
  property bool isRefreshing: false

  readonly property int pollInterval: ((pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.pollIntervalSec) ? pluginApi.pluginSettings.pollIntervalSec : 5) * 1000

  function getHelperPath() {
    return (pluginApi && pluginApi.pluginDir) ? (pluginApi.pluginDir + "/scripts/virt-helper.sh") : "virt-helper.sh";
  }

  function refresh() {
    if (proc.running) return;
    root.isRefreshing = true;
    proc.command = [getHelperPath(), "list"];
    proc.running = true;
  }

  function launchVm(name) {
    if (!name || String(name).trim() === "") return;
    Quickshell.execDetached([getHelperPath(), "launch", String(name).trim()]);
  }

  Process {
    id: proc
    stdout: StdioCollector {}

    onExited: function(exitCode) {
      root.isRefreshing = false;
      if (exitCode === 0) {
        try {
          var raw = (proc.stdout && proc.stdout.text) ? proc.stdout.text.trim() : "";
          if (raw.length > 0) {
            var parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) {
              root.runningVms = parsed;
              return;
            }
          }
        } catch (e) {
          // Keep previous state on parse error
        }
      }
    }
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    root.refresh();
  }
}
