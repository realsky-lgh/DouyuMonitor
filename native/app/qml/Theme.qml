pragma Singleton
import QtQuick

QtObject {
    readonly property color appBar: "#11151b"
    readonly property color managementSurface: "#1b2028"
    readonly property color canvas: "#171b22"
    readonly property color controlSurface: "#202731"
    readonly property color well: "#12171e"
    readonly property color border: "#303845"
    readonly property color borderStrong: "#344252"
    readonly property color text: "#eef2f7"
    readonly property color mutedText: "#8996a6"
    readonly property color accent: "#f27522"
    readonly property color online: "#50cf91"
    readonly property color warning: "#f0b26c"
    readonly property color danger: "#d78383"
    readonly property int topBarHeight: 56
    readonly property int controlHeight: 36
    readonly property int roomRowHeight: 104
    readonly property int radiusSmall: 7
    readonly property int radiusMedium: 10
    readonly property int radiusLarge: 12
    readonly property int gap: 10

    // Typography scale
    readonly property int fontTiny: 11
    readonly property int fontSmall: 13
    readonly property int fontBody: 14
    readonly property int fontMedium: 16
    readonly property int fontLarge: 18
    readonly property int fontTitle: 22
}
