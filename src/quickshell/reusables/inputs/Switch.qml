import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../../"

Item {
    id: root
    implicitWidth: Math.max(120, (root.maxNeededWidth > 0 ? root.maxNeededWidth : 28) * (root.options ? root.options.length : 1))
    implicitHeight: 32

    property var options: ["x", "y"]
    property var optionIcons: []
    property int iconPixelSize: fontPixelSize
    property int iconSpacing: 8
    FontLoader { id: switchIconFont; source: "../../assets/fonts/IosevkaNerdFont-Regular.ttf" }
    property int currentIndex: 0

    property color accentColor: "#89b4fa"
    property color baseColor: "#1affffff"
    property color textColor: "#cdd6f4"
    property color activeTextColor: "#11111b"

    property int cornerRadius: 8
    property int smallRadius: 2
    property int fontPixelSize: 11
    property int minFontPixelSize: 7
    property bool enabled: true
    property string switchSound: "reusables/switch/sfx.wav"

    signal valueChanged(int index, string value)
    signal toggled(int index)
    signal clicked()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    property real maxNeededWidth: 0
    property real totalNeededWidth: 0
    property var allocatedWidths: []

    function recalculateLayout() {
        var count = root.options ? root.options.length : 0;
        if (count === 0) {
            root.allocatedWidths = [];
            return;
        }

        var needs = [];
        var totalNeeded = 0;
        var maxNeeded = 0;

        for (var i = 0; i < count; i++) {
            var it = tabsRepeater.itemAt(i);
            var req = it ? it.fitWidth : 28;
            needs.push(req);
            totalNeeded += req;
            if (req > maxNeeded) {
                maxNeeded = req;
            }
        }

        root.maxNeededWidth = maxNeeded;
        root.totalNeededWidth = totalNeeded;

        var availableW = root.width;
        if (availableW <= 0) {
            availableW = Math.max(120, maxNeeded * count);
        }

        var equalW = availableW / count;
        var widths = [];

        if (maxNeeded <= equalW) {
            for (var i = 0; i < count; i++) {
                widths.push(equalW);
            }
        } else if (availableW >= totalNeeded) {
            var totalDeficit = 0;
            var totalSurplus = 0;

            for (var i = 0; i < count; i++) {
                if (needs[i] > equalW) {
                    totalDeficit += (needs[i] - equalW);
                } else {
                    totalSurplus += (equalW - needs[i]);
                }
            }

            var f = totalSurplus > 0 ? (totalDeficit / totalSurplus) : 0;
            if (f > 1.0) f = 1.0;

            for (var i = 0; i < count; i++) {
                if (needs[i] > equalW) {
                    widths.push(needs[i]);
                } else {
                    widths.push(equalW - f * (equalW - needs[i]));
                }
            }
        } else {
            for (var i = 0; i < count; i++) {
                widths.push(totalNeeded > 0 ? (availableW * (needs[i] / totalNeeded)) : equalW);
            }
        }

        root.allocatedWidths = widths;
    }

    onWidthChanged: recalculateLayout()
    onOptionsChanged: recalculateLayout()
    onOptionIconsChanged: recalculateLayout()
    onFontPixelSizeChanged: recalculateLayout()
    onIconPixelSizeChanged: recalculateLayout()

    Rectangle {
        id: bgShape
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.baseColor
        clip: true
        opacity: root.enabled ? 1.0 : 0.5

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on opacity { NumberAnimation { duration: 180 } }

        scale: root.popScale
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

        Rectangle {
            id: activeTabHighlight
            property int prevIdx: 0
            property int curIdx: root.currentIndex

            onCurIdxChanged: {
                if (curIdx > prevIdx) { rightAnim.duration = 200; leftAnim.duration = 350; }
                else if (curIdx < prevIdx) { leftAnim.duration = 200; rightAnim.duration = 350; }
                prevIdx = curIdx;
            }

            readonly property Item currentItem: (tabsRepeater && root.options && root.currentIndex >= 0 && root.currentIndex < tabsRepeater.count)
                ? tabsRepeater.itemAt(root.currentIndex)
                : null

            property real targetLeft: currentItem ? currentItem.x : 0
            property real targetRight: currentItem ? (currentItem.x + currentItem.width) : 0

            property real actualLeft: targetLeft
            property real actualRight: targetRight

            Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
            Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

            y: 0
            height: bgShape.height
            x: actualLeft
            width: Math.max(0, actualRight - actualLeft)
            z: 0

            topLeftRadius: root.currentIndex === 0 ? root.cornerRadius : root.smallRadius
            bottomLeftRadius: root.currentIndex === 0 ? root.cornerRadius : root.smallRadius
            topRightRadius: root.currentIndex === root.options.length - 1 ? root.cornerRadius : root.smallRadius
            bottomRightRadius: root.currentIndex === root.options.length - 1 ? root.cornerRadius : root.smallRadius

            Behavior on topLeftRadius { NumberAnimation { duration: 180 } }
            Behavior on bottomLeftRadius { NumberAnimation { duration: 180 } }
            Behavior on topRightRadius { NumberAnimation { duration: 180 } }
            Behavior on bottomRightRadius { NumberAnimation { duration: 180 } }

            color: root.accentColor

            Behavior on color { ColorAnimation { duration: 180 } }
        }

        Row {
            id: tabsRow
            anchors.fill: parent
            spacing: 0
            z: 1

            Repeater {
                id: tabsRepeater
                model: root.options
                onCountChanged: root.recalculateLayout()

                Item {
                    id: optionItem
                    required property string modelData
                    required property int index

                    readonly property string optionIcon: root.optionIcons && root.optionIcons.length > index ? root.optionIcons[index] : ""
                    readonly property real fitWidth: Math.max(28, Math.ceil(optMetrics.width) + (optionIcon ? Math.ceil(iconMetrics.width) + (modelData ? root.iconSpacing : 0) : 0) + 14)

                    width: (root.allocatedWidths && root.allocatedWidths.length > optionItem.index)
                        ? root.allocatedWidths[optionItem.index]
                        : (root.options && root.options.length > 0 ? (parent.width / root.options.length) : 0)
                    height: parent.height

                    Component.onCompleted: root.recalculateLayout()

                    TextMetrics {
                        id: optMetrics
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Normal
                        font.pixelSize: root.fontPixelSize
                        text: optionItem.modelData
                        onWidthChanged: root.recalculateLayout()
                    }

                    TextMetrics {
                        id: iconMetrics
                        font.family: switchIconFont.status === FontLoader.Ready ? switchIconFont.name : "Iosevka Nerd Font"
                        font.pixelSize: root.iconPixelSize
                        text: optionItem.optionIcon
                        onWidthChanged: root.recalculateLayout()
                    }

                    Rectangle {
                        anchors.fill: parent
                        topLeftRadius: optionItem.index === 0 ? root.cornerRadius : root.smallRadius
                        bottomLeftRadius: optionItem.index === 0 ? root.cornerRadius : root.smallRadius
                        topRightRadius: optionItem.index === root.options.length - 1 ? root.cornerRadius : root.smallRadius
                        bottomRightRadius: optionItem.index === root.options.length - 1 ? root.cornerRadius : root.smallRadius
                        color: root.currentIndex === optionItem.index ? "transparent" : (optionMa.containsMouse ? "#1affffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        visible: optionItem.optionIcon === ""
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: optionItem.modelData
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Normal
                        font.pixelSize: root.fontPixelSize
                        fontSizeMode: Text.Fit
                        minimumPixelSize: root.minFontPixelSize
                        color: root.currentIndex === optionItem.index ? root.activeTextColor : root.textColor
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    RowLayout {
                        visible: optionItem.optionIcon !== ""
                        anchors.centerIn: parent
                        width: Math.max(0, Math.min(parent.width - 12, iconMetrics.width + (optionItem.modelData ? root.iconSpacing + optMetrics.width : 0)))
                        height: parent.height
                        spacing: optionItem.modelData ? root.iconSpacing : 0

                        CenteredIcon {
                            Layout.preferredWidth: iconMetrics.width
                            Layout.preferredHeight: root.iconPixelSize + 4
                            Layout.alignment: Qt.AlignVCenter
                            text: optionItem.optionIcon
                            pixelSize: root.iconPixelSize
                            color: root.currentIndex === optionItem.index ? root.activeTextColor : root.textColor
                        }
                        Text {
                            visible: optionItem.modelData !== ""
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: optionItem.modelData
                            elide: Text.ElideRight
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.fontPixelSize
                            fontSizeMode: Text.Fit
                            minimumPixelSize: root.minFontPixelSize
                            color: root.currentIndex === optionItem.index ? root.activeTextColor : root.textColor
                        }
                    }

                    MouseArea {
                        id: optionMa
                        anchors.fill: parent
                        enabled: root.enabled
                        hoverEnabled: true
                        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (!root.enabled) return;
                            if (root.currentIndex !== optionItem.index) {
                                root.currentIndex = optionItem.index;
                                root.valueChanged(optionItem.index, optionItem.modelData);
                                root.toggled(optionItem.index);
                            }
                            btnPopAnim.start();
                            root.flashOpacity = 0.2;
                            btnFlashAnim.start();
                            if (typeof Sounds !== "undefined") {
                                Sounds.playSfx(root.switchSound);
                            }
                            root.clicked();
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "#ffffff"
            opacity: root.flashOpacity
            z: 2
            PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
        }
    }

    SequentialAnimation {
        id: btnPopAnim
        NumberAnimation { target: root; property: "popScale"; to: 1.04; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
    }
}
