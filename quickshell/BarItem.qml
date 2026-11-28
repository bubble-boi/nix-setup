import QtQuick

Item {
    id: root
    property real sideInset: 20
    property bool parallelSides: false
    property bool reverseSlope: false
    readonly property real effectiveSideInset: Math.min(Math.max(0, sideInset), width / (parallelSides ? 2 : 4))
    property bool flushLeft: false
    property bool flushRight: false
    property url source
    property real backgroundOffsetX: 0

    onBackgroundOffsetXChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onAvailableChanged: if (available) { loadImage(root.source); requestPaint() }
        onImageLoaded: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            const w = width, h = height
            if (w <= 0 || h <= 0) return
            const inset = root.effectiveSideInset
            const topLeft = !root.flushLeft && root.parallelSides && !root.reverseSlope ? inset : 0
            const topRight = !root.flushRight && root.parallelSides && root.reverseSlope ? w - inset : w
            const left = root.flushLeft || (root.parallelSides && !root.reverseSlope) ? 0 : inset
            const right = root.flushRight || (root.parallelSides && root.reverseSlope) ? w : w - inset

            ctx.reset()
            ctx.clearRect(0, 0, w, h)
            ctx.save()
            ctx.beginPath()
            ctx.moveTo(topLeft, 0)
            ctx.lineTo(topRight, 0)
            ctx.lineTo(right, h)
            ctx.lineTo(left, h)
            ctx.closePath()
            ctx.clip()
            ctx.fillStyle = Style.panelFallbackColor
            ctx.fillRect(0, 0, w, h)
            if (isImageLoaded(root.source))
                ctx.drawImage(root.source, -root.backgroundOffsetX, 0)
            // Follow the exposed edges only.
            ctx.beginPath()
            if (!root.flushRight) {
                ctx.moveTo(topRight, 0)
                ctx.lineTo(right, h)
            } else {
                ctx.moveTo(right, h)
            }
            ctx.lineTo(left, h)
            if (!root.flushLeft)
                ctx.lineTo(topLeft, 0)

            ctx.strokeStyle = Style.shadowColor
            ctx.lineJoin = "miter"
            ctx.lineCap = "butt"
            for (let i = Style.shadowLayers; i >= 1; --i) {
                ctx.lineWidth = i * Style.shadowStrokeStep
                ctx.globalAlpha = i === 1 ? Style.shadowInnerOpacity : Style.shadowOuterOpacity
                ctx.stroke()
            }
            ctx.globalAlpha = 1

            const shadowDepth = Math.min(Style.shadowDepth, h)
            const bottomShade = ctx.createLinearGradient(0, h - shadowDepth, 0, h)
            bottomShade.addColorStop(0, Style.shadowClearColor)
            bottomShade.addColorStop(1, Style.shadowEdgeColor)
            ctx.fillStyle = bottomShade
            ctx.fillRect(0, h - shadowDepth, w, shadowDepth)
            ctx.restore()
        }
    }
}
