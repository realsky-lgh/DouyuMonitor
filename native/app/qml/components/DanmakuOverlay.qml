import QtQuick
import "DanmakuLaneScheduler.js" as DanmakuLaneScheduler

Item {
    id: root

    required property string roomId
    property var controller: null
    property var signalController: null
    property var activeItems: []
    property var pendingMessage: ({})
    property int activeItemLimit: 64
    property real topInset: 0
    property real bottomInset: 0

    readonly property var displaySettings: controller && controller.displaySettings
                                         ? controller.displaySettings : ({})
    readonly property int durationMs: Math.max(1, Number(displaySettings.durationSeconds || 8) * 1000)
    readonly property int fontSize: Math.max(1, Number(displaySettings.fontSize || 24))
    readonly property real messageOpacity: Math.max(0, Math.min(1, Number(displaySettings.opacity || 0.9)))
    readonly property string region: displaySettings.region || "full"
    readonly property string density: displaySettings.density || "normal"
    readonly property string fontFamily: displaySettings.fontFamily === "simhei" ? "SimHei" : "Microsoft YaHei"
    readonly property string rendering: displaySettings.rendering || "native"
    readonly property bool showColors: displaySettings.showColors !== false
    readonly property bool showBadges: displaySettings.showBadges !== false
    readonly property bool presentationSuspended: !root.visible
                                                  || !!(controller && controller.presentationSuspended)
    readonly property int launchInterval: density === "massive" ? 80 : density === "reduced" ? 360 : 180
    readonly property real safeTopInset: Math.max(0, topInset)
    readonly property real usableHeight: Math.max(0, height - safeTopInset - Math.max(0, bottomInset))

    clip: true
    z: 1

    TextMetrics {
        id: metrics
        text: root.pendingMessage.text || ""
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.bold: root.rendering === "advanced" || Number(root.pendingMessage.nobleLevel || 0) >= 5
    }

    TextMetrics {
        id: localMetrics
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.bold: true
    }

    TextMetrics {
        id: badgeMetrics
        font.family: root.fontFamily
        font.pixelSize: Math.max(9, Math.round(root.fontSize * 0.52))
        font.bold: true
    }

    TextMetrics {
        id: adminMetrics
        text: "房管"
        font.family: root.fontFamily
        font.pixelSize: Math.max(9, Math.round(root.fontSize * 0.52))
        font.bold: true
    }

    Component {
        id: danmakuLineComponent
        DanmakuLine { }
    }

    Timer {
        id: launchTimer
        interval: root.launchInterval
        repeat: true
        running: root.enabled && !root.presentationSuspended && root.controller !== null
                 && root.width > 0 && root.height > 0
        onTriggered: root.launchNextMessage()
    }

    Connections {
        target: root.signalController || root.controller

        function onMessageAvailable(roomId) {
            if (roomId === root.roomId && root.enabled && !root.presentationSuspended
                    && !launchTimer.running) launchTimer.restart()
        }

        function onDanmakuBlocked(roomId, text) {
            if (roomId === root.roomId || !roomId) {
                root.removeDanmakuByText(text)
            }
        }
    }

    function removeDanmakuByText(text) {
        if (!text) return
        const trimmed = text.trim()
        if (pendingMessage && pendingMessage.text && pendingMessage.text.trim() === trimmed) {
            pendingMessage = ({})
        }
        for (let index = activeItems.length - 1; index >= 0; --index) {
            const item = activeItems[index]
            if (item && item.messageText && item.messageText.trim() === trimmed) {
                root.removeActiveItem(item)
            }
        }
    }

    function handleBlockRequested(text) {
        if (root.controller) {
            root.controller.blockDanmaku(root.roomId, text)
        }
        root.removeDanmakuByText(text)
    }

    function handleCopyRequested(text) {
        if (root.controller) {
            root.controller.copyToClipboard(text)
        }
    }

    function hasPendingMessage() {
        return pendingMessage && pendingMessage.text && pendingMessage.text.length > 0
    }

    function activeDescriptors() {
        const descriptors = []
        for (let index = 0; index < activeItems.length; ++index) {
            const item = activeItems[index]
            if (!item) continue
            descriptors.push({
                laneIndex: item.laneIndex,
                width: item.lineWidth,
                containerWidth: item.containerWidth,
                launchedAt: item.launchedAt,
                durationMs: item.durationMs,
                fontSize: item.fontSize
            })
        }
        return descriptors
    }

    function removeActiveItem(item) {
        if (!item) return
        const index = activeItems.indexOf(item)
        if (index !== -1) {
            activeItems.splice(index, 1)
        }
        item.destroy()
    }

    function clearActiveItems() {
        for (let index = 0; index < activeItems.length; ++index) {
            const item = activeItems[index]
            if (item) item.destroy()
        }
        activeItems = []
        pendingMessage = ({})
    }

    function clearRoom() {
        clearActiveItems()
    }

    function calculateSpeed(containerWidth, durationSeconds) {
        const safeWidth = Math.max(100, Number(containerWidth || 1280))
        const safeDuration = Math.max(1, Number(durationSeconds || 8))
        const userFactor = 8.0 / safeDuration
        // Sub-linear square root scaling relative to 1280px reference width
        const baseSpeed = 160.0 * Math.sqrt(safeWidth / 1280.0)
        // Clamp minimum speed to 120 px/s * factor to eliminate jitter/crawling in small windows
        const minSpeed = 120.0 * userFactor
        return Math.max(minSpeed, baseSpeed * userFactor)
    }

    function calculateDuration(containerWidth, itemWidth, durationSeconds) {
        const speed = calculateSpeed(containerWidth, durationSeconds)
        const totalDistance = Math.max(1, Number(containerWidth || 0)) + Math.max(1, Number(itemWidth || 0))
        return Math.max(1, Math.round((totalDistance / speed) * 1000))
    }

    function launchNextMessage() {
        if (!enabled || presentationSuspended || !controller || width <= 0 || usableHeight <= 0) return
        if (activeItems.length >= activeItemLimit) return

        if (!hasPendingMessage()) pendingMessage = controller.takeNextMessage(roomId)
        if (!hasPendingMessage()) return

        const hasBadge = root.showBadges && (pendingMessage.badgeName && pendingMessage.badgeName.length > 0
                          && Number(pendingMessage.badgeLevel || 0) > 0)
        let badgeExtra = 0
        if (hasBadge) {
            badgeMetrics.text = String(pendingMessage.badgeLevel || "") + " " + pendingMessage.badgeName
            badgeExtra += Math.ceil(badgeMetrics.advanceWidth) + 12 + 6
        }
        if (root.showBadges && pendingMessage.isRoomAdmin) {
            badgeExtra += Math.ceil(adminMetrics.advanceWidth) + 10 + 6
        }

        const isBordered = Number(pendingMessage.nobleLevel || 0) >= 5
        const itemWidth = Math.ceil(metrics.advanceWidth) + badgeExtra + (isBordered ? 16 : 4)
        const itemDuration = calculateDuration(width, itemWidth, displaySettings.durationSeconds)
        const candidate = {
            width: itemWidth,
            containerWidth: width,
            launchedAt: Date.now(),
            durationMs: itemDuration,
            fontSize: fontSize
        }
        const lane = DanmakuLaneScheduler.selectLane(
            DanmakuLaneScheduler.lanes(usableHeight, fontSize, region, density),
            activeDescriptors(), candidate)
        if (lane === null) return

        const line = danmakuLineComponent.createObject(root, {
            messageText: pendingMessage.text,
            textColor: root.showColors ? (pendingMessage.color || "") : "",
            nobleLevel: Number(pendingMessage.nobleLevel || 0),
            badgeName: root.showBadges ? (pendingMessage.badgeName || "") : "",
            badgeLevel: root.showBadges ? Number(pendingMessage.badgeLevel || 0) : 0,
            isRoomAdmin: root.showBadges ? !!pendingMessage.isRoomAdmin : false,
            laneIndex: lane.index,
            laneTop: safeTopInset + lane.top,
            lineWidth: candidate.width,
            containerWidth: candidate.containerWidth,
            durationMs: candidate.durationMs,
            fontSize: candidate.fontSize,
            fontFamily: fontFamily,
            messageOpacity: messageOpacity,
            rendering: rendering,
            launchedAt: candidate.launchedAt
        })
        if (!line) return

        line.finished.connect(function() { root.removeActiveItem(line) })
        line.blockRequested.connect(root.handleBlockRequested)
        line.copyRequested.connect(root.handleCopyRequested)
        activeItems.push(line)
        pendingMessage = ({})
    }

    function showLocalDanmaku(text) {
        if (!text || text.trim().length === 0 || width <= 0 || usableHeight <= 0) return
        const trimmed = text.trim()
        localMetrics.text = trimmed
        const itemWidth = Math.ceil(localMetrics.advanceWidth) + 24
        const itemDuration = calculateDuration(width, itemWidth, displaySettings.durationSeconds)
        const candidate = {
            width: itemWidth,
            containerWidth: width,
            launchedAt: Date.now(),
            durationMs: itemDuration,
            fontSize: fontSize
        }
        const lanes = DanmakuLaneScheduler.lanes(usableHeight, fontSize, region, density)
        let lane = DanmakuLaneScheduler.selectLane(lanes, activeDescriptors(), candidate)
        if (lane === null) {
            lane = lanes.length > 0 ? lanes[0] : { index: 0, top: 0 }
        }

        if (activeItems.length >= activeItemLimit && activeItems.length > 0) {
            root.removeActiveItem(activeItems[0])
        }

        const line = danmakuLineComponent.createObject(root, {
            messageText: trimmed,
            laneIndex: lane.index,
            laneTop: safeTopInset + lane.top,
            lineWidth: candidate.width,
            containerWidth: candidate.containerWidth,
            durationMs: candidate.durationMs,
            fontSize: candidate.fontSize,
            fontFamily: fontFamily,
            messageOpacity: 1.0,
            rendering: rendering,
            launchedAt: candidate.launchedAt,
            isSelf: true
        })
        if (!line) return

        line.finished.connect(function() { root.removeActiveItem(line) })
        line.blockRequested.connect(root.handleBlockRequested)
        line.copyRequested.connect(root.handleCopyRequested)
        activeItems.push(line)
    }

    function relayoutActiveItems() {
        if (activeItems.length === 0) return
        const laneList = DanmakuLaneScheduler.lanes(usableHeight, fontSize, region, density)
        for (let index = 0; index < activeItems.length; ++index) {
            const item = activeItems[index]
            if (!item) continue
            const lane = laneList.length > 0 ? laneList[index % laneList.length] : null
            if (lane === null) continue
            item.laneIndex = lane.index
            item.laneTop = safeTopInset + lane.top
            item.y = item.laneTop
        }
    }

    onHeightChanged: relayoutActiveItems()
    onTopInsetChanged: relayoutActiveItems()
    onBottomInsetChanged: relayoutActiveItems()
    onFontSizeChanged: relayoutActiveItems()
    onRegionChanged: relayoutActiveItems()
    onDensityChanged: relayoutActiveItems()

    onEnabledChanged: {
        if (!enabled) clearRoom()
    }

    onPresentationSuspendedChanged: {
        if (presentationSuspended) {
            launchTimer.stop()
            clearActiveItems()
        } else if (enabled) {
            launchTimer.restart()
        }
    }

    Component.onDestruction: clearActiveItems()
}
