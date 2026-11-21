import QtQuick
import qs.Ui

// Ryoku mark in the native Omarchy bar. Only replaces the launcher widget.
// The original omarchy.menu plugin and its menu are kept enabled.
Item {
  id: root
  property var bar: null
  property string moduleName: "ryoku-menu"
  property var settings: ({})

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "緑"
    fontFamily: "Noto Sans CJK JP"
    tooltipText: "Ryoku — menu do Omarchy"

    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton) {
        root.bar.run("xdg-terminal-exec")
      } else {
        root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
      }
    }
  }
}
