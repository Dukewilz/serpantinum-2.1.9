import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Rectangle {
    id: sideTopRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property real targetY: 0
    property bool showLayout: barWindow ? Boolean(barWindow.isStartupReady) : true
    property alias helpButton: helpBtn

    y: targetY
    property real targetWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    property real targetHeight: targetWidth

    width: targetWidth
    height: targetHeight

    radius: Math.round(targetWidth / 2)
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && (barWindow.barOpacity * (barWindow.barContentOpacity !== undefined ? barWindow.barContentOpacity : 1.0)) !== undefined) ? (barWindow.barOpacity * (barWindow.barContentOpacity !== undefined ? barWindow.barContentOpacity : 1.0)) : 1.0) : 0.0
    visible: opacity > 0
    enabled: moduleActive

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    IconButton {
        id: helpBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(sideTopRoot.isCompact ? 32 : 34) : (sideTopRoot.isCompact ? 32 : 34)
        height: barWindow ? barWindow.s(sideTopRoot.isCompact ? 32 : 34) : (sideTopRoot.isCompact ? 32 : 34)
        cornerRadius: Math.round((barWindow ? barWindow.s(sideTopRoot.isCompact ? 32 : 34) : (sideTopRoot.isCompact ? 32 : 34)) / 2)
        buttonIcon: "󰒓"
        iconOffsetX: 0
        iconFontSize: barWindow ? barWindow.s(sideTopRoot.isCompact ? 17 : 18) : (sideTopRoot.isCompact ? 17 : 18)
        accentColor: sideTopRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (sideTopRoot.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle guide"])
    }
}
