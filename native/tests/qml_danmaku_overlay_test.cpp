#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTimer>
#include <QtTest/QtTest>

#include <memory>

class FakeDanmakuQmlController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap displaySettings READ displaySettings NOTIFY settingsChanged)

public:
    QVariantMap displaySettings() const
    {
        return settings_;
    }

    void enqueue(QVariantMap message)
    {
        messages_.append(std::move(message));
        emit messageAvailable(messages_.last().value(QStringLiteral("roomId")).toString());
    }

    int clearCount() const noexcept
    {
        return clearCount_;
    }

    QString lastClearedRoomId() const
    {
        return lastClearedRoomId_;
    }

    Q_INVOKABLE QVariantMap takeNextMessage(const QString &roomId)
    {
        if (messages_.isEmpty() || messages_.first().value(QStringLiteral("roomId")).toString() != roomId) {
            return {};
        }
        return messages_.takeFirst();
    }

    Q_INVOKABLE QVariantMap statusForRoom(const QString &) const
    {
        return {{QStringLiteral("state"), QStringLiteral("connected")}};
    }

    Q_INVOKABLE void clearRoom(const QString &roomId)
    {
        ++clearCount_;
        lastClearedRoomId_ = roomId;
        messages_.clear();
    }

    Q_INVOKABLE void blockDanmaku(const QString &roomId, const QString &text)
    {
        blockedRooms_.append(roomId);
        blockedTexts_.append(text);
        emit danmakuBlocked(roomId, text);
    }

    Q_INVOKABLE void copyToClipboard(const QString &text)
    {
        copiedText_ = text;
    }

    QString copiedText_;
    QStringList blockedRooms_;
    QStringList blockedTexts_;

signals:
    void messageAvailable(const QString &roomId);
    void danmakuBlocked(const QString &roomId, const QString &text);
    void settingsChanged();

private:
    QVariantMap settings_{{QStringLiteral("durationSeconds"), 5},
                          {QStringLiteral("fontSize"), 20},
                          {QStringLiteral("opacity"), 0.9},
                          {QStringLiteral("region"), QStringLiteral("top")},
                          {QStringLiteral("density"), QStringLiteral("massive")},
                          {QStringLiteral("fontFamily"), QStringLiteral("microsoft-yahei")},
                          {QStringLiteral("rendering"), QStringLiteral("native")}};
    QList<QVariantMap> messages_;
    int clearCount_ = 0;
    QString lastClearedRoomId_;
};

namespace {

QVariantMap message(const QString &id,
                    const QString &text,
                    const QString &color = {},
                    int nobleLevel = 0,
                    const QString &badgeName = {},
                    int badgeLevel = 0,
                    bool isRoomAdmin = false)
{
    return {{QStringLiteral("id"), id},
            {QStringLiteral("roomId"), QStringLiteral("63136")},
            {QStringLiteral("nickname"), QStringLiteral("tester")},
            {QStringLiteral("text"), text},
            {QStringLiteral("color"), color},
            {QStringLiteral("nobleLevel"), nobleLevel},
            {QStringLiteral("badgeName"), badgeName},
            {QStringLiteral("badgeLevel"), badgeLevel},
            {QStringLiteral("isRoomAdmin"), isRoomAdmin}};
}

QQuickItem *createOverlay(QQmlEngine &engine,
                          QQuickWindow &window,
                          FakeDanmakuQmlController &controller)
{
    QQmlComponent component(&engine, QUrl(QStringLiteral("qrc:/qml/components/DanmakuOverlay.qml")));
    if (!component.isReady()) return nullptr;
    QObject *created = component.createWithInitialProperties({
        {QStringLiteral("roomId"), QStringLiteral("63136")},
        {QStringLiteral("enabled"), true},
        {QStringLiteral("controller"), QVariant::fromValue(static_cast<QObject *>(&controller))},
        {QStringLiteral("width"), 320},
        {QStringLiteral("height"), 180},
    });
    auto *overlay = qobject_cast<QQuickItem *>(created);
    if (overlay == nullptr) {
        delete created;
        return nullptr;
    }
    overlay->setParentItem(window.contentItem());
    return overlay;
}

QList<QObject *> activeLines(QQuickItem *overlay)
{
    return overlay->findChildren<QObject *>(QStringLiteral("danmakuLine"));
}

} // namespace

class QmlDanmakuOverlayTest final : public QObject {
    Q_OBJECT

private slots:
    void launchesAQueuedMessageIntoTheConfiguredRegion();
    void doesNotReuseAnUnsafeLane();
    void keepsLaneSpacingSafeForOutlinedText();
    void relayoutsActiveDanmakuWhenContainerHeightChanges();
    void clearsActiveAndQueuedMessagesWhenDisabled();
    void pausesHiddenOverlayWithoutConsumingQueuedMessages();
    void keepsLaunchingDuringContinuousMessageArrival();
    void rendersColoredAndNobleDanmaku();
    void rendersFansAndRoomAdminBadges();
    void blocksAndCopiesDanmakuFromContextMenu();
    void hoverPausesDanmakuAnimation();
};

