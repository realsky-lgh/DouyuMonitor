import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: root

    required property string messageText
    required property int laneIndex
    required property real laneTop
    required property real lineWidth
    required property real containerWidth
    required property int durationMs
    required property int fontSize
    required property string fontFamily
    required property real messageOpacity
    required property string rendering
    required property double launchedAt
    property bool isSelf: false
    property string textColor: ""
    property int nobleLevel: 0
    property string badgeName: ""
    property int badgeLevel: 0
    property bool isRoomAdmin: false

    readonly property bool hasPill: root.isSelf || root.nobleLevel >= 5
    readonly property color pillBorderColor: root.isSelf ? "#00f59b"
                                           : (root.nobleLevel >= 7 ? "#ff55b0" : "#ffd700")
    readonly property color pillBgColor: root.isSelf ? Qt.rgba(0.02, 0.1, 0.06, 0.75)
                                       : (root.nobleLevel >= 7 ? Qt.rgba(0.25, 0.05, 0.18, 0.8)
                                       : Qt.rgba(0.18, 0.14, 0.02, 0.8))
    readonly property color resolvedTextColor: root.isSelf ? "#00ffb0"
                                             : (root.textColor.length > 0 ? root.textColor
                                             : (root.nobleLevel >= 7 ? "#ffe14d"
                                             : (root.nobleLevel >= 5 ? "#ffd700" : "#f5f7fa")))

    readonly property bool hasBadge: root.badgeName.length > 0 && root.badgeLevel > 0
    readonly property color badgeBorderColor: {
        if (root.badgeLevel >= 21) return "#f04438"
        if (root.badgeLevel >= 16) return "#ff7800"
        if (root.badgeLevel >= 11) return "#a24eed"
        if (root.badgeLevel >= 6)  return "#2395ff"
        return "#50cf91"
    }
    readonly property color badgeBgColor: {
        if (root.badgeLevel >= 21) return Qt.rgba(0.35, 0.08, 0.1, 0.85)
        if (root.badgeLevel >= 16) return Qt.rgba(0.35, 0.16, 0.05, 0.85)
        if (root.badgeLevel >= 11) return Qt.rgba(0.24, 0.1, 0.38, 0.85)
        if (root.badgeLevel >= 6)  return Qt.rgba(0.08, 0.22, 0.38, 0.85)
        return Qt.rgba(0.12, 0.3, 0.18, 0.85)
    }

    objectName: "danmakuLine"
    width: root.hasPill ? (contentRow.implicitWidth + 16) : Math.max(lineWidth, contentRow.implicitWidth)
    height: contentRow.implicitHeight + 4
    x: containerWidth
    y: laneTop
    enabled: true
    z: (lineMouseArea.containsMouse || danmakuMenu.visible) ? 100 : (root.isSelf ? 20 : (root.nobleLevel >= 5 ? 10 : 1))

    signal finished()
    signal blockRequested(string text)
    signal copyRequested(string text)

    Rectangle {
        id: pill
        visible: root.hasPill
        anchors.fill: contentRow
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        anchors.topMargin: -2
        anchors.bottomMargin: -2
        radius: 4
        color: root.pillBgColor
        border.color: root.pillBorderColor
        border.width: 1.5
    }

    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.leftMargin: root.hasPill ? 6 : 2
        anchors.top: parent.top
        anchors.topMargin: 2
        spacing: 6

        Rectangle {
            id: fansBadge
            objectName: "danmakuFansBadge"
            visible: root.hasBadge
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(14, Math.round(root.fontSize * 0.72))
            width: badgeRow.width + 8
            radius: 3
            color: root.badgeBgColor
            border.color: root.badgeBorderColor
            border.width: 1

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 3

                Text {
                    id: badgeLevelText
                    objectName: "danmakuBadgeLevel"
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.badgeLevel > 0 ? String(root.badgeLevel) : ""
                    color: root.badgeBorderColor
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(9, Math.round(root.fontSize * 0.52))
                    font.bold: true
                }

                Text {
                    id: badgeNameText
                    objectName: "danmakuBadgeName"
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.badgeName
                    color: "#ffffff"
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(9, Math.round(root.fontSize * 0.52))
                    font.bold: true
                }
            }
        }

        Rectangle {
            id: adminBadge
            objectName: "danmakuAdminBadge"
            visible: root.isRoomAdmin
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(14, Math.round(root.fontSize * 0.72))
            width: adminText.implicitWidth + 8
            radius: 3
            color: Qt.rgba(0.9, 0.4, 0.1, 0.25)
            border.color: "#f27522"
            border.width: 1

            Text {
                id: adminText
                anchors.centerIn: parent
                text: "房管"
                color: "#f5a623"
                font.family: root.fontFamily
                font.pixelSize: Math.max(9, Math.round(root.fontSize * 0.52))
                font.bold: true
            }
        }

        Item {
            id: textContainer
            anchors.verticalCenter: parent.verticalCenter
            width: foreground.implicitWidth
            height: foreground.implicitHeight

            Text {
                id: shadow
                visible: !root.isSelf && root.rendering === "advanced"
                x: 1
                y: 1
                color: "#070a0d"
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.bold: true
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
                text: root.messageText
            }

            Text {
                id: foreground
                objectName: "danmakuForegroundText"
                color: root.resolvedTextColor
                opacity: root.isSelf ? 1.0 : root.messageOpacity
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.bold: root.isSelf || root.rendering === "advanced" || root.nobleLevel >= 5
                font.hintingPreference: Font.PreferNoHinting
                renderType: Text.QtRendering
                antialiasing: true
                smooth: true
                style: Text.Outline
                styleColor: root.isSelf ? "#052216"
                          : (root.nobleLevel >= 5 ? "#241804"
                          : (root.rendering === "advanced" ? "#090d12" : "#1c2731"))
                text: root.messageText
            }
        }
    }

    Rectangle {
        id: hoverOutline
        anchors.fill: contentRow
        anchors.leftMargin: root.hasPill ? -8 : -4
        anchors.rightMargin: root.hasPill ? -8 : -4
        anchors.topMargin: -3
        anchors.bottomMargin: -3
        radius: 4
        visible: lineMouseArea.containsMouse || danmakuMenu.visible
        color: Qt.rgba(1, 1, 1, 0.1)
        border.color: Qt.rgba(1, 1, 1, 0.4)
        border.width: 1
        z: -1
    }

    MouseArea {
        id: lineMouseArea
        objectName: "danmakuLineMouseArea"
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.RightButton
        cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                danmakuMenu.popup(mouse.x, mouse.y)
            }
        }
    }

    Menu {
        id: danmakuMenu
        objectName: "danmakuContextMenu"
        title: "弹幕选项"

        background: Rectangle {
            implicitWidth: 92
            implicitHeight: 64
            color: typeof Theme !== "undefined" ? Theme.controlSurface : "#1f242c"
            border.color: typeof Theme !== "undefined" ? Theme.border : "#343b45"
            radius: typeof Theme !== "undefined" ? Theme.radiusSmall : 4
        }

        MenuItem {
            objectName: "danmakuBlockOption"
            text: "屏蔽"
            onTriggered: root.blockRequested(root.messageText)
            contentItem: Text {
                text: parent.text
                color: typeof Theme !== "undefined" ? Theme.danger : "#ff4d4f"
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }
            background: Rectangle {
                color: parent.highlighted ? (typeof Theme !== "undefined" ? Theme.well : "#2b313a") : "transparent"
                radius: typeof Theme !== "undefined" ? Theme.radiusSmall : 4
            }
        }

        MenuItem {
            objectName: "danmakuCopyOption"
            text: "复制"
            onTriggered: root.copyRequested(root.messageText)
            contentItem: Text {
                text: parent.text
                color: typeof Theme !== "undefined" ? Theme.text : "#f4f6f8"
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }
            background: Rectangle {
                color: parent.highlighted ? (typeof Theme !== "undefined" ? Theme.well : "#2b313a") : "transparent"
                radius: typeof Theme !== "undefined" ? Theme.radiusSmall : 4
            }
        }
    }

    property bool forcePaused: false

    NumberAnimation {
        id: moveAnimation
        objectName: "moveAnimation"
        target: root
        property: "x"
        from: root.containerWidth
        to: -root.width
        duration: root.durationMs
        easing.type: Easing.Linear
        running: true
        paused: lineMouseArea.containsMouse || danmakuMenu.visible || root.forcePaused
        onFinished: root.finished()
    }
}
