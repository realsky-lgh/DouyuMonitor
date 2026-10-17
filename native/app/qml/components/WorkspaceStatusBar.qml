import QtQuick
import ".."

Rectangle {
    id: root

    objectName: "workspaceStatusBar"
    property int onlineCount: 0
    property int offlineCount: 0
    property int danmakuCount: 0
    property string audioLabel: "无"
    property bool silentChecking: true
    property string statusHint: ""

    height: 32
    radius: Theme.radiusSmall
    color: Theme.controlSurface
    border.color: Theme.border
    clip: true

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 16

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.online
            font.pixelSize: Theme.fontSmall
            text: root.onlineCount + " 直播中"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.mutedText
            font.pixelSize: Theme.fontSmall
            text: root.offlineCount + " 未开播"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.mutedText
            font.pixelSize: Theme.fontSmall
            text: "弹幕 " + root.danmakuCount + " 已连接"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.mutedText
            font.pixelSize: Theme.fontSmall
            text: "声音焦点：" + root.audioLabel
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.mutedText
            font.pixelSize: Theme.fontSmall
            text: root.silentChecking ? "静默检查" : "检查中"
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: root.statusHint.length > 0
        color: Theme.accent
        font.bold: true
        font.pixelSize: Theme.fontSmall
        text: root.statusHint
    }
}