void QmlDanmakuOverlayTest::pausesHiddenOverlayWithoutConsumingQueuedMessages()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    FakeDanmakuQmlController controller;
    QQuickItem page(window.contentItem());
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay);
    overlay->setParentItem(&page);
    page.setVisible(false);
    QVERIFY(!overlay->isVisible());
    controller.enqueue(message("hidden", "queued while hidden"));
    QTest::qWait(250);
    QCOMPARE(activeLines(overlay.get()).size(), 0);
    QCOMPARE(controller.clearCount(), 0);
    page.setVisible(true);
    QVERIFY(overlay->isVisible());
    QCOMPARE(overlay->property("presentationSuspended").toBool(), false);
    QTRY_COMPARE_WITH_TIMEOUT(activeLines(overlay.get()).size(), 1, 1000);
}

void QmlDanmakuOverlayTest::keepsLaunchingDuringContinuousMessageArrival()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));
    FakeDanmakuQmlController controller;
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay);
    QTimer arrivals;
    int nextId = 0;
    connect(&arrivals, &QTimer::timeout, &controller, [&] {
        controller.enqueue(message(QString::number(++nextId), "continuous"));
    });
    arrivals.start(20);
    QTRY_VERIFY_WITH_TIMEOUT(!activeLines(overlay.get()).isEmpty(), 400);
    QVERIFY(arrivals.isActive());
}

void QmlDanmakuOverlayTest::launchesAQueuedMessageIntoTheConfiguredRegion()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("1"), QStringLiteral("first")));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);

    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() == 1, 1500);
    QObject *line = activeLines(overlay.get()).constFirst();
    QVERIFY(line->property("y").toDouble() >= 0);
    QVERIFY(line->property("y").toDouble() < overlay->height() / 2.0);
}

void QmlDanmakuOverlayTest::doesNotReuseAnUnsafeLane()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("1"), QString(70, QChar('a'))));
    controller.enqueue(message(QStringLiteral("2"), QString(70, QChar('b'))));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);

    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() == 2, 2000);
    const QList<QObject *> lines = activeLines(overlay.get());
    QVERIFY(lines.at(0)->property("y").toDouble() != lines.at(1)->property("y").toDouble());
}

void QmlDanmakuOverlayTest::keepsLaneSpacingSafeForOutlinedText()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("1"), QStringLiteral("first")));
    controller.enqueue(message(QStringLiteral("2"), QStringLiteral("second")));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);
    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() == 2, 2000);

    const QList<QObject *> lines = activeLines(overlay.get());
    const qreal fontSize = lines.constFirst()->property("fontSize").toDouble();
    const qreal firstTop = lines.at(0)->property("y").toDouble();
    const qreal secondTop = lines.at(1)->property("y").toDouble();
    const qreal laneGap = qAbs(secondTop - firstTop);
    const qreal minimumSafeGap = fontSize * 1.6;
    QVERIFY2(laneGap >= minimumSafeGap,
             qPrintable(QStringLiteral("danmaku lane gap %1 is smaller than safe gap %2")
                            .arg(laneGap)
                            .arg(minimumSafeGap)));
}

void QmlDanmakuOverlayTest::relayoutsActiveDanmakuWhenContainerHeightChanges()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("1"), QStringLiteral("first")));
    controller.enqueue(message(QStringLiteral("2"), QStringLiteral("second")));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);
    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() == 2, 2000);

    const QList<QObject *> before = activeLines(overlay.get());
    QVERIFY(before.at(0)->property("laneIndex").toInt()
            != before.at(1)->property("laneIndex").toInt());
    overlay->setHeight(140);
    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() == 2, 2000);
    const QList<QObject *> after = activeLines(overlay.get());
    for (QObject *line : after) {
        QVERIFY(line->property("laneIndex").toInt() >= 0);
        QVERIFY(line->property("y").toDouble() >= 0);
        QVERIFY(line->property("y").toDouble() + line->property("height").toDouble()
                <= overlay->height());
    }
    QVERIFY(after.at(0)->property("laneIndex").toInt()
            != after.at(1)->property("laneIndex").toInt());
}

void QmlDanmakuOverlayTest::clearsActiveAndQueuedMessagesWhenDisabled()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("1"), QStringLiteral("first")));
    controller.enqueue(message(QStringLiteral("2"), QStringLiteral("second")));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);
    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() == 1, 1500);

    overlay->setProperty("enabled", false);
    QTRY_COMPARE_WITH_TIMEOUT(activeLines(overlay.get()).size(), 0, 1000);
    QCOMPARE(controller.clearCount(), 0);
    QCOMPARE(controller.lastClearedRoomId(), QString());
}

