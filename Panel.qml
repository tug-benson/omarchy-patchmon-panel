import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.tug-benson.patchmon"
  ipcTarget: "io.github.tug-benson.patchmon"

  // ---- configuration (from the widget's shell.json entry) -----------------
  readonly property string serverUrl: (setting("serverUrl", "") || "").replace(/\/+$/, "")
  readonly property string apiKey: setting("apiKey", "") || ""
  readonly property string apiSecret: setting("apiSecret", "") || ""
  readonly property string hostGroup: setting("hostGroup", "") || ""
  readonly property bool verifySsl: setting("verifySsl", true)
  readonly property int refreshIntervalSec: Math.max(15, setting("refreshIntervalSec", 60))
  // A host counts as "reporting/online" when it last checked in within this
  // many minutes. PatchMon's Integration API does not expose reporting_state,
  // so we derive connectivity from how fresh `last_update` is.
  readonly property int staleAfterMin: Math.max(1, setting("staleAfterMin", 1440))
  readonly property bool configured: serverUrl !== "" && apiKey !== "" && apiSecret !== ""
  readonly property string serverHost: (function () { var m = String(serverUrl).match(/\/\/([^/]+)/); return m ? m[1] : serverUrl; })()
  readonly property string scriptPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.tug-benson.patchmon/bin/fetch.sh"

  // ---- theme shortcuts ----------------------------------------------------
  // Popup content keys off the *popup* surface tokens so text stays readable
  // against the panel background (Color.popups.background), not the bar's.
  readonly property color fg: Color.popups.text
  readonly property color dim: Color.muted
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property string ff: root.bar ? root.bar.fontFamily : "monospace"
  // Bar-icon tokens (contrast against the bar surface, not the popup).
  readonly property color barFg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color barAccent: root.bar ? root.bar.accent : Color.accent
  readonly property color barUrgent: root.bar ? root.bar.urgent : Color.urgent

  // ---- glyphs (Font Awesome, patched into the Omarchy nerd font) ----------
  readonly property string gServer: "\uF233"
  readonly property string gCheck: "\uF00C"
  readonly property string gRefresh: "\uF021"
  readonly property string gPower: "\uF011"
  readonly property string gNet: "\uF4FC"
  readonly property string gShield: "\uF483"
  readonly property string gBoxes: "\uF466"
  readonly property string gDownload: "\uF019"
  readonly property string gLock: "\uF132"
  readonly property string gUsers: "\uF0C0"
  readonly property string gExt: "\uF08E"
  readonly property string gWarn: "\uF071"
  readonly property string gClock: "\uF017"

  // ---- PatchMon dashboard card palette (from the PatchMon web UI) ----------
  readonly property color cardBg: "#1d223c"
  readonly property color cMuted: "#5b6478"
  readonly property color cHosts: "#2865eb"
  readonly property color cUpdates: "#d97909"
  readonly property color cReboot: "#e0524f"
  readonly property color cConn: "#36a3f7"
  readonly property color cPackages: "#8b93b0"
  readonly property color cScore: "#3fb950"
  readonly property color cSec: "#e0524f"

  // ---- runtime state ------------------------------------------------------
  property var rawData: ({})
  property bool reachable: false
  property string errorText: ""
  property int lastFetchEpoch: 0
  property int nowTick: 0

  property int total: 0
  property int connected: 0
  property int offline: 0
  property int needsUpdates: 0
  property int needsReboot: 0
  property int upToDateHosts: 0
  property int securityHosts: 0
  property int outdatedPackages: 0
  property int securityPackages: 0
  property int totalPackages: 0
  property int securityScore: 100
  property var osDist: []
  property var hostsOffline: []
  property var hostsNeedReboot: []
  property var hostsNeedUpdate: []
  property var hostsUpToDate: []

  readonly property var hosts: (rawData && rawData.hosts && Array.isArray(rawData.hosts)) ? rawData.hosts : []

  // ---- derived presentation ----------------------------------------------
  readonly property color statusColor: (!configured) ? barFg
    : (!reachable ? barUrgent
      : (securityHosts > 0 || offline > 0 ? barUrgent
        : (needsUpdates > 0 || needsReboot > 0 ? barAccent : barFg)))
  readonly property color scoreColor: securityScore >= 85 ? fg
    : (securityScore >= 60 ? accent : urgent)
  readonly property string barIcon: configured ? (reachable ? gServer : gWarn) : gServer
  readonly property string tooltipText: (!configured) ? "PatchMon — not configured"
    : (!reachable) ? "PatchMon — unreachable"
    : ("PatchMon — " + total + " hosts · " + needsUpdates + " updates · " + needsReboot + " reboot · " + connected + "/" + total + " online")
  readonly property string lastUpdatedText: (function () {
    if (!root.lastFetchEpoch) return "never"
    var d = root.nowTick - root.lastFetchEpoch
    if (d < 0) d = 0
    if (d < 60) return d + "s ago"
    if (d < 3600) return Math.floor(d / 60) + "m ago"
    return Math.floor(d / 3600) + "h ago"
  })()

  // ---- aggregation --------------------------------------------------------
  function recompute() {
    var hs = root.hosts
    var c = 0, off = 0, nu = 0, nr = 0, ud = 0, sh = 0, op = 0, sp = 0, tpk = 0
    var od = {}
    var offlineArr = [], rebArr = [], updArr = [], okArr = []
    for (var i = 0; i < hs.length; i++) {
      var h = hs[i]
      var uc = Number(h.updates_count) || 0
      var sc = Number(h.security_updates_count) || 0
      var t = Number(h.total_packages) || 0
      var online = hostAgeMin(h.last_update) <= root.staleAfterMin
      if (online) c++; else { off++; offlineArr.push(h) }
      if (uc > 0) nu++
      if (h.needs_reboot === true) nr++
      if (uc === 0 && sc === 0) ud++
      if (sc > 0) sh++
      op += uc; sp += sc; tpk += t
      var os = h.os_type || "Unknown"
      od[os] = (od[os] || 0) + 1
      if (online) {
        if (h.needs_reboot === true) rebArr.push(h)
        else if (uc > 0) updArr.push(h)
        else okArr.push(h)
      }
    }
    total = hs.length; connected = c; offline = off
    needsUpdates = nu; needsReboot = nr; upToDateHosts = ud
    securityHosts = sh; outdatedPackages = op; securityPackages = sp; totalPackages = tpk
    function byName(a, b) {
      var na = (a.friendly_name || a.hostname || "").toLowerCase()
      var nb = (b.friendly_name || b.hostname || "").toLowerCase()
      return na < nb ? -1 : (na > nb ? 1 : 0)
    }
    offlineArr.sort(byName); rebArr.sort(byName); updArr.sort(byName); okArr.sort(byName)
    var arr = []
    for (var k in od) arr.push({ name: k, count: od[k] })
    arr.sort(function (a, b) { return b.count - a.count })
    osDist = arr
    hostsOffline = offlineArr; hostsNeedReboot = rebArr; hostsNeedUpdate = updArr; hostsUpToDate = okArr
    var tt = Math.max(1, total)
    var score = 100 - Math.round(50 * (sh / tt) + 20 * (nr / tt) + 30 * (nu / tt))
    securityScore = Math.max(0, Math.min(100, score))
  }

  function apply(raw) {
    try {
      var data = JSON.parse(raw)
      if (data && data.error) {
        root.reachable = false
        root.errorText = data.error
        return
      }
      root.rawData = data
      root.reachable = true
      root.errorText = ""
      root.lastFetchEpoch = Math.floor(Date.now() / 1000)
      root.recompute()
    } catch (e) {
      root.reachable = false
      root.errorText = "parse-error"
    }
  }

  function refresh() {
    if (fetchProc.running) return
    fetchProc.running = true
  }

  // Minutes since a host last reported. Infinity if unknown.
  function hostAgeMin(iso) {
    if (!iso) return Infinity
    var t = Date.parse(iso)
    if (!t || isNaN(t)) return Infinity
    return Math.max(0, (Date.now() - t) / 60000)
  }

  Component.onCompleted: if (configured) refresh()

  Process {
    id: fetchProc
    command: ["bash", root.scriptPath, root.serverUrl, root.apiKey, root.apiSecret, root.hostGroup, (root.verifySsl ? "0" : "1")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  // Background refresh while closed; faster while the panel is open.
  Timer {
    interval: root.refreshIntervalSec * 1000
    running: !root.opened
    repeat: true
    onTriggered: root.refresh()
  }
  Timer {
    interval: 10000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: root.nowTick = Math.floor(Date.now() / 1000)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIcon
    foreground: root.statusColor
    slotSize: Style.bar.iconSlot
    tooltipText: root.tooltipText
    onPressed: function (b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) { if (t === "r" || t === "R") root.refresh() }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(14)

      // ---------- Hero ----------
      PanelHero {
        width: parent.width
        foreground: root.fg
        fontFamily: root.ff
        iconComponent: Component {
          Text {
            text: root.configured ? (root.reachable ? root.gServer : root.gWarn) : root.gServer
            color: root.statusColor
            font.family: root.ff
            font.pixelSize: Style.font.display
          }
        }
        title: "PatchMon"
        meta: root.configured ? (root.reachable ? ("Connected · " + root.serverHost) : "Unreachable") : "Not configured"
        detail: root.configured && root.reachable ? ("updated " + root.lastUpdatedText) : ""
      }

      // ---------- Banners ----------
      Text {
        visible: !root.configured
        width: parent.width
        text: "Not configured. Set serverUrl, apiKey and apiSecret for this widget in ~/.config/omarchy/shell.json."
        color: root.accent
        font.family: root.ff
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
      Text {
        visible: root.configured && !root.reachable
        width: parent.width
        text: "PatchMon unreachable (" + (root.errorText || "error") + ") — showing last known data."
        color: root.urgent
        font.family: root.ff
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      // ---------- Footer (kept near the top so it is always visible) ----------
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        Button {
          Layout.fillWidth: true
          text: "Open PatchMon"
          iconText: root.gExt
          fontFamily: root.ff
          foreground: root.fg
          bordered: true
          onClicked: if (root.serverUrl) Qt.openUrlExternally(root.serverUrl)
        }
        Button {
          Layout.fillWidth: true
          text: "Refresh"
          iconText: root.gRefresh
          fontFamily: root.ff
          foreground: root.fg
          bordered: true
          onClicked: root.refresh()
        }
      }

      PanelSeparator { foreground: root.fg }

      // ---------- Dashboard cards ----------
      GridLayout {
        width: parent.width
        columns: 3
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gServer; label: "Hosts"; value: String(root.total); tint: root.cHosts; fontFamily: root.ff }
        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gRefresh; label: "Needs Updates"; value: String(root.needsUpdates); tint: root.needsUpdates > 0 ? root.cUpdates : root.cMuted; fontFamily: root.ff }
        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gPower; label: "Needs Reboot"; value: String(root.needsReboot); tint: root.needsReboot > 0 ? root.cReboot : root.cMuted; fontFamily: root.ff }

        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gNet; label: "Connection"; value: root.connected + "/" + root.total; tint: root.offline > 0 ? root.cReboot : root.cConn; fontFamily: root.ff }
        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gShield; label: "Security Score"; value: root.securityScore + "%"; tint: root.cScore; valueColor: root.scoreColor; fontFamily: root.ff }
        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gBoxes; label: "Packages"; value: String(root.totalPackages); tint: root.cPackages; fontFamily: root.ff }

        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gDownload; label: "Outdated Pkgs"; value: String(root.outdatedPackages); tint: root.outdatedPackages > 0 ? root.cUpdates : root.cMuted; fontFamily: root.ff }
        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gLock; label: "Security Pkgs"; value: String(root.securityPackages); tint: root.securityPackages > 0 ? root.cSec : root.cMuted; fontFamily: root.ff }
        MetricCard { Layout.fillWidth: true; cardBackground: root.cardBg; glyph: root.gWarn; label: "Security Hosts"; value: String(root.securityHosts); tint: root.securityHosts > 0 ? root.cSec : root.cMuted; fontFamily: root.ff }
      }

      PanelSeparator { foreground: root.fg }

      // ---------- Connection ----------
      Collapsible {
        width: parent.width
        title: "Connection"
        badge: root.connected + "/" + root.total + " online"
        badgeColor: root.offline > 0 ? root.urgent : root.fg
        foreground: root.fg
        fontFamily: root.ff
        Column {
          width: parent.width
          spacing: Style.spacing.labelGap
          RowLayout {
            width: parent.width
            Text { text: "\u25CF"; color: root.fg; font.family: root.ff; font.pixelSize: Style.font.caption }
            Text { text: "Reporting (online)"; color: root.dim; font.family: root.ff; font.pixelSize: Style.font.bodySmall }
            Item { Layout.fillWidth: true }
            Text { text: String(root.connected); color: root.fg; font.family: root.ff; font.pixelSize: Style.font.bodySmall }
          }
          RowLayout {
            width: parent.width
            Text { text: "\u25CF"; color: root.urgent; font.family: root.ff; font.pixelSize: Style.font.caption }
            Text { text: "Offline / stale"; color: root.dim; font.family: root.ff; font.pixelSize: Style.font.bodySmall }
            Item { Layout.fillWidth: true }
            Text { text: String(root.offline); color: root.urgent; font.family: root.ff; font.pixelSize: Style.font.bodySmall }
          }
        }
      }

      // ---------- OS distribution ----------
      Collapsible {
        width: parent.width
        title: "OS Distribution"
        badge: String(root.osDist.length) + " types"
        foreground: root.fg
        fontFamily: root.ff
        Column {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: root.osDist
            delegate: RowLayout {
              width: parent.width
              spacing: Style.space(8)
              Text { text: modelData.name; color: root.fg; font.family: root.ff; font.pixelSize: Style.font.bodySmall; Layout.fillWidth: true; elide: Text.ElideRight }
              Item {
                Layout.preferredWidth: Style.space(80)
                height: Style.space(8)
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: parent.height; radius: Style.space(3); color: Qt.darker(root.fg, 2.2) }
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  height: parent.height
                  radius: Style.space(3)
                  color: root.accent
                  width: Math.max(Style.space(3), parent.width * (modelData.count / Math.max(1, root.total)))
                }
              }
              Text { text: String(modelData.count); color: root.dim; font.family: root.ff; font.pixelSize: Style.font.caption }
            }
          }
        }
      }

      // ---------- Hosts (drill-down, collapsed by default, last) ----------
      Collapsible {
        width: parent.width
        title: "Hosts"
        badge: String(root.total)
        defaultOpen: false
        foreground: root.fg
        fontFamily: root.ff
        Flickable {
          width: parent.width
          height: Math.min(inner.implicitHeight, Style.space(240))
          contentHeight: inner.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: inner
            width: parent.width
            spacing: Style.space(10)
            StatusGroup { title: "Offline / Stale"; model: root.hostsOffline; dotColor: root.urgent; foreground: root.fg; fontFamily: root.ff; accent: root.accent; urgent: root.urgent; staleAfterMin: root.staleAfterMin }
            StatusGroup { title: "Needs Reboot"; model: root.hostsNeedReboot; dotColor: root.urgent; foreground: root.fg; fontFamily: root.ff; accent: root.accent; urgent: root.urgent; staleAfterMin: root.staleAfterMin }
            StatusGroup { title: "Needs Updates"; model: root.hostsNeedUpdate; dotColor: root.accent; foreground: root.fg; fontFamily: root.ff; accent: root.accent; urgent: root.urgent; staleAfterMin: root.staleAfterMin }
            StatusGroup { title: "Up to Date"; model: root.hostsUpToDate; dotColor: root.fg; foreground: root.fg; fontFamily: root.ff; accent: root.accent; urgent: root.urgent; staleAfterMin: root.staleAfterMin }
          }
        }
      }

      } // Column
    } // PanelKeyCatcher
  } // KeyboardPanel

  // A status group inside the Hosts collapsible.
  component StatusGroup: Item {
    id: sg
    property string title: ""
    property var model: []
    property color dotColor: Color.foreground
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    property color accent: Color.accent
    property color urgent: Color.urgent
    property int staleAfterMin: 1440

    width: parent.width
    implicitHeight: col.implicitHeight

    Column {
      id: col
      width: parent.width
      spacing: Style.space(4)
      Row {
        width: parent.width
        spacing: Style.space(6)
        Text { text: "\u25CF"; color: sg.dotColor; font.family: sg.fontFamily; font.pixelSize: Style.font.caption }
        Text { text: sg.title + " (" + sg.model.length + ")"; color: Qt.darker(sg.foreground, 1.3); font.family: sg.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
      }
      Column {
        width: parent.width
        spacing: Style.space(2)
        visible: sg.model.length > 0
        Repeater {
          model: sg.model
          delegate: HostRow {
            host: modelData
            foreground: sg.foreground
            fontFamily: sg.fontFamily
            accent: sg.accent
            urgent: sg.urgent
            staleAfterMin: sg.staleAfterMin
            width: parent.width
          }
        }
      }
      Text {
        visible: sg.model.length === 0
        text: "None"
        color: Qt.darker(sg.foreground, 1.6)
        font.family: sg.fontFamily
        font.pixelSize: Style.font.caption
        font.italic: true
      }
    }
  }
}
