import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property var requestedLayoutTemplate: []
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property int maxApps: 10
    property real iconSize: s(42)
    property real itemSpacing: s(6)
    property real dockPadding: s(8)

    property real dockThickness: iconSize + (dockPadding * 2)
    property real dockSpan: appModel.count > 0 ? (appModel.count * iconSize) + ((appModel.count - 1) * itemSpacing) + (dockPadding * 2) : s(90)

    property real preferredWidth: dockThickness + s(6)
    property real preferredExtraLength: typeof floatingWidget !== "undefined" ? Math.max(0, dockSpan - floatingWidget.baseSidebarH + s(12)) : dockSpan

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    property bool isHorizontal: root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top"

    property color cBase: ThemeBackend.base
    property color cSurface0: ThemeBackend.surface0
    property color cSurface1: ThemeBackend.surface1
    property color cText: ThemeBackend.text

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    readonly property var appEntries: DesktopEntries.applications.values
    function refreshApps() {
        appModel.clear();
        let entries = appEntries || [];
        for (let i = 0; i < entries.length && appModel.count < root.maxApps; ++i) {
            let entry = entries[i];
            if (!entry || entry.noDisplay) continue;
            appModel.append({name: entry.name, icon: entry.icon || "", desktopId: entry.id});
        }
    }
    onAppEntriesChanged: refreshApps()
    Component.onCompleted: refreshApps()
    ListModel { id: appModel }
    function launchApp(desktopId) {
        let entry = IconResolver.entryFor(desktopId);
        if (entry) entry.execute();
    }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: root.isHorizontal ? root.dockSpan : root.dockThickness
        height: root.isHorizontal ? root.dockThickness : root.dockSpan
        rotation: root.counterRotation
        clip: false

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: root.alpha(root.cSurface0, 0.85)
            border.color: root.alpha(root.cText, 0.1)
            border.width: 1

            ListView {
                id: dockList
                anchors.fill: parent
                anchors.margins: root.dockPadding
                orientation: root.isHorizontal ? ListView.Horizontal : ListView.Vertical
                spacing: root.itemSpacing
                model: appModel
                interactive: false
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    width: root.iconSize
                    height: root.iconSize

                    Rectangle {
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: itemMouseArea.containsMouse ? root.alpha(root.cSurface1, 0.4) : "transparent"
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: parent.width * 0.8
                        height: parent.height * 0.8

                        property real hoverScale: itemMouseArea.pressed ? 0.92 : (itemMouseArea.containsMouse ? 1.08 : 1.0)
                        scale: hoverScale
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                        Image {
                            id: dockIcon
                            anchors.fill: parent
                            source: IconResolver.source(model.icon, model.desktopId)
                            visible: source !== "" && status === Image.Ready
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                        }

                        Text {
        id: v24Icon10
        TextMetrics { id: v24Ink10; text: v24Icon10.text; font: v24Icon10.font }
        transform: Translate {
            x: (v24Icon10.implicitWidth - v24Ink10.tightBoundingRect.width) / 2 - v24Ink10.tightBoundingRect.x
            y: (v24Icon10.implicitHeight - v24Ink10.tightBoundingRect.height) / 2 - v24Ink10.tightBoundingRect.y - v24Icon10.baselineOffset
        }

                            anchors.centerIn: parent
                            visible: !dockIcon.visible
                            text: "󰣆"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: Math.min(parent.width, parent.height) * 0.55
                            color: ThemeBackend.subtext0
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchApp(model.desktopId)
                    }
                }
            }
        }
    }
}
