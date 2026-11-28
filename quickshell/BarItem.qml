import QtQuick

Item {
    id: root
    property real sideInset: 20
    property bool parallelSides: false
    property bool flushLeft: false
    property bool flushRight: false
    property url source

    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onAvailableChanged: if (available) { loadImage(root.source); requestPaint() }
        onImageLoaded: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            const w = width, h = height
            if (w <= 0 || h <= 0) return
            const inset = Math.min(Math.max(0, root.sideInset), w / (root.parallelSides ? 2 : 4))
            const topLeft = !root.flushLeft && root.parallelSides ? inset : 0
            const left = root.flushLeft || root.parallelSides ? 0 : inset
            const right = root.flushRight ? w : w - inset

            ctx.reset()
            ctx.clearRect(0, 0, w, h)
            ctx.save()
            ctx.beginPath()
            ctx.moveTo(topLeft, 0)
            ctx.lineTo(w, 0)
            ctx.lineTo(right, h)
            ctx.lineTo(left, h)
            ctx.closePath()
            ctx.clip()
            ctx.fillStyle = "#181818"
            ctx.fillRect(0, 0, w, h)
            if (isImageLoaded(root.source))
                ctx.drawImage(root.source, 0, 0)
            // Follow the exposed edges only.
            ctx.beginPath()
            if (!root.flushRight) {
                ctx.moveTo(w, 0)
                ctx.lineTo(right, h)
            } else {
                ctx.moveTo(right, h)
            }
            ctx.lineTo(left, h)
            if (!root.flushLeft)
                ctx.lineTo(topLeft, 0)

            ctx.strokeStyle = "#000000"
            ctx.lineJoin = "miter"
            ctx.lineCap = "butt"
            for (let i = 3; i >= 1; --i) {
                ctx.lineWidth = i * 2
                ctx.globalAlpha = i === 1 ? 0.10 : 0.055
                ctx.stroke()
            }
            ctx.globalAlpha = 1

            const shadowDepth = Math.min(4, h)
            const bottomShade = ctx.createLinearGradient(0, h - shadowDepth, 0, h)
            bottomShade.addColorStop(0, "rgba(0,0,0,0)")
            bottomShade.addColorStop(1, "rgba(0,0,0,0.35)")
            ctx.fillStyle = bottomShade
            ctx.fillRect(0, h - shadowDepth, w, shadowDepth)
            ctx.restore()
        }
    }
}
