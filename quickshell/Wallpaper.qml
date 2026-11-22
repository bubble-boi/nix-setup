import QtQuick

Item {
    id: root

    property string sourcePath: ""
    property string currentPath: ""
    property string nextPath: ""
    property real progress: 0

    function imageUrl(path) {
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
    }

    function changeWallpaper(path) {
        if (!path || path === currentPath && !animation.running)
            return

        if (animation.running) {
            animation.stop()
            currentPath = nextPath
            progress = 0
        }

        if (!currentPath) {
            currentPath = path
            return
        }

        nextPath = path
        if (nextImage.status === Image.Ready)
            animation.start()
    }

    onSourcePathChanged: changeWallpaper(sourcePath)

    clip: true

    Image {
        anchors.fill: parent
        y: -root.height * root.progress
        source: root.imageUrl(root.currentPath)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Image {
        id: nextImage
        anchors.fill: parent
        y: root.height * (1 - root.progress)
        source: root.imageUrl(root.nextPath)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: root.nextPath !== ""

        onStatusChanged: {
            if (status === Image.Ready && root.nextPath !== "" && !animation.running)
                animation.start()
            else if (status === Image.Error && root.nextPath !== "")
                console.warn("Could not load wallpaper: " + root.nextPath)
        }
    }

    NumberAnimation {
        id: animation
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 350
        easing.type: Easing.InOutCubic

        onFinished: {
            root.currentPath = root.nextPath
            root.nextPath = ""
            root.progress = 0
        }
    }
}
