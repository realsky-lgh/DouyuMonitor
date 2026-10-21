import QtQuick

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

    objectName: "danmakuLine"
    width: root.isSelf ? (foreground.implicitWidth + 16) : lineWidth
    height: foreground.implicitHeight + 4
    x: containerWidth
    y: laneTop
    enabled: false
    z: root.isSelf ? 20 : 1

    signal finished()

    Rectangle {
        id: selfBorder
        visible: root.isSelf
        anchors.fill: foreground
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        anchors.topMargin: -2
        anchors.bottomMargin: -2
        radius: 4
        color: Qt.rgba(0.02, 0.1, 0.06, 0.75)
        border.color: "#00f59b"
        border.width: 1.5
    }

    Text {
        id: shadow
        visible: !root.isSelf && root.rendering === "advanced"
        anchors.left: foreground.left
        anchors.leftMargin: 1
        anchors.top: foreground.top
        anchors.topMargin: 1
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
        anchors.left: parent.left
        anchors.leftMargin: root.isSelf ? 6 : 2
        anchors.top: parent.top
        anchors.topMargin: 2
        color: root.isSelf ? "#00ffb0" : "#f5f7fa"
        opacity: root.isSelf ? 1.0 : root.messageOpacity
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.bold: root.isSelf || root.rendering === "advanced"
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.QtRendering
        antialiasing: true
        smooth: true
        style: Text.Outline
        styleColor: root.isSelf ? "#052216" : (root.rendering === "advanced" ? "#090d12" : "#1c2731")
        text: root.messageText
    }

    XAnimator {
        target: root
        from: root.containerWidth
        to: -root.width
        duration: root.durationMs
        easing.type: Easing.Linear
        running: true
        onFinished: root.finished()
    }
}