void QmlDanmakuOverlayTest::rendersColoredAndNobleDanmaku()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(320, 180);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("m1"), QStringLiteral("red"), QStringLiteral("#fe0302"), 0));
    controller.enqueue(message(QStringLiteral("m2"), QStringLiteral("emperor"), QString(), 6));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);

    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() >= 1, 1500);
    QObject *firstLine = activeLines(overlay.get()).constFirst();
    QCOMPARE(firstLine->property("textColor").toString(), QStringLiteral("#fe0302"));
    QObject *fgText = firstLine->findChild<QObject *>(QStringLiteral("danmakuForegroundText"));
    QVERIFY(fgText != nullptr);
    QCOMPARE(fgText->property("color").value<QColor>().name(), QStringLiteral("#fe0302"));
}

void QmlDanmakuOverlayTest::rendersFansAndRoomAdminBadges()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(400, 200);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("b1"), QStringLiteral("hello fans"), QString(), 0, QStringLiteral("大马猴"), 12, true));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);

    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() >= 1, 1500);
    QObject *line = activeLines(overlay.get()).constFirst();
    QCOMPARE(line->property("badgeName").toString(), QStringLiteral("大马猴"));
    QCOMPARE(line->property("badgeLevel").toInt(), 12);
    QCOMPARE(line->property("isRoomAdmin").toBool(), true);

    QObject *fansBadge = line->findChild<QObject *>(QStringLiteral("danmakuFansBadge"));
    QVERIFY(fansBadge != nullptr);
    QCOMPARE(fansBadge->property("visible").toBool(), true);

    QObject *badgeLevelText = line->findChild<QObject *>(QStringLiteral("danmakuBadgeLevel"));
    QVERIFY(badgeLevelText != nullptr);
    QCOMPARE(badgeLevelText->property("text").toString(), QStringLiteral("12"));

    QObject *badgeNameText = line->findChild<QObject *>(QStringLiteral("danmakuBadgeName"));
    QVERIFY(badgeNameText != nullptr);
    QCOMPARE(badgeNameText->property("text").toString(), QStringLiteral("大马猴"));

    QObject *adminBadge = line->findChild<QObject *>(QStringLiteral("danmakuAdminBadge"));
    QVERIFY(adminBadge != nullptr);
    QCOMPARE(adminBadge->property("visible").toBool(), true);
}

void QmlDanmakuOverlayTest::blocksAndCopiesDanmakuFromContextMenu()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(400, 200);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("m1"), QStringLiteral("屏蔽此弹幕测试")));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);

    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() >= 1, 1500);
    QObject *line = activeLines(overlay.get()).constFirst();

    QObject *menu = line->findChild<QObject *>(QStringLiteral("danmakuContextMenu"));
    QVERIFY(menu != nullptr);

    QObject *copyOption = line->findChild<QObject *>(QStringLiteral("danmakuCopyOption"));
    QVERIFY(copyOption != nullptr);
    QVERIFY(QMetaObject::invokeMethod(copyOption, "triggered"));
    QCOMPARE(controller.copiedText_, QStringLiteral("屏蔽此弹幕测试"));

    QObject *blockOption = line->findChild<QObject *>(QStringLiteral("danmakuBlockOption"));
    QVERIFY(blockOption != nullptr);
    QVERIFY(QMetaObject::invokeMethod(blockOption, "triggered"));
    QCOMPARE(controller.blockedTexts_.contains(QStringLiteral("屏蔽此弹幕测试")), true);

    // After blocking, the line should be removed from active items
    QTRY_COMPARE_WITH_TIMEOUT(activeLines(overlay.get()).size(), 0, 1000);
}

void QmlDanmakuOverlayTest::hoverPausesDanmakuAnimation()
{
    QQmlEngine engine;
    QQuickWindow window;
    window.resize(400, 200);
    window.show();
    QVERIFY(QTest::qWaitForWindowExposed(&window));

    FakeDanmakuQmlController controller;
    controller.enqueue(message(QStringLiteral("m1"), QStringLiteral("测试悬停暂停弹幕")));
    std::unique_ptr<QQuickItem> overlay(createOverlay(engine, window, controller));
    QVERIFY(overlay != nullptr);

    QTRY_VERIFY_WITH_TIMEOUT(activeLines(overlay.get()).size() >= 1, 1500);
    QObject *line = activeLines(overlay.get()).constFirst();

    QObject *moveAnim = line->findChild<QObject *>(QStringLiteral("moveAnimation"));
    QVERIFY(moveAnim != nullptr);
    QCOMPARE(moveAnim->property("running").toBool(), true);
    QCOMPARE(moveAnim->property("paused").toBool(), false);

    // Verify pausing with forcePaused or menu visibility
    line->setProperty("forcePaused", true);
    QCOMPARE(moveAnim->property("paused").toBool(), true);

    line->setProperty("forcePaused", false);
    QCOMPARE(moveAnim->property("paused").toBool(), false);

    // Verify pausing when menu opens
    QObject *menu = line->findChild<QObject *>(QStringLiteral("danmakuContextMenu"));
    QVERIFY(menu != nullptr);
    menu->setProperty("visible", true);
    QCOMPARE(moveAnim->property("paused").toBool(), true);
    menu->setProperty("visible", false);
    QCOMPARE(moveAnim->property("paused").toBool(), false);
}

QTEST_MAIN(QmlDanmakuOverlayTest)

#include "qml_danmaku_overlay_test.moc"
