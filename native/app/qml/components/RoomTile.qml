import QtQuick
import QtQuick.Controls
import DouyuNative
import ".."

FocusScope {
    id: root

    implicitWidth: 320
    implicitHeight: 180
    z: menuOpen ? 1000 : 0

    required property string roomId
    required property string anchorName
    required property string title
    required property string category
    required property string viewerLabel
    required property url avatarUrl
    required property string liveState
    required property string playbackState
    required property bool primary
    property bool secondaryPrimary: false
    required property bool favorite
    required property bool audioFocused
    required property string requestedQuality
    required property int requestedQualityRate
    required property string effectiveQuality
    required property bool muted
    required property int volume
    required property bool danmakuEnabled
    required property string danmakuState
    required property string danmakuErrorCode
    required property bool renderEnabled
    required property int index
    required property var availableQualities
    property var controller: null
    property bool isMaximized: false
    signal fullScreenToggleRequested(string roomId)
    property color borderColor: Theme.border
    property color accentColor: Theme.accent
    property color textColor: Theme.text
    property color mutedTextColor: Theme.mutedText
    property bool menuOpen: false
    property bool controlsVisible: true
    property string attachedPlayerRoomId: ""
    readonly property string density: root.width >= 320
                                      ? "comfortable"
                                      : (root.width >= 180 ? "compact" : "dense")
    readonly property bool compact: density === "compact"
    readonly property bool dense: density === "dense"
    readonly property string displayAnchorName: root.anchorName.trim().length > 0 ? root.anchorName : root.roomId
    readonly property string displayTitle: root.title.trim().length > 0 ? root.title : "斗鱼直播间"
    readonly property string displayCategory: root.category.trim().length > 0 ? root.category : "未分类"
    readonly property string displayViewerLabel: root.viewerLabel.trim().length > 0 ? root.viewerLabel : "--"
    readonly property var qualityOptions: root.availableQualities && root.availableQualities.length > 0
                                         ? root.availableQualities
                                         : [{"id": "auto", "label": "自动", "quality": "auto"}]

    function qualityIndex(token, rate) {
        for (var i = 0; i < qualityOptions.length; ++i) {
            const optionRate = Number(qualityOptions[i].rate)
            if (Number.isFinite(optionRate)) {
                if (optionRate === rate) return i
            } else if (qualityOptions[i].quality === token || qualityOptions[i].id === token) {
                return i
            }
        }
        return 0
    }

    function qualityEnum(token) {
        switch (token) {
        case "original": return 1
        case "super": return 2
        case "high": return 3
        case "standard": return 4
        default: return 0
        }
    }

    Timer {
        id: pictureDoubleClickGuard
        interval: Qt.styleHints.mouseDoubleClickInterval
        repeat: false
    }

    Timer {
        id: controlsTimer
        objectName: "roomControlsTimer"
        interval: 2200
        repeat: false
        onTriggered: {
            if (root.menuOpen || qualityBox.popup.visible || roomVolumeSlider.pressed || danmakuTextField.activeFocus) restart()
            else root.controlsVisible = false
        }
    }

    function revealControls() {
        controlsVisible = true
        controlsTimer.restart()
    }

    Component.onCompleted: controlsTimer.start()

    function attachPlayerForCurrentRoom(player) {
        if (!player || !root.controller || root.roomId.trim().length === 0) return
        if (root.attachedPlayerRoomId === root.roomId) return
        if (root.attachedPlayerRoomId.length > 0) {
            root.controller.detachPlayer(root.attachedPlayerRoomId, player)
        }
        root.controller.attachPlayer(root.roomId, player)
        root.attachedPlayerRoomId = root.roomId
    }

    function detachAttachedPlayer(player) {
        if (!player || !root.controller || root.attachedPlayerRoomId.length === 0) return
        root.controller.detachPlayer(root.attachedPlayerRoomId, player)
        root.attachedPlayerRoomId = ""
    }

    function requestRoomRemoval(roomId) {
        const controller = root.controller
        const requestedRoomId = String(roomId || "")
        if (!controller || requestedRoomId.length === 0) return
        controller.requestRemoveRoom(requestedRoomId)
    }

    Rectangle {
        id: roomCardSurface
        objectName: "roomCardSurface"
        property color frameColor: root.primary ? root.accentColor : Theme.borderStrong
        anchors.fill: parent
        radius: Theme.radiusMedium
        color: Theme.well
        border.width: root.primary ? 2 : 1
        border.color: frameColor
        clip: true

        Loader {
            id: playerLoader
            anchors.fill: parent
            active: root.renderEnabled && root.controller !== null
            sourceComponent: Component {
                MpvQuickItem {
                    id: player
                    Component.onCompleted: root.attachPlayerForCurrentRoom(player)
                    Component.onDestruction: root.detachAttachedPlayer(player)
                }
            }
        }

        DanmakuOverlay {
            id: roomDanmakuOverlay
            anchors.fill: parent
            roomId: root.roomId
            controller: root.controller ? root.controller.danmaku : null
            signalController: root.controller ? root.controller.danmaku : null
            enabled: root.danmakuEnabled && root.controller !== null
                     && root.controller.danmaku.globalEnabled
            topInset: topBar.height
            bottomInset: bottomBar.visible ? bottomBar.height : 0
        }

        Rectangle {
            objectName: "danmakuWaitingLabel"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: topBar.height + 7
            width: waitingLabel.width + 14
            height: 21
            radius: Theme.radiusSmall
            z: 4
            visible: root.danmakuState === "waiting"
            color: Qt.rgba(0.92, 0.68, 0.24, 0.16)
            border.color: Qt.rgba(0.92, 0.68, 0.24, 0.56)
            Text {
                id: waitingLabel
                anchors.centerIn: parent
                color: "#e7b95d"
                font.pixelSize: 10
                text: "等待弹幕会话"
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.renderEnabled || root.controller === null
            color: root.index % 3 === 0 ? Theme.controlSurface : root.index % 3 === 1 ? "#29241f" : "#202b2a"
            Text {
                anchors.centerIn: parent
                color: "#657181"
                font.pixelSize: 12
                text: !root.renderEnabled
                      ? "预览模式"
                      : (root.playbackState === "offline" ? "未开播" : "等待播放")
            }
        }

        Rectangle {
            id: topBar
            objectName: "roomTopBar"
            parent: root
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.dense ? 32 : root.compact ? 36 : 42
            z: 100
            color: Qt.rgba(Theme.appBar.r, Theme.appBar.g, Theme.appBar.b, 0.88)
            opacity: root.controlsVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Item {
                id: roomTopMetadata
                objectName: "roomTopMetadata"
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.right: roomTopActions.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: liveStatusBadge
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.dense ? 20 : 23
                    width: statusLabel.width + (root.dense ? 10 : 14)
                    radius: Theme.radiusSmall
                    color: root.liveState === "online"
                           ? Qt.rgba(Theme.online.r, Theme.online.g, Theme.online.b, 0.14)
                           : (root.liveState === "offline"
                              ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.14)
                              : Theme.controlSurface)
                    border.color: root.liveState === "online"
                                  ? Qt.rgba(Theme.online.r, Theme.online.g, Theme.online.b, 0.48)
                                  : (root.liveState === "offline"
                                     ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.48)
                                     : Theme.borderStrong)
                    Text {
                        id: statusLabel
                        objectName: "roomStatusLabel"
                        anchors.centerIn: parent
                        color: root.liveState === "online"
                               ? Theme.online
                               : (root.liveState === "offline" ? Theme.danger : Theme.mutedText)
                        font.bold: true
                        font.pixelSize: root.dense ? 10 : 12
                        text: root.liveState === "online" ? "直播中" : root.liveState === "offline" ? "未开播" : "检查中"
                    }
                }

                Rectangle {
                    id: primaryRoomBadge
                    objectName: "primaryRoomBadge"
                    property string text: root.secondaryPrimary
                        ? "主画面 2"
                        : (root.primary && root.controller && root.controller.workspace
                           && root.controller.workspace.layoutMode === "primary-two"
                           ? "主画面 1" : "主画面")
                    anchors.left: liveStatusBadge.right
                    anchors.leftMargin: visible ? 6 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.primary || root.secondaryPrimary
                    width: visible ? primaryRoomLabel.width + (root.dense ? 10 : 14) : 0
                    height: root.dense ? 20 : 23
                    radius: Theme.radiusSmall
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.52)
                    Text {
                        id: primaryRoomLabel
                        anchors.centerIn: parent
                        color: root.accentColor
                        font.bold: true
                        font.pixelSize: root.dense ? 10 : 12
                        text: primaryRoomBadge.text
                    }
                }

                Text {
                    id: categoryLabel
                    anchors.left: (root.primary || root.secondaryPrimary) ? primaryRoomBadge.right : liveStatusBadge.right
                    anchors.leftMargin: 8
                    anchors.right: viewerLabel.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.compact && !root.dense
                    color: Theme.text
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    text: root.displayCategory
                }
                Text {
                    id: denseAnchorLabel
                    anchors.left: (root.primary || root.secondaryPrimary)
                                  ? primaryRoomBadge.right : liveStatusBadge.right
                    anchors.leftMargin: 6
                    anchors.right: viewerLabel.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.dense
                    width: Math.max(0, parent.width - x - anchors.leftMargin
                                    - anchors.rightMargin)
                    color: Theme.text
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: 11
                    text: root.displayAnchorName
                }
                Text {
                    id: viewerLabel
                    objectName: "roomViewerLabel"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.compact && !root.dense
                    width: 86
                    color: Theme.mutedText
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    text: "热度 " + root.displayViewerLabel
                }
            }

            ToolButton {
                id: roomTopActions
                objectName: "roomTopActions"
                anchors.right: parent.right
                anchors.rightMargin: root.dense ? 4 : 7
                anchors.verticalCenter: parent.verticalCenter
                width: root.dense ? 30 : 34
                height: root.dense ? 24 : 28
                Accessible.name: "更多操作"
                ToolTip.visible: hovered
                ToolTip.text: Accessible.name
                onClicked: { root.menuOpen = !root.menuOpen; root.revealControls() }
                contentItem: Image { anchors.centerIn: parent; width: 16; height: 16; source: Qt.resolvedUrl("../assets/icons/ellipsis.svg") }
                background: Rectangle { radius: Theme.radiusSmall; color: parent.hovered ? Theme.controlSurface : "transparent" }
            }
        }

        Rectangle {
            id: menu
            objectName: "roomControlMenu"
            parent: root
            visible: root.menuOpen
            z: 110
            width: 196
            height: menuColumn.implicitHeight + 16
            anchors.top: topBar.bottom
            anchors.right: parent.right
            anchors.margins: 8
            radius: Theme.radiusMedium
            color: "#141a21"
            border.color: root.borderColor

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 3
                Text { width: parent.width; height: 30; verticalAlignment: Text.AlignVCenter; color: root.mutedTextColor; font.pixelSize: 12; elide: Text.ElideRight; text: root.playbackState === "error" ? "播放状态异常" : "播放状态正常" }
                ToolButton {
                    objectName: "toggleMaximizeRoomAction"
                    width: parent.width; height: 32
                    Accessible.name: root.isMaximized ? "恢复宫格" : "充满窗口"
                    ToolTip.visible: hovered; ToolTip.text: Accessible.name
                    onClicked: { root.menuOpen = false; root.fullScreenToggleRequested(root.roomId) }
                    contentItem: Text { text: root.isMaximized ? "恢复宫格 (双击)" : "充满窗口 (双击)"; color: "#d6dde5"; leftPadding: 8; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                    background: Rectangle { radius: 5; color: parent.hovered ? "#241b17" : "transparent" }
                }
                ToolButton {
                    objectName: "refreshRoomAction"
                    width: parent.width; height: 32
                    Accessible.name: "刷新房间数据"
                    ToolTip.visible: hovered; ToolTip.text: Accessible.name
                    onClicked: { if (root.controller) root.controller.refreshRoom(root.roomId); root.menuOpen = false }
                    contentItem: Text { text: "刷新房间数据"; color: "#d6dde5"; leftPadding: 8; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                    background: Rectangle { radius: 5; color: parent.hovered ? "#241b17" : "transparent" }
                }
                ToolButton {
                    visible: !!(root.controller && root.controller.workspace
                                && root.controller.workspace.layoutMode === "primary-two")
                    width: parent.width; height: 32
                    Accessible.name: root.secondaryPrimary ? "当前主画面 2" : "设为主画面 2"
                    onClicked: { if (root.controller) root.controller.setSecondaryPrimaryRoom(root.roomId); root.menuOpen = false }
                    contentItem: Text { text: root.secondaryPrimary ? "当前主画面 2" : "设为主画面 2"; color: "#d6dde5"; leftPadding: 8; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                    background: Rectangle { radius: 5; color: parent.hovered ? "#241b17" : "transparent" }
                }
                ToolButton {
                    width: parent.width; height: 32
                    Accessible.name: "重新检查播放源"
                    onClicked: { if (root.controller) root.controller.retryPlayback(root.roomId); root.menuOpen = false }
                    contentItem: Text { text: "重新检查播放源"; color: "#d6dde5"; leftPadding: 8; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                    background: Rectangle { radius: 5; color: parent.hovered ? "#241b17" : "transparent" }
                }
                ToolButton {
                    width: parent.width; height: 32
                    Accessible.name: root.primary ? "当前主画面 1" : "设为主画面 1"
                    onClicked: { if (root.controller) root.controller.setPrimaryRoom(root.roomId); root.menuOpen = false }
                    contentItem: Text { text: root.controller && root.controller.workspace && root.controller.workspace.layoutMode === "primary-two" ? (root.primary ? "当前主画面 1" : "设为主画面 1") : (root.primary ? "当前主画面" : "设为主画面"); color: "#d6dde5"; leftPadding: 8; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                    background: Rectangle { radius: 5; color: parent.hovered ? "#241b17" : "transparent" }
                }
                ToolButton {
                    width: parent.width; height: 32
                    Accessible.name: "移除房间"
                    onClicked: { root.menuOpen = false; root.requestRoomRemoval(root.roomId) }
                    contentItem: Text { text: "移除房间"; color: parent.hovered ? "#ff9b92" : "#d6dde5"; leftPadding: 8; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                    background: Rectangle { radius: 5; color: parent.hovered ? "#4b1c1c" : "transparent" }
                }
            }
        }

        Rectangle {
            id: danmakuInputBar
            objectName: "danmakuInputBar"
            parent: root
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (bottomBar.visible ? bottomBar.height : 0) + 6
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            height: root.compact ? 36 : 40
            z: 100
            visible: !root.dense
            opacity: (root.controlsVisible || danmakuTextField.activeFocus || danmakuInputHoverHandler.hovered) ? 1 : 0
            radius: Theme.radiusSmall
            color: Qt.rgba(0.08, 0.11, 0.16, 0.94)
            border.color: danmakuTextField.activeFocus ? Theme.accent : Theme.border
            border.width: 1

            Behavior on opacity { NumberAnimation { duration: 150 } }

            HoverHandler {
                id: danmakuInputHoverHandler
                onHoveredChanged: if (hovered) root.revealControls()
            }

            Row {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 6

                TextField {
                    id: danmakuTextField
                    objectName: "roomDanmakuInput"
                    width: parent.width - sendDanmakuButton.width - parent.spacing
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    placeholderText: (root.controller && root.controller.isLoggedIn) ? "发个弹幕吧~ (按Enter发送)" : "点击登录斗鱼发弹幕"
                    placeholderTextColor: Theme.mutedText
                    color: Theme.text
                    font.pixelSize: root.compact ? 13 : 15
                    leftPadding: 10
                    rightPadding: 10
                    background: Item {}

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            controlsTimer.stop()
                            if (root.controller && !root.controller.isLoggedIn) {
                                root.controller.startQrLogin()
                            }
                        } else {
                            controlsTimer.restart()
                        }
                    }

                    onAccepted: {
                        sendDanmakuButton.triggerSend()
                    }
                }

                ToolButton {
                    id: sendDanmakuButton
                    objectName: "sendDanmakuButton"
                    width: root.compact ? 54 : 60
                    height: parent.height
                    enabled: danmakuTextField.text.trim().length > 0 || (root.controller && !root.controller.isLoggedIn)
                    onClicked: triggerSend()

                    function triggerSend() {
                        if (!root.controller) return
                        if (!root.controller.isLoggedIn) {
                            root.controller.startQrLogin()
                            return
                        }
                        const txt = danmakuTextField.text.trim()
                        if (txt.length === 0) return
                        roomDanmakuOverlay.showLocalDanmaku(txt)
                        danmakuStatusBubble.showMessage("正在发送弹幕...", "info")
                        root.controller.sendDanmaku(root.roomId, txt)
                        danmakuTextField.text = ""
                    }

                    contentItem: Text {
                        text: (root.controller && root.controller.isLoggedIn) ? "发送" : "登录"
                        color: parent.enabled ? ((root.controller && root.controller.isLoggedIn) ? Theme.accent : "#10B981") : Theme.mutedText
                        font.pixelSize: root.compact ? 12 : 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: parent.down ? Theme.well : (parent.hovered ? Theme.controlSurface : "transparent")
                    }
                }
            }
        }

        Rectangle {
            id: danmakuStatusBubble
            objectName: "danmakuStatusBubble"
            parent: root
            anchors.bottom: danmakuInputBar.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: danmakuInputBar.horizontalCenter
            width: Math.min(statusBubbleText.implicitWidth + 24, parent.width - 24)
            height: 26
            radius: 13
            z: 101
            visible: opacity > 0
            opacity: 0
            color: statusType === "error" ? Qt.rgba(0.9, 0.18, 0.18, 0.92) : (statusType === "success" ? Qt.rgba(0.02, 0.65, 0.38, 0.92) : Qt.rgba(0.1, 0.15, 0.22, 0.92))
            border.color: statusType === "error" ? "#ff4d4f" : (statusType === "success" ? "#00f59b" : "#4a515a")
            border.width: 1

            property string statusType: "info"

            Behavior on opacity { NumberAnimation { duration: 180 } }

            Timer {
                id: statusBubbleTimer
                interval: 3000
                onTriggered: danmakuStatusBubble.opacity = 0
            }

            function showMessage(msg, type) {
                statusBubbleText.text = msg
                statusType = type || "info"
                opacity = 1
                statusBubbleTimer.restart()
            }

            Text {
                id: statusBubbleText
                anchors.centerIn: parent
                color: "#ffffff"
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Rectangle {
            id: bottomBar
            objectName: "roomBottomBar"
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.dense ? 26 : root.compact ? 48 : 64
            visible: !root.dense
            color: Qt.rgba(Theme.appBar.r, Theme.appBar.g, Theme.appBar.b, 0.92)
            opacity: root.controlsVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 56
                anchors.right: tileActions.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text { objectName: "roomAnchorName"; width: parent.width; color: root.textColor; elide: Text.ElideRight; font.bold: true; font.pixelSize: root.compact ? 12 : 14; text: root.displayAnchorName }
                Text { objectName: "roomTitleText"; width: parent.width; visible: !root.compact; color: root.mutedTextColor; elide: Text.ElideRight; font.pixelSize: 11; text: root.displayTitle }
                Text { objectName: "roomTitle"; visible: false; text: root.displayTitle }
            }

            Rectangle {
                id: avatarFrame
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: root.compact ? 30 : 38
                height: root.compact ? 30 : 38
                radius: width / 2
                color: root.primary ? "#3a2820" : "#28313a"

                Image {
                    id: roomAvatarImage
                    objectName: "roomAvatarImage"
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.avatarUrl
                    visible: root.avatarUrl.toString().length > 0 && status !== Image.Error
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    clip: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !roomAvatarImage.visible
                    color: root.textColor
                    font.bold: true
                    font.pixelSize: root.compact ? 10 : 12
                    text: root.displayAnchorName.slice(0, 1)
                }
            }

            Row {
                id: tileActions
                objectName: "roomActionBar"
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Slider {
                    id: roomVolumeSlider
                    objectName: "roomVolumeSlider"
                    visible: !root.compact
                    width: 76
                    height: 27
                    from: 0
                    to: 1
                    value: Math.max(0, Math.min(1, root.volume / 100))
                    Accessible.name: "房间音量"
                    ToolTip.visible: hovered
                    ToolTip.text: Accessible.name + " " + Math.round(value * 100) + "%"
                    onMoved: {
                        if (root.controller) root.controller.setVolume(root.roomId, Math.round(value * 100))
                    }
                    handle: Rectangle {
                        objectName: "roomVolumeSliderHandle"
                        implicitWidth: 10
                        implicitHeight: 10
                        x: roomVolumeSlider.leftPadding
                           + roomVolumeSlider.visualPosition
                             * (roomVolumeSlider.availableWidth - width)
                        y: roomVolumeSlider.topPadding
                           + (roomVolumeSlider.availableHeight - height) / 2
                        radius: width / 2
                        color: roomVolumeSlider.pressed ? Theme.accent : Theme.text
                        border.color: Theme.borderStrong
                        border.width: 1
                    }
                }
                ToolButton {
                    objectName: "danmakuRetryAction"
                    width: 32; height: 32
                    Accessible.name: root.primary ? "当前主画面" : "设为主画面"
                    ToolTip.visible: hovered; ToolTip.text: Accessible.name
                    onClicked: if (root.controller) root.controller.setPrimaryRoom(root.roomId)
                    contentItem: Image { anchors.centerIn: parent; width: 18; height: 18; source: Qt.resolvedUrl("../assets/icons/pin.svg"); opacity: root.primary ? 1 : 0.55 }
                    background: Rectangle { radius: 5; border.color: parent.hovered || root.primary ? "#9b572f" : "#4a515a"; color: parent.hovered ? "#2a211c" : "#10151b" }
                }
                ToolButton {
                    width: 32; height: 32
                    Accessible.name: root.controller && root.controller.workspace
                                     && root.controller.workspace.audioMode === "multi"
                                     ? (root.audioFocused ? "静音直播间" : "取消直播间静音")
                                     : (root.audioFocused ? "关闭声音焦点" : "播放声音")
                    ToolTip.visible: hovered; ToolTip.text: Accessible.name
                    onClicked: {
                        if (!root.controller) return
                        if (root.controller.workspace && root.controller.workspace.audioMode === "multi") {
                            root.controller.setRoomMuted(root.roomId, !root.muted)
                        } else {
                            root.controller.setAudioRoom(root.audioFocused ? "" : root.roomId)
                        }
                    }
                    contentItem: Image { anchors.centerIn: parent; width: 18; height: 18; source: Qt.resolvedUrl("../assets/icons/volume-2.svg"); opacity: root.audioFocused ? 1 : 0.62 }
                    background: Rectangle { radius: 5; border.color: parent.hovered || root.audioFocused ? "#9b572f" : "#4a515a"; color: parent.hovered ? "#2a211c" : "#10151b" }
                }
                ToolButton {
                    width: 32; height: 32
                    Accessible.name: root.danmakuState === "failed" || root.danmakuState === "platform-blocked"
                                     ? "重试弹幕连接"
                                     : (root.danmakuState === "waiting"
                                        ? "等待弹幕会话"
                                        : (root.danmakuEnabled ? "隐藏弹幕" : "显示弹幕"))
                    ToolTip.visible: hovered
                    ToolTip.text: root.danmakuErrorCode === "AUTH_REQUIRED"
                                  ? "弹幕连接需要认证，点击重试" : Accessible.name
                    onClicked: {
                        if (!root.controller) return
                        if (root.danmakuState === "failed" || root.danmakuState === "platform-blocked") {
                            root.controller.danmaku.retry(root.roomId)
                        } else if (root.danmakuState === "waiting") {
                            return
                        } else {
                            root.controller.toggleDanmaku(root.roomId)
                        }
                    }
                    contentItem: Item {
                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: Qt.resolvedUrl("../assets/icons/message-circle.svg")
                            opacity: root.danmakuEnabled ? 1 : 0.62
                        }
                        Rectangle {
                            objectName: "danmakuConnectedIndicator"
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width: 7
                            height: 7
                            radius: 3.5
                            visible: root.danmakuState === "connected"
                                     || root.danmakuState === "failed"
                                     || root.danmakuState === "platform-blocked"
                                     || root.danmakuState === "waiting"
                            color: root.danmakuState === "connected"
                                   ? "#55b975"
                                   : (root.danmakuState === "waiting" ? "#e7b95d" : "#e57062")
                            border.color: "#10151b"
                            border.width: 1
                        }
                    }
                    background: Rectangle {
                        radius: 5
                        border.color: parent.hovered || root.danmakuEnabled ? "#9b572f" : "#4a515a"
                        color: parent.hovered ? "#2a211c" : "#10151b"
                    }
                }
                ComboBox {
                    id: qualityBox
                    objectName: "roomQualitySelector"
                    width: Math.max(90, Math.min(130, implicitContentWidth + 38))
                    height: 32
                    model: root.qualityOptions
                    textRole: "label"
                    currentIndex: root.qualityIndex(root.requestedQuality, root.requestedQualityRate)
                    Accessible.name: "清晰度"
                    onActivated: function(optionIndex) {
                        if (!root.controller || optionIndex < 0 || optionIndex >= root.qualityOptions.length) return
                        const option = root.qualityOptions[optionIndex]
                        const optionRate = Number(option.rate)
                        root.controller.setQuality(root.roomId,
                                                   root.qualityEnum(option.quality),
                                                   Number.isFinite(optionRate) ? optionRate : -1)
                    }
                    contentItem: Item {
                        Text {
                            objectName: "roomQualityLabel"
                            anchors.fill: parent
                            leftPadding: 8
                            rightPadding: 8
                            color: "#d7dee5"
                            text: qualityBox.displayText
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                            elide: Text.ElideNone
                        }
                    }
                    popup: Popup {
                        objectName: "roomQualityPopup"
                        onClosed: pictureDoubleClickGuard.restart()
                        y: qualityBox.height + 2
                        width: Math.max(qualityBox.width, Math.min(150, qualityBox.implicitContentWidth + 30))
                        implicitHeight: contentItem.implicitHeight
                        padding: 1
                        background: Rectangle {
                            radius: 5
                            color: "#141a21"
                            border.color: root.borderColor
                        }
                        contentItem: ListView {
                            objectName: "roomQualityPopupList"
                            clip: true
                            implicitHeight: contentHeight
                            model: qualityBox.delegateModel
                            currentIndex: qualityBox.highlightedIndex
                            interactive: false
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }
                        }
                    }
                    delegate: ItemDelegate {
                        id: qualityOptionDelegate
                        required property var model
                        required property int index

                        width: ListView.view.width
                        height: 32
                        contentItem: Item {
                            Text {
                                objectName: "roomQualityOptionLabel"
                                anchors.fill: parent
                                leftPadding: 8
                                rightPadding: 8
                                text: model[qualityBox.textRole] !== undefined
                                      ? model[qualityBox.textRole] : qualityBox.textAt(index)
                                color: qualityOptionDelegate.highlighted ? Theme.text : "#d7dee5"
                                font.pixelSize: 11
                                elide: Text.ElideNone
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        background: Rectangle {
                            radius: 4
                            color: parent.highlighted ? "#2a211c" : "transparent"
                        }
                    }
                    background: Rectangle { radius: 4; border.color: root.borderColor; color: "#10151b" }
                }
            }
        }

    }

    MouseArea {
        objectName: "roomPictureDoubleClickArea"
        anchors.fill: parent
        anchors.topMargin: topBar.height
        anchors.bottomMargin: bottomBar.visible ? (bottomBar.height + (danmakuInputBar.visible ? (danmakuInputBar.height + 6) : 0)) : 0
        enabled: !root.menuOpen && !qualityBox.popup.visible
                 && !pictureDoubleClickGuard.running
        acceptedButtons: Qt.LeftButton
        onDoubleClicked: root.fullScreenToggleRequested(root.roomId)
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) root.revealControls()
            else controlsTimer.restart()
        }
        onPointChanged: if (hovered) root.revealControls()
    }

    onMenuOpenChanged: {
        if (menuOpen) revealControls()
        else {
            controlsTimer.restart()
            pictureDoubleClickGuard.restart()
        }
    }

    onActiveFocusChanged: {
        if (activeFocus) revealControls()
        else if (!menuOpen) controlsTimer.restart()
    }

    onRoomIdChanged: {
        if (playerLoader.item) attachPlayerForCurrentRoom(playerLoader.item)
    }

    Connections {
        target: root.controller
        ignoreUnknownSignals: true

        function onDanmakuSendResult(roomId, success, errorMessage) {
            if (roomId === root.roomId) {
                if (success) {
                    danmakuStatusBubble.showMessage("✓ 弹幕发送成功", "success")
                } else {
                    danmakuStatusBubble.showMessage("✕ " + (errorMessage ? errorMessage : "发送失败"), "error")
                }
            }
        }
    }
}
