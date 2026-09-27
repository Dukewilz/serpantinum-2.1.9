import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"

Popup {
    id: themeEditorPopup
    parent: rootObj ? rootObj : undefined
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    width: rootObj ? Math.min(rootObj.width - rootObj.s(32), rootObj.s(680)) : 680
    padding: rootObj ? rootObj.s(20) : 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property real tileWidth: 0

    property string editingThemeName: ""
    property var currentColors: ({})

    readonly property var colorKeys: [
        "base", "mantle", "crust",
        "surface0", "surface1", "surface2",
        "overlay0", "overlay1", "overlay2",
        "subtext0", "subtext1", "text",
        "lavender", "blue", "sapphire", "sky", "teal", "green",
        "yellow", "peach", "maroon", "red", "mauve", "pink", "flamingo", "rosewater"
    ]

    function tr(key, fallback) {
        let value = I18n.t(key);
        return !value || value === key ? fallback : value;
    }
    function setColor(key, value) {
        let colors = Object.assign({}, currentColors);
        colors[key] = value;
        currentColors = colors;
    }
    signal saveRequested(var themeObj)

    function openForNew() {
        editingThemeName = "";
        themeNameInput.text = "";
        let initial = {};
        for (let i = 0; i < colorKeys.length; i++) {
            let k = colorKeys[i];
            initial[k] = ThemeBackend[k] ? ThemeBackend[k].toString() : "#000000";
        }
        currentColors = initial;
        open();
        themeNameInput.forceInputFocus();
    }

    function openForEdit(themeObj) {
        if (!themeObj) return;
        editingThemeName = themeObj.name || "";
        themeNameInput.text = editingThemeName;
        let initial = {};
        let src = themeObj.colors || {};
        for (let i = 0; i < colorKeys.length; i++) {
            let k = colorKeys[i];
            if (src[k]) {
                initial[k] = src[k];
            } else {
                initial[k] = ThemeBackend[k] ? ThemeBackend[k].toString() : "#000000";
            }
        }
        currentColors = initial;
        open();
        themeNameInput.forceInputFocus();
    }

    function commitSave() {
        let name = themeNameInput.text.trim();
        if (!name) {
            themeNameInput.triggerShake();
            return;
        }
        let themeObj = {
            "name": name,
            "isCustom": true,
            "category": "user",
            "colors": currentColors
        };
        themeEditorPopup.saveRequested(themeObj);
        close();
    }

    Connections {
        target: themeEditorPopup.rootObj ? themeEditorPopup.rootObj : null
        function onVisibleChanged() {
            if (themeEditorPopup.rootObj && !themeEditorPopup.rootObj.visible) {
                themeEditorPopup.close();
            }
        }
    }

    Connections {
        target: themeEditorPopup.parent && themeEditorPopup.parent !== themeEditorPopup.rootObj ? themeEditorPopup.parent : null
        function onVisibleChanged() {
            if (themeEditorPopup.parent && !themeEditorPopup.parent.visible) {
                themeEditorPopup.close();
            }
        }
    }

    background: Rectangle {
        radius: ThemeBackend.clampedBorderRadius
        color: ThemeBackend.base
        border.color: ThemeBackend.surface0
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: rootObj ? rootObj.s(16) : 16

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: themeEditorPopup.editingThemeName === "" ? themeEditorPopup.tr("guide.theme.editor.create_title", "Create Custom Theme") : themeEditorPopup.tr("guide.theme.editor.edit_title", "Edit Custom Theme")
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj ? rootObj.s(16) : 16
                font.bold: true
                Layout.fillWidth: true
            }

            IconButton {
                size: rootObj ? rootObj.s(30) : 30
                cornerRadius: rootObj ? rootObj.s(8) : 8
                buttonIcon: "󰅖"
                iconFontSize: rootObj ? rootObj.s(14) : 14
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: themeEditorPopup.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: rootObj ? rootObj.s(10) : 10

            Input {
                id: themeNameInput
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj ? rootObj.s(36) : 36
                placeholderText: themeEditorPopup.tr("guide.theme.editor.name_placeholder", "Theme Name...")
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontPixelSize: rootObj ? rootObj.s(12) : 12
                onAccepted: themeEditorPopup.commitSave()
            }

            IconButton {
                size: rootObj ? rootObj.s(36) : 36
                Layout.preferredWidth: rootObj ? rootObj.s(36) : 36
                Layout.preferredHeight: rootObj ? rootObj.s(36) : 36
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰄬"
                iconFontSize: rootObj ? rootObj.s(16) : 16
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: themeEditorPopup.commitSave()
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: rootObj ? rootObj.s(320) : 320
            contentHeight: colorsGrid.implicitHeight
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: rootObj ? rootObj.s(4) : 4
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    radius: rootObj ? rootObj.s(2) : 2
                    color: ThemeBackend.surface2
                }
            }

            GridLayout {
                id: colorsGrid
                width: parent.width - (rootObj ? rootObj.s(8) : 8)
                columns: 2
                rowSpacing: rootObj ? rootObj.s(8) : 8
                columnSpacing: rootObj ? rootObj.s(12) : 12

                Repeater {
                    model: themeEditorPopup.colorKeys
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj ? rootObj.s(8) : 8

                        Rectangle {
                            Layout.preferredWidth: rootObj ? rootObj.s(28) : 28
                            Layout.preferredHeight: rootObj ? rootObj.s(28) : 28
                            radius: rootObj ? rootObj.s(6) : 6
                            color: themeEditorPopup.currentColors[modelData] || "#000000"
                            border.width: 1
                            border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: visualPicker.choose(modelData, parent.color)
                            }
                        }

                        Text {
                            text: modelData
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: rootObj ? rootObj.s(12) : 12
                            Layout.preferredWidth: rootObj ? rootObj.s(80) : 80
                            elide: Text.ElideRight
                        }

                        Input {
                            Layout.fillWidth: true
                            Layout.preferredHeight: rootObj ? rootObj.s(28) : 28
                            text: themeEditorPopup.currentColors[modelData] || ""
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: rootObj ? rootObj.s(6) : 6
                            fontPixelSize: rootObj ? rootObj.s(11) : 11
                            onTextEdited: newText => {
                                if (/^#[0-9a-fA-F]{6}$/.test(newText)) themeEditorPopup.setColor(modelData, newText);
                            }
                        }
                    }
                }
            }
        }
    }
    onClosed: visualPicker.close()
    Popup {
        id: visualPicker
        parent: themeEditorPopup.contentItem
        anchors.centerIn: parent
        width: Math.min(parent.width, 360)
        padding: 16
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property string colorKey: ""
        property real hue: 0
        property real saturation: 0
        property real brightness: 0
        readonly property color preview: Qt.hsva(hue, saturation, brightness, 1)
        function choose(key, value) {
            colorKey = key;
            hue = Math.max(0, value.hsvHue);
            saturation = value.hsvSaturation;
            brightness = value.hsvValue;
            open();
        }
        background: Rectangle { radius: ThemeBackend.borderRadius; color: ThemeBackend.base; border.color: ThemeBackend.surface2 }
        contentItem: ColumnLayout {
            spacing: 10
            Text { text: "Choose color · " + visualPicker.colorKey; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 14 }
            Rectangle { Layout.fillWidth: true; implicitHeight: 58; radius: 10; color: visualPicker.preview }
            Text { text: "Hue"; color: ThemeBackend.text }
            Slider { Layout.fillWidth: true; from: 0; to: 1; value: visualPicker.hue; onMoved: visualPicker.hue = value }
            Text { text: "Saturation"; color: ThemeBackend.text }
            Slider { Layout.fillWidth: true; from: 0; to: 1; value: visualPicker.saturation; onMoved: visualPicker.saturation = value }
            Text { text: "Brightness"; color: ThemeBackend.text }
            Slider { Layout.fillWidth: true; from: 0; to: 1; value: visualPicker.brightness; onMoved: visualPicker.brightness = value }
            RowLayout {
                Layout.fillWidth: true
                Button { text: "Cancel"; onClicked: visualPicker.close() }
                Item { Layout.fillWidth: true }
                Button { text: "Use color"; onClicked: { themeEditorPopup.setColor(visualPicker.colorKey, visualPicker.preview.toString()); visualPicker.close(); } }
            }
        }
    }

}
