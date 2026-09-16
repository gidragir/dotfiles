import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null

  property var rgbData: ({
    "current": "off",
    "brightness": 100,
    "base_color": "FF0000",
    "profiles": ["off"]
  })

  readonly property string helperScript: (pluginApi?.pluginDir || "") + "/scripts/openrgb-helper.sh"
  readonly property int pollInterval: (pluginApi?.pluginSettings?.pollIntervalSec ?? 10) * 1000

  // ── Command Queue (prevents race conditions on rapid clicks) ──────────────
  property var _cmdQueue: []
  property bool busy: false

  function _enqueue(args) {
    _cmdQueue.push([helperScript].concat(args));
    if (!busy) _runNext();
  }

  function _runNext() {
    if (_cmdQueue.length === 0) {
      busy = false;
      return;
    }
    busy = true;
    proc.command = _cmdQueue.shift();
    proc.running = true;
  }

  // ── Internal: update rgbData.current without a full list round-trip ───────
  function _setCurrentOptimistic(value) {
    var updated = ({});
    var keys = Object.keys(root.rgbData);
    for (var i = 0; i < keys.length; i++) updated[keys[i]] = root.rgbData[keys[i]];
    updated.current = value;
    root.rgbData = updated;
  }

  function _setBrightnessOptimistic(value) {
    var updated = ({});
    var keys = Object.keys(root.rgbData);
    for (var i = 0; i < keys.length; i++) updated[keys[i]] = root.rgbData[keys[i]];
    updated.brightness = value;
    root.rgbData = updated;
  }

  // ── Public API ────────────────────────────────────────────────────────────
  function refresh() {
    _enqueue(["list"]);
  }

  function applyProfile(name) {
    _setCurrentOptimistic(name);   // immediate UI feedback
    _enqueue(["apply", name]);
  }

  function applyColor(hex) {
    _setCurrentOptimistic("custom_" + hex.toLowerCase());  // immediate UI feedback
    _enqueue(["set_color", hex]);
  }

  function setBrightness(percent) {
    var val = Math.max(0, Math.min(100, Math.round(percent)));
    _setBrightnessOptimistic(val);
    _enqueue(["set_brightness", val.toString()]);
  }

  function saveProfile(name) {
    if (!name || name.trim() === "") return;
    _enqueue(["save", name.trim()]);
  }

  function deleteProfile(name) {
    if (!name || name === "off") return;
    _enqueue(["delete", name]);
  }

  // ── Single process handles all commands sequentially ─────────────────────
  Process {
    id: proc
    stdout: StdioCollector {}

    onExited: (exitCode) => {
      if (exitCode === 0 && proc.command[1] === "list") {
        try {
          var res = JSON.parse(proc.stdout.text.trim());
          root.rgbData = res;
        } catch (_) {}
      }
      root.busy = false;
      root._runNext();
      // After any mutating command, sync state from backend
      if (proc.command[1] !== "list") {
        root.refresh();
      }
    }
  }

  // ── Polling timer ─────────────────────────────────────────────────────────
  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    root.refresh();
  }
}
