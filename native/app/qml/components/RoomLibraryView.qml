import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: root

    property var controller: null
    property var libraryRooms: []
    property bool favoritesOnly: false
    property var visibleRooms: []
    property color accentColor: Theme.accent
    property color surfaceColor: Theme.managementSurface
    property color borderColor: Theme.border
    property color textColor: Theme.text
    property color mutedTextColor: Theme.mutedText

    property bool pendingRebuild: false
    readonly property bool isScrolling: historyList.moving || historyList.flicking || historyList.dragging || (vScrollBar && vScrollBar.pressed)
    readonly property bool isInteracting: isScrolling || interactionCooldownTimer.running

    Timer {
        id: interactionCooldownTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (root.pendingRebuild && !root.isScrolling) {
                root.rebuildVisibleRooms()
                root.pendingRebuild = false
            }
        }
    }

    function noteUserInteracting() {
        interactionCooldownTimer.restart()
    }

    function forceRebuild() {
        interactionCooldownTimer.stop()
        root.pendingRebuild = false
        root.rebuildVisibleRooms()
    }

    function openedLabel(timestamp) {
        if (!timestamp || timestamp <= 0) return "未打开"
        return Qt.formatDateTime(new Date(timestamp), "MM-dd hh:mm")
    }

    function rebuildVisibleRooms() {
        const source = root.libraryRooms || []
        const result = []
        for (let index = 0; index < source.length; ++index) {
            const entry = source[index]
            if (root.favoritesOnly ? entry.favorite : entry.lastOpenedAtMs > 0) result.push(entry)
        }
        result.sort(function(left, right) {
            const leftOnline = (left.online || left.active) ? 1 : 0
            const rightOnline = (right.online || right.active) ? 1 : 0
            if (leftOnline !== rightOnline) return rightOnline - leftOnline
            return 0
        })
        root.visibleRooms = result
    }

    onLibraryRoomsChanged: {
        if (root.isInteracting) {
            root.pendingRebuild = true
            return
        }
        rebuildVisibleRooms()
    }
    onFavoritesOnlyChanged: forceRebuild()
    onVisibleChanged: {
        if (visible) {
            forceRebuild()
        } else {
            interactionCooldownTimer.stop()
            pendingRebuild = false
        }
    }
    Component.onCompleted: rebuildVisibleRooms()

    ListView {
        id: historyList
        objectName: "historyList"
        anchors.fill: parent
        clip: true
        model: root.visibleRooms
        spacing: 3
        leftMargin: 8
        rightMargin: 8
        topMargin: 8
        bottomMargin: 8
        ScrollBar.vertical: ScrollBar {
            id: vScrollBar
            policy: ScrollBar.AsNeeded
            onPressedChanged: {
                if (pressed) {
                    root.noteUserInteracting()
                }
            }
        }

        onMovementStarted: root.noteUserInteracting()
        onMovementEnded: root.noteUserInteracting()
        onFlickStarted: root.noteUserInteracting()
        onFlickEnded: root.noteUserInteracting()
        onMovingChanged: if (moving) root.noteUserInteracting()
        onDraggingChanged: if (dragging) root.noteUserInteracting()
        onContentYChanged: if (moving || flicking || dragging || (vScrollBar && vScrollBar.pressed)) root.noteUserInteracting()

        WheelHandler {
            onWheel: (event) => {
                root.noteUserInteracting()
            }
        }

        delegate: Item {
            id: roomRow
            required property var modelData

            readonly property var entry: modelData
            width: historyList.width - historyList.leftMargin - historyList.rightMargin
            height: Theme.roomRowHeight

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: entry.active
                       ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.08)
                       : (historyMouse.containsMouse ? Theme.controlSurface : "transparent")
                border.color: entry.active
                              ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
                              : "transparent"
                border.width: entry.active ? 1 : 0
            }

            Rectangle {
                id: avatar
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                radius: 24
                color: entry.active ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18) : Theme.well

                Image {
                    id: roomAvatarImage
                    objectName: "roomHistoryAvatarImage"
                    anchors.fill: parent
                    anchors.margins: 1
                    source: entry.avatarUrl
                    visible: entry.avatarUrl && entry.avatarUrl.toString().length > 0
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
                    font.pixelSize: 20
                    text: entry.anchorName.length > 0 ? entry.anchorName.slice(0, 1) : entry.roomId.slice(0, 1)
                }
            }

            Column {
                anchors.left: avatar.right
                anchors.leftMargin: 10
                anchors.right: roomActionBar.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    objectName: "libraryRoomTitle"
                    width: parent.width
                    color: root.textColor
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Theme.roomItemTitleSize
                    text: entry.anchorName.length > 0 ? entry.anchorName : entry.roomId
                    ToolTip.visible: truncated && historyMouse.containsMouse
                    ToolTip.text: text
                    ToolTip.delay: 400
                }
                Text {
                    objectName: "libraryRoomSubtitle"
                    width: parent.width
                    color: root.mutedTextColor
                    elide: Text.ElideRight
                    font.pixelSize: Theme.roomItemSubtitleSize
                    text: entry.title.length > 0 ? entry.title : entry.roomId
                    ToolTip.visible: truncated && historyMouse.containsMouse
                    ToolTip.text: text
                    ToolTip.delay: 400
                }
                Row {
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: (entry.active || entry.online) ? Theme.online : Theme.mutedText
                    }
                    Text {
                        color: (entry.active || entry.online) ? Theme.online : root.mutedTextColor
                        font.pixelSize: Theme.roomItemStatusSize
                        text: entry.active ? "当前播放" : (entry.online ? "直播中" : (root.favoritesOnly ? "未开播" : ("未开播 · " + root.openedLabel(entry.lastOpenedAtMs))))
                    }
                }
            }

            Item {
                id: roomActionBar
                objectName: "libraryRoomActionBar"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 5
                width: 27
                height: 27

                ToolButton {
                    objectName: "openHistoryRoomButton"
                    anchors.fill: parent
                    enabled: !entry.active && root.controller !== null
                    Accessible.name: "加入观看"
                    ToolTip.visible: hovered
                    ToolTip.text: Accessible.name
                    onClicked: {
                        root.controller.addRoom(entry.roomId)
                        root.forceRebuild()
                    }
                    contentItem: Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: Qt.resolvedUrl("../assets/icons/plus.svg")
                        opacity: parent.enabled ? 1 : 0.35
                    }
                    background: Rectangle {
                        radius: Theme.radiusSmall
                        color: parent.hovered && parent.enabled ? "#2a211c" : "transparent"
                    }
                }
            }

            Menu {
                id: historyContextMenu
                MenuItem {
                    text: "从历史中删除"
                    enabled: !entry.active && entry.lastOpenedAtMs > 0 && root.controller !== null
                    onTriggered: {
                        if (root.controller) {
                            root.controller.removeHistoryRoom(entry.roomId)
                            root.forceRebuild()
                        }
                    }
                }
            }

            MouseArea {
                id: historyMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton && !root.favoritesOnly) {
                        historyContextMenu.popup()
                    }
                }
                onContainsMouseChanged: {
                    if (containsMouse) {
                        root.noteUserInteracting()
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: historyList.count === 0
            color: root.mutedTextColor
            font.pixelSize: 14
            text: root.favoritesOnly ? "暂无收藏" : "暂无历史记录"
        }
    }
}
