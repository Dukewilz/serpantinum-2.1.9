import QtQuick
import QtQuick.Effects
import "../"

Item {
    id: ambient

    property color accentColor: ThemeBackend.mauve
    property color secondaryColor: ThemeBackend.sapphire
    property color tertiaryColor: ThemeBackend.blue
    property string glyph: ""
    property real strength: 1.0
    // The host popup must opt in while it is actually active.  Popups are
    // cached by Main.qml, so Item.visible alone is not a safe lifecycle flag.
    property bool active: false
    property bool animate: active
    property bool allowWallpaper: true
    property real cornerRadius: {
        if (parent && parent.radius !== undefined) return Math.max(0, Number(parent.radius));
        return Math.max(0, ThemeBackend.clampedBorderRadius);
    }

    readonly property real baseLuma: 0.2126 * ThemeBackend.base.r + 0.7152 * ThemeBackend.base.g + 0.0722 * ThemeBackend.base.b
    readonly property real surfaceLuma: 0.2126 * ThemeBackend.surface0.r + 0.7152 * ThemeBackend.surface0.g + 0.0722 * ThemeBackend.surface0.b
    readonly property bool extremePalette: baseLuma < 0.075 || baseLuma > 0.90
    readonly property bool lowTonalSeparation: Math.abs(baseLuma - surfaceLuma) < 0.055
    readonly property real paletteBoost: extremePalette ? 1.82 : (lowTonalSeparation ? 1.48 : 1.0)
    readonly property real effectiveStrength: Math.max(0.0, strength * ThemeBackend.uiAmbientStrength)
    // Frosted tint follows the upstream palette, never a wallpaper fallback.
    readonly property color frostedColor: Qt.tint(ThemeBackend.base, Qt.alpha(ThemeBackend.surface0, 0.30))
    // Opacity affects only the background; foreground text/icons stay untouched.
    readonly property real frostedOpacity: Math.max(0.48, Math.min(0.82, ThemeBackend.uiBackgroundOpacity * 0.84))
    readonly property bool wallpaperActive: active && allowWallpaper && ThemeBackend.uiBackgroundUseWallpaper && ThemeBackend.uiBackgroundImageSource !== ""

    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: ambient.cornerRadius
        color: "white"
        visible: false
        antialiasing: true
        layer.enabled: true
        layer.smooth: true
    }

    Item {
        id: effectsLayer
        anchors.fill: parent
        layer.enabled: ambient.active && ambient.cornerRadius > 0
        layer.smooth: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: roundedMask
        }

        Loader {
            anchors.fill: parent
            active: ambient.wallpaperActive
            asynchronous: true
            sourceComponent: Component {
                Image {
                    source: ThemeBackend.uiBackgroundImageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    visible: status === Image.Ready
                    layer.enabled: visible && ambient.active && (ThemeBackend.uiGlossy || ThemeBackend.uiBackgroundBlur > 0.01)
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: ThemeBackend.uiGlossy ? 64 : 24
                        blur: ThemeBackend.uiGlossy ? Math.max(0.65, ThemeBackend.uiBackgroundBlur) : ThemeBackend.uiBackgroundBlur
                        autoPaddingEnabled: false
                    }
                }
            }
        }

        // Base color overlay — always visible when active so that opacity
        // changes are reflected in all source modes (theme, current, custom).
        // In wallpaper modes the wallpaper image renders behind this overlay.
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(ThemeBackend.uiGlossy ? ambient.frostedColor : ThemeBackend.base, ThemeBackend.uiGlossy ? ambient.frostedOpacity : ThemeBackend.uiBackgroundOpacity)
            visible: ambient.active
            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            visible: ambient.active && ThemeBackend.uiGlossy
            radius: ambient.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(ThemeBackend.text, 0.07) }
                GradientStop { position: 0.35; color: Qt.alpha(ThemeBackend.surface0, 0.035) }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha(ThemeBackend.text, 0.025) }
            }
            border.width: 0 // Gloss is a surface highlight, not an outline.
        }

        property real phase: 0
        NumberAnimation on phase {
            from: 0
            to: Math.PI * 2
            duration: 18000
            loops: Animation.Infinite
            running: ambient.active && ambient.animate && ambient.effectiveStrength > 0
        }

        Rectangle {
            width: Math.max(parent.width, parent.height) * 0.62
            height: width
            radius: width / 2
            x: parent.width * 0.70 - width / 2 + Math.sin(effectsLayer.phase) * parent.width * 0.055
            y: parent.height * 0.16 - height / 2 + Math.cos(effectsLayer.phase * 0.8) * parent.height * 0.055
            color: Qt.alpha(ambient.accentColor, Math.min(0.16, 0.060 * ambient.paletteBoost * ambient.effectiveStrength))
            border.width: Math.max(1, width * 0.055)
            border.color: Qt.alpha(ambient.accentColor, Math.min(0.09, 0.030 * ambient.paletteBoost * ambient.effectiveStrength))
        }

        Rectangle {
        width: Math.max(parent.width, parent.height) * 0.48
        height: width
        radius: width / 2
        x: parent.width * 0.18 - width / 2 + Math.cos(effectsLayer.phase * 0.72) * parent.width * 0.045
        y: parent.height * 0.82 - height / 2 + Math.sin(effectsLayer.phase * 0.9) * parent.height * 0.05
        color: Qt.alpha(ambient.secondaryColor, Math.min(0.13, 0.047 * ambient.paletteBoost * ambient.effectiveStrength))
        border.width: Math.max(1, width * 0.07)
        border.color: Qt.alpha(ambient.secondaryColor, Math.min(0.075, 0.024 * ambient.paletteBoost * ambient.effectiveStrength))
        }

        Rectangle {
        width: Math.max(parent.width, parent.height) * 0.32
        height: width
        radius: width / 2
        x: parent.width * 0.48 - width / 2 + Math.sin(effectsLayer.phase * 1.12) * parent.width * 0.035
        y: parent.height * 0.52 - height / 2 + Math.cos(effectsLayer.phase * 0.64) * parent.height * 0.04
        color: "transparent"
        border.width: Math.max(1, width * 0.028)
        border.color: Qt.alpha(ambient.tertiaryColor, Math.min(0.11, 0.036 * ambient.paletteBoost * ambient.effectiveStrength))
        }

        Text {
        visible: ambient.glyph !== ""
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -font.pixelSize * 0.10
        anchors.bottomMargin: -font.pixelSize * 0.24
        text: ambient.glyph
        font.family: "Iosevka Nerd Font"
        font.pixelSize: Math.max(parent.height * 0.62, 140)
        color: Qt.alpha(ambient.accentColor, Math.min(0.12, 0.040 * ambient.paletteBoost * ambient.effectiveStrength))
        rotation: -8 + Math.sin(effectsLayer.phase) * 2
        }
    }
}
