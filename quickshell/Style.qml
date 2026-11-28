pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Palette
    readonly property color textColor: "#d8d8d8"
    readonly property color darkTextColor: "#000000"
    readonly property color mutedTextColor: "#505050"
    readonly property color errorColor: "#d80000"
    readonly property color backgroundColor: "#000000"
    readonly property color panelFallbackColor: "#181818"
    readonly property color selectionColor: "#000000"
    readonly property color transparentColor: "transparent"
    readonly property color maskOpaqueColor: "#ffffff"

    // Typography
    readonly property string fontFamily: "BIZ UDP明朝"
    readonly property string monoFontFamily: "Courier Prime"
    readonly property string iconFontFamily: "ProFont Nerd Font"
    readonly property int barFontSize: 11
    readonly property int iconFontSize: 13
    readonly property int bodyFontSize: 13
    readonly property int inputFontSize: 15
    readonly property int lockFontSize: 14

    // Textures
    readonly property string imageDirectory: "file://" + Quickshell.env("HOME") + "/.local/share/img/"
    readonly property url panelBackground: imageDirectory + "item_bg.png"
    readonly property url terminalBackground: imageDirectory + "term_bg.png"
    readonly property url wallpaper: imageDirectory + "wallpaper.png"

    // Inset shadows
    readonly property color shadowColor: "#000000"
    readonly property color shadowClearColor: Qt.rgba(0, 0, 0, 0)
    readonly property color shadowEdgeColor: Qt.rgba(0, 0, 0, 0.35)
    readonly property int shadowLayers: 3
    readonly property real shadowStrokeStep: 2
    readonly property real shadowInnerOpacity: 0.10
    readonly property real shadowOuterOpacity: 0.055
    readonly property real shadowDepth: 4

    // Motion
    readonly property int panelAnimationDuration: 280
    readonly property int fastAnimationDuration: 180
    readonly property int lockAnimationDuration: 450
    readonly property int lockEnterDelay: 100
}
