import QtQuick
import QtQuick.Controls
import ".."

Dialog {
    id: root

    objectName: "douyuLoginDialog"
    property var controller: null

    readonly property int qrState: controller ? controller.qrLoginState : 0
    readonly property string qrUrl: controller ? controller.qrLoginUrl : ""
    readonly property string statusText: controller ? controller.qrLoginStatusText : ""
    readonly property bool isLoggedIn: controller ? controller.isLoggedIn : false

    modal: true
    title: "斗鱼账号登录"
    width: 360
    height: 480
    padding: 16
    anchors.centerIn: parent

    palette.window: Theme.controlSurface
    palette.base: Theme.well
    palette.button: Theme.controlSurface
    palette.buttonText: Theme.text
    palette.text: Theme.text
    palette.windowText: Theme.text
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.text

    background: Rectangle {
        color: Theme.controlSurface
        border.color: Theme.border
        radius: Theme.radiusLarge
    }

    onOpened: {
        if (controller && !controller.isLoggedIn) {
            controller.startQrLogin()
        }
    }

    onClosed: {
        if (controller && !controller.isLoggedIn) {
            controller.cancelQrLogin()
        }
    }

    header: Item {
        implicitHeight: 48
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.text
            font.bold: true
            font.pixelSize: 16
        }
        ToolButton {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.controlHeight
            height: Theme.controlHeight
            onClicked: root.close()
            contentItem: Text {
                anchors.centerIn: parent
                text: "✕"
                color: parent.hovered ? Theme.text : Theme.mutedText
                font.pixelSize: 14
            }
            background: Rectangle {
                radius: Theme.radiusSmall
                color: parent.down ? Theme.well : (parent.hovered ? Theme.well : "transparent")
            }
        }
    }

    contentItem: Column {
        anchors.fill: parent
        spacing: 16
        topPadding: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "请使用 手机斗鱼App 扫描二维码登录"
            color: Theme.mutedText
            font.pixelSize: 13
        }

        // 二维码卡片容器
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 230
            height: 230

            Rectangle {
                anchors.fill: parent
                color: "#FFFFFF"
                radius: Theme.radiusMedium
                border.color: Theme.border
                border.width: 1

                Image {
                    id: qrImage
                    anchors.centerIn: parent
                    width: 210
                    height: 210
                    fillMode: Image.PreserveAspectFit
                    source: root.qrUrl.length > 0 ? ("image://qrcode/" + encodeURIComponent(root.qrUrl)) : ""
                    visible: root.qrState >= 2 && root.qrState <= 4
                    smooth: false
                }

                // 加载中提示
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: root.qrState <= 1

                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: root.qrState <= 1
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "正在生成二维码..."
                        color: "#333333"
                        font.pixelSize: 13
                    }
                }

                // 二维码过期遮罩
                Rectangle {
                    anchors.fill: parent
                    color: "#CC000000"
                    radius: Theme.radiusMedium
                    visible: root.qrState === 5

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "二维码已过期"
                            color: "#FFFFFF"
                            font.bold: true
                            font.pixelSize: 14
                        }

                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "点击刷新"
                            palette.button: Theme.accent
                            palette.buttonText: "#FFFFFF"
                            onClicked: {
                                if (root.controller) root.controller.startQrLogin()
                            }
                        }
                    }
                }

                // 登录成功提示遮罩
                Rectangle {
                    anchors.fill: parent
                    color: "#EEFFFFFF"
                    radius: Theme.radiusMedium
                    visible: root.isLoggedIn || root.qrState === 4

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "✓"
                            color: "#10B981"
                            font.bold: true
                            font.pixelSize: 42
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "登录成功！"
                            color: "#1F2937"
                            font.bold: true
                            font.pixelSize: 16
                        }
                    }

                    Timer {
                        running: root.isLoggedIn && root.visible
                        interval: 1000
                        repeat: false
                        onTriggered: root.close()
                    }
                }
            }
        }

        // 状态文字提示
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.statusText.length > 0 ? root.statusText : (root.qrState === 3 ? "已扫描，请在手机上确认登录" : "打开手机斗鱼扫一扫")
            color: root.qrState === 3 ? Theme.accent : Theme.mutedText
            font.pixelSize: 13
            font.bold: root.qrState === 3
        }

        Item {
            width: parent.width
            height: 10
        }

        // 底部刷新与取消操作
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Button {
                text: "刷新二维码"
                enabled: root.qrState !== 1 && !root.isLoggedIn
                onClicked: {
                    if (root.controller) root.controller.startQrLogin()
                }
                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 34
                    radius: Theme.radiusSmall
                    color: parent.down ? Theme.well : (parent.hovered ? Theme.controlSurface : "transparent")
                    border.color: Theme.border
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 13
                }
            }

            Button {
                text: "关闭"
                onClicked: root.close()
                background: Rectangle {
                    implicitWidth: 80
                    implicitHeight: 34
                    radius: Theme.radiusSmall
                    color: Theme.well
                    border.color: Theme.border
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 13
                }
            }
        }
    }
}
