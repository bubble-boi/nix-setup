pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Colors
    readonly property color textColor: "#d8d8d8"
    readonly property color errorColor: "#d80000"
    readonly property color backgroundColor: "#000000"

    // Font
    readonly property string fontFamily: "Outfit"
    readonly property string monoFontFamily: "M Plus 1 Code"

    // Text shadow
    readonly property color shadowColor: "#181818"
    readonly property real shadowBlur: 0.3
    readonly property real shadowX: 0
    readonly property real shadowY: 3

    // Mask
    readonly property color maskOpaque: "#ffd8d8d8"
    readonly property color maskTransparent: "#00d8d8d8"

    // Wallpaper gallery
    readonly property color galleryBackgroundColor: "#181818"
    readonly property color galleryTileColor: "#282828"
    readonly property color galleryBorderColor: "#484848"
    readonly property color galleryMutedColor: "#999999"
}
