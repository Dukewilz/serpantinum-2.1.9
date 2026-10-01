import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "../"
import "../../"

Item {
    id: bar
    implicitWidth: 200
    implicitHeight: 32

    property real from: 0.0
    property real to: 100.0
    property real value: 0.0
    property bool playing: false
    property bool active: bar.visible && (!Window.window || Window.window.visible)

    property color waveColor: ThemeBackend.mauve || "#cba6f7"
    Behavior on waveColor { ColorAnimation { duration: 600 } }
    property color primaryColor: waveColor
    Behavior on primaryColor { ColorAnimation { duration: 600 } }
    property color secondaryColor: ThemeBackend.lavender || "#b4befe"
    Behavior on secondaryColor { ColorAnimation { duration: 600 } }
    property color tertiaryColor: ThemeBackend.blue || "#89b4fa"
    Behavior on tertiaryColor { ColorAnimation { duration: 600 } }

    property real trackAlpha: 0.28
    property color handleHoverColor: Qt.lighter(waveColor, 1.15)

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    property real handleSize: height < 30 ? Math.max(8, Math.min(14, height * 0.75)) : bar.s(17)
    property real strokeWidth: height < 30 ? Math.max(2.5, handleSize * 0.35) : bar.s(9)
    property real amplitude: height < 30 ? Math.max(4, height * 0.45) : bar.s(20)
    property int cycleMs: 8000
    property real restingLevel: 0.0

    readonly property real cy: height - handleSize * (height < 30 ? 0.65 : 0.7)
    property real pad: handleSize / 2
    property bool isDragging: mouseArea.pressed
    signal moved(real val)

    property real ampFactor: playing ? 1.0 : restingLevel
    Behavior on ampFactor {
        NumberAnimation { duration: 600; easing.type: Easing.OutQuad }
    }

    readonly property real liveAmp: ampFactor

    property real progressFraction: (to > from) ? Math.max(0.0, Math.min(1.0, (value - from) / (to - from))) : 0.0
    property real shownFraction: progressFraction
    Behavior on shownFraction {
        enabled: !bar.isDragging
        NumberAnimation { duration: 250; easing.type: Easing.Linear }
    }

    readonly property real progressX: pad + shownFraction * (width - 2 * pad)

    property real phase: 0

    property real step: height < 30 ? 2.0 : Math.max(2, bar.s(2.5))
    property real startTaperMin: height < 30 ? 12 : bar.s(24)
    property real startTaperMax: height < 30 ? 32 : bar.s(64)

    property string trackColorStr: ""
    property string fullColorStr: ""
    property var layerColorStrs: []
    property var gridTables: []
    property var cachedGradients: []
    property real cachedGradTop: -9999
    property real cachedGradA: -9999

    property real scaleFactor: height < 30 ? (height / 35) : 1.0
    property var layers: [
        { color: bar.primaryColor, amp: 0.86, alpha: 0.32, taper: bar.s(70) * bar.scaleFactor, comps: [
            { len: bar.s(245) * bar.scaleFactor, mult: 1, off: 1.10, w: 0.65 },
            { len: bar.s(145) * bar.scaleFactor, mult: 2, off: 1.90, w: 0.35 } ] },
        { color: bar.primaryColor, amp: 0.93, alpha: 0.56, taper: bar.s(80) * bar.scaleFactor, comps: [
            { len: bar.s(300) * bar.scaleFactor, mult: 1, off: 0.55, w: 0.65 },
            { len: bar.s(180) * bar.scaleFactor, mult: 2, off: 1.25, w: 0.35 } ] },
        { color: bar.primaryColor, amp: 1.00, alpha: 0.82, taper: bar.s(90) * bar.scaleFactor, comps: [
            { len: bar.s(360) * bar.scaleFactor, mult: 1, off: 0.00, w: 0.68 },
            { len: bar.s(225) * bar.scaleFactor, mult: 2, off: 0.60, w: 0.32 } ] }
    ]

    function rgbaCol(col, a) {
        if (!col) return "rgba(0,0,0," + a + ")";
        return "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + "," + Math.round(col.b * 255) + "," + a + ")";
    }

    function easeQuintic(t) {
        t = Math.max(0, Math.min(1, t));
        return t * t * t * (t * (t * 6 - 15) + 10);
    }

    function updateColors() {
        trackColorStr = rgbaCol(bar.waveColor, bar.trackAlpha);
        fullColorStr = rgbaCol(bar.waveColor, 1.0);
        var arr = [];
        var L = bar.layers;
        if (L) {
            for (var i = 0; i < L.length; i++) {
                var curCol = L[i].color || bar.primaryColor;
                arr.push({
                    c0: rgbaCol(curCol, L[i].alpha * 0.55),
                    c1: rgbaCol(curCol, L[i].alpha)
                });
            }
        }
        layerColorStrs = arr;
        cachedGradients = [];
    }

    function rebuildGridTables() {
        var L = bar.layers;
        if (!L || L.length === 0 || bar.width <= 0) return;
        var maxSteps = Math.ceil(bar.width / bar.step) + 4;
        var tables = [];
        for (var li = 0; li < L.length; li++) {
            var comps = L[li].comps;
            var layerSins = [];
            var layerCoss = [];
            for (var k = 0; k < comps.length; k++) {
                var p = comps[k];
                var kFreq = (2 * Math.PI) / p.len;
                var sins = new Float64Array(maxSteps);
                var coss = new Float64Array(maxSteps);
                for (var i = 0; i < maxSteps; i++) {
                    var x = bar.pad + i * bar.step;
                    var angle = kFreq * x + p.off;
                    sins[i] = Math.sin(angle);
                    coss[i] = Math.cos(angle);
                }
                layerSins.push(sins);
                layerCoss.push(coss);
            }
            tables.push({ sins: layerSins, coss: layerCoss, maxSteps: maxSteps });
        }
        bar.gridTables = tables;
    }

    function hillFromGrid(table, comps, i, cosBetas, sinBetas) {
        var n = 0;
        for (var k = 0; k < comps.length; k++) {
            n += comps[k].w * (table.sins[k][i] * cosBetas[k] - table.coss[k][i] * sinBetas[k]);
        }
        var base = (n + 0.85) / 1.85;
        if (base <= 0) return 0;
        if (base >= 1) base = 1;
        return 0.5 * (1 - Math.cos(base * Math.PI));
    }

    function hillDirect(x, comps, phaseVal) {
        var n = 0;
        for (var k = 0; k < comps.length; k++) {
            var p = comps[k];
            n += p.w * Math.sin((2 * Math.PI / p.len) * x - phaseVal * p.mult + p.off);
        }
        var base = (n + 0.85) / 1.85;
        if (base <= 0) return 0;
        if (base >= 1) base = 1;
        return 0.5 * (1 - Math.cos(base * Math.PI));
    }

    Component.onCompleted: {
        updateColors();
        rebuildGridTables();
    }

    onActiveChanged: {
        if (bar.active) {
            bar.updateColors();
            bar.rebuildGridTables();
            cv.requestPaint();
        }
    }

    onLiveAmpChanged: { if (bar.active) cv.requestPaint(); }
    onWaveColorChanged: { updateColors(); if (bar.active) cv.requestPaint(); }
    onPrimaryColorChanged: { updateColors(); if (bar.active) cv.requestPaint(); }
    onSecondaryColorChanged: { if (bar.active) cv.requestPaint(); }
    onTertiaryColorChanged: { if (bar.active) cv.requestPaint(); }
    onShownFractionChanged: { if (bar.active) cv.requestPaint(); }
    onWidthChanged: { rebuildGridTables(); if (bar.active) cv.requestPaint(); }
    onPadChanged: { rebuildGridTables(); if (bar.active) cv.requestPaint(); }
    onStepChanged: { rebuildGridTables(); if (bar.active) cv.requestPaint(); }
    onLayersChanged: { updateColors(); rebuildGridTables(); if (bar.active) cv.requestPaint(); }

    Timer {
        id: waveTimer
        interval: 16
        repeat: true
        running: bar.active && (bar.playing || bar.ampFactor > 0.001)
        onTriggered: {
            var now = Date.now();
            bar.phase = ((now % bar.cycleMs) / bar.cycleMs) * Math.PI * 2;
            cv.requestPaint();
        }
    }

    Canvas {
        id: cv
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        opacity: (bar.isDragging || mouseArea.containsMouse) ? 1.0 : (bar.playing ? 1.0 : 0.55)
        Behavior on opacity {
            NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
        }

        onPaint: {
            if (!bar.active) return;

            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cy = bar.cy;
            var pad = bar.pad;
            var right = width - pad;
            var endX = Math.max(pad, bar.progressX);
            var strokeW = bar.strokeWidth;
            var top = cy - strokeW / 2;
            var step = bar.step;
            var startTaper = Math.max(bar.startTaperMin, Math.min(bar.startTaperMax, (endX - pad) * 0.6));
            var currentPhase = bar.phase;
            var barAmp = bar.amplitude;
            var currentLiveAmp = bar.liveAmp;
            var L = bar.layers;

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.lineWidth = strokeW;
            ctx.globalAlpha = 1.0;

            ctx.strokeStyle = bar.trackColorStr || bar.rgbaCol(bar.waveColor, bar.trackAlpha);
            ctx.beginPath();
            ctx.moveTo(endX, cy);
            ctx.lineTo(right, cy);
            ctx.stroke();

            if (endX > pad + 1 && L) {
                var tables = bar.gridTables;
                var hasTables = tables && tables.length === L.length;
                var gradients = bar.cachedGradients;
                var colorStrs = bar.layerColorStrs;

                for (var li = 0; li < L.length; li++) {
                    var ly = L[li];
                    var A = barAmp * ly.amp * currentLiveAmp;
                    if (A < 0.3) continue;

                    var endTaperLen = Math.max(1.0, ly.taper * Math.min(1.0, (endX - pad) / (ly.taper * 1.5)));

                    var g = (gradients && gradients[li] && bar.cachedGradTop === top && bar.cachedGradA === A)
                        ? gradients[li]
                        : null;

                    if (!g) {
                        g = ctx.createLinearGradient(0, top - A, 0, top);
                        var colPair = (colorStrs && colorStrs[li]) ? colorStrs[li] : {
                            c0: bar.rgbaCol(ly.color || bar.primaryColor, ly.alpha * 0.55),
                            c1: bar.rgbaCol(ly.color || bar.primaryColor, ly.alpha)
                        };
                        g.addColorStop(0.0, colPair.c0);
                        g.addColorStop(1.0, colPair.c1);
                        if (!gradients) gradients = [];
                        gradients[li] = g;
                    }

                    var comps = ly.comps;
                    var numComps = comps.length;
                    var cosBetas = new Float64Array(numComps);
                    var sinBetas = new Float64Array(numComps);
                    for (var k = 0; k < numComps; k++) {
                        var beta = comps[k].mult * currentPhase;
                        cosBetas[k] = Math.cos(beta);
                        sinBetas[k] = Math.sin(beta);
                    }

                    var table = hasTables ? tables[li] : null;
                    var canUseGrid = table && table.sins && table.sins.length === numComps;

                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.moveTo(pad, cy);

                    var gridIdx = 0;
                    for (var x = pad; x <= endX; x += step, gridIdx++) {
                        var curX = Math.min(x, endX);
                        var env = bar.easeQuintic((curX - pad) / startTaper) * bar.easeQuintic((endX - curX) / endTaperLen);
                        var h = (canUseGrid && curX === x && gridIdx < table.maxSteps)
                            ? bar.hillFromGrid(table, comps, gridIdx, cosBetas, sinBetas)
                            : bar.hillDirect(curX, comps, currentPhase);
                        var yPos = top - h * A * env;
                        ctx.lineTo(curX, yPos);
                        if (curX === endX) break;
                    }
                    ctx.lineTo(endX, top);
                    ctx.lineTo(endX, cy);
                    ctx.closePath();
                    ctx.fill();
                }
                bar.cachedGradTop = top;
                bar.cachedGradA = A;
                bar.cachedGradients = gradients;
            }

            ctx.strokeStyle = bar.fullColorStr || bar.rgbaCol(bar.waveColor, 1.0);
            ctx.beginPath();
            ctx.moveTo(pad, cy);
            ctx.lineTo(endX, cy);
            ctx.stroke();
        }
    }

    Rectangle {
        id: handle
        x: Math.max(0, Math.min(bar.width - width, bar.progressX - width / 2))
        y: bar.cy - height / 2
        width: bar.handleSize
        height: bar.handleSize
        radius: width / 2
        color: bar.isDragging ? bar.handleHoverColor : (mouseArea.containsMouse ? bar.handleHoverColor : bar.waveColor)
        opacity: 1.0
        scale: bar.isDragging ? 1.25 : (mouseArea.containsMouse ? 1.15 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updatePos(mx) {
            var avail = bar.width - 2 * bar.pad;
            if (avail <= 0) return;
            var frac = Math.max(0.0, Math.min(1.0, (mx - bar.pad) / avail));
            var newVal = bar.from + frac * (bar.to - bar.from);
            bar.value = newVal;
            bar.moved(newVal);
        }

        onPressed: mouse => updatePos(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) updatePos(mouse.x);
        }
    }
}
