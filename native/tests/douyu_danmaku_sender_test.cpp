#include <QtTest/QtTest>
#include <QSignalSpy>
#include "danmaku/douyu_danmaku_sender.h"
#include "danmaku/douyu_danmaku_protocol.h"

class DouyuDanmakuSenderTest final : public QObject {
    Q_OBJECT

private slots:
    void rejectsEmptyRoomId();
    void rejectsEmptyContent();
    void rejectsUnauthenticatedSession();
    void encodesChatMessageFrameCorrectly();
};

void DouyuDanmakuSenderTest::rejectsEmptyRoomId()
{
    DouyuDanmakuSender sender;
    QSignalSpy spy(&sender, &DouyuDanmakuSender::danmakuSent);

    DouyuUserSession session;
    session.uid = QStringLiteral("123456");
    session.cookies[QStringLiteral("acf_uid")] = QStringLiteral("123456");

    sender.sendDanmaku(QString(), QStringLiteral("hello"), session);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(spy.at(0).at(1).toBool(), false);
    QVERIFY(spy.at(0).at(2).toString().contains(QStringLiteral("房间号为空")));
}

void DouyuDanmakuSenderTest::rejectsEmptyContent()
{
    DouyuDanmakuSender sender;
    QSignalSpy spy(&sender, &DouyuDanmakuSender::danmakuSent);

    DouyuUserSession session;
    session.uid = QStringLiteral("123456");
    session.cookies[QStringLiteral("acf_uid")] = QStringLiteral("123456");

    sender.sendDanmaku(QStringLiteral("288016"), QStringLiteral("   "), session);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(spy.at(0).at(1).toBool(), false);
    QVERIFY(spy.at(0).at(2).toString().contains(QStringLiteral("弹幕内容不能为空")));
}

void DouyuDanmakuSenderTest::rejectsUnauthenticatedSession()
{
    DouyuDanmakuSender sender;
    QSignalSpy spy(&sender, &DouyuDanmakuSender::danmakuSent);

    DouyuUserSession session; // invalid session
    sender.sendDanmaku(QStringLiteral("288016"), QStringLiteral("hello"), session);
    QCOMPARE(spy.count(), 1);
    QCOMPARE(spy.at(0).at(1).toBool(), false);
    QVERIFY(spy.at(0).at(2).toString().contains(QStringLiteral("未登录")));
}

void DouyuDanmakuSenderTest::encodesChatMessageFrameCorrectly()
{
    const QMap<QString, QString> fields = {
        {QStringLiteral("type"), QStringLiteral("chatmessage")},
        {QStringLiteral("content"), QStringLiteral("加油/test@123")},
        {QStringLiteral("admzq"), QStringLiteral("0")},
        {QStringLiteral("cst"), QStringLiteral("1600000000000")},
        {QStringLiteral("tts"), QStringLiteral("1600000000")},
    };
    const QString serialized = DouyuDanmakuProtocol::serializeStt(fields);
    QVERIFY(serialized.contains(QStringLiteral("type@=chatmessage/")));
    QVERIFY(serialized.contains(QStringLiteral("content@=加油@Stest@A123/")));

    const QByteArray frame = DouyuDanmakuProtocol::encodeFrame(serialized, 690);
    QVERIFY(frame.size() > 12);
    QCOMPARE(frame.back(), '\0');

    DouyuDanmakuProtocol::FrameDecoder decoder;
    const auto result = decoder.push(frame);
    QCOMPARE(result.error, DouyuDanmakuProtocol::FrameError::None);
    QCOMPARE(result.frames.size(), 1);

    const auto parsed = DouyuDanmakuProtocol::parseStt(result.frames.first());
    QCOMPARE(parsed.value(QStringLiteral("type")), QStringLiteral("chatmessage"));
    QCOMPARE(parsed.value(QStringLiteral("content")), QStringLiteral("加油/test@123"));
}

QTEST_MAIN(DouyuDanmakuSenderTest)
#include "douyu_danmaku_sender_test.moc"
