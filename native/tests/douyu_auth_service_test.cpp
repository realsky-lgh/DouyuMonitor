#include <QtTest/QtTest>
#include "danmaku/douyu_auth_service.h"
#include "ui/qr_code_image_provider.h"

class DouyuAuthServiceTest final : public QObject {
    Q_OBJECT

private slots:
    void initialStateIsUnauthenticated();
    void cancelResetsToIdle();
    void logoutClearsSession();
    void sessionSaveAndLoadPersistence();
    void qrCodeImageProviderGeneratesValidImage();
};

void DouyuAuthServiceTest::sessionSaveAndLoadPersistence()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    const QString sessionFile = tempDir.filePath(QStringLiteral("test_auth.json"));

    // Write a mock session JSON
    {
        QJsonObject obj;
        obj[QStringLiteral("uid")] = QStringLiteral("12345678");
        obj[QStringLiteral("nickname")] = QStringLiteral("测试用户");
        obj[QStringLiteral("timestamp")] = QDateTime::currentSecsSinceEpoch();
        QJsonObject cookies;
        cookies[QStringLiteral("acf_uid")] = QStringLiteral("12345678");
        cookies[QStringLiteral("acf_auth")] = QStringLiteral("token_abc");
        obj[QStringLiteral("cookies")] = cookies;

        QFile file(sessionFile);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(QJsonDocument(obj).toJson());
        file.close();
    }

    // Load session in DouyuAuthService
    {
        DouyuAuthService auth;
        auth.setSessionFilePath(sessionFile);
        auth.loadSession();
        QVERIFY(auth.isLoggedIn());
        QCOMPARE(auth.uid(), QStringLiteral("12345678"));
        QCOMPARE(auth.nickname(), QStringLiteral("测试用户"));
        QCOMPARE(auth.session().cookies.value(QStringLiteral("acf_auth")), QStringLiteral("token_abc"));

        // Logout should delete the session file
        auth.logout();
        QVERIFY(!auth.isLoggedIn());
        QVERIFY(!QFile::exists(sessionFile));
    }
}

void DouyuAuthServiceTest::initialStateIsUnauthenticated()
{
    DouyuAuthService auth;
    QVERIFY(!auth.isLoggedIn());
    QVERIFY(auth.uid().isEmpty());
    QVERIFY(auth.username().isEmpty());
    QVERIFY(auth.nickname().isEmpty());
    QVERIFY(auth.avatarUrl().isEmpty());
}

void DouyuAuthServiceTest::cancelResetsToIdle()
{
    DouyuAuthService auth;
    auth.startQrLogin();
    auth.cancelQrLogin();
    QVERIFY(!auth.isLoggedIn());
}

void DouyuAuthServiceTest::logoutClearsSession()
{
    DouyuAuthService auth;
    auth.logout();
    QVERIFY(!auth.isLoggedIn());
}

void DouyuAuthServiceTest::qrCodeImageProviderGeneratesValidImage()
{
    QrCodeImageProvider provider;
    QSize size;
    const QImage img = provider.requestImage(QStringLiteral("https%3A%2F%2Fm.douyu.com%2Ftest"), &size, QSize(200, 200));
    QVERIFY(!img.isNull());
    QVERIFY(img.width() > 0);
    QVERIFY(img.height() > 0);
}

QTEST_MAIN(DouyuAuthServiceTest)
#include "douyu_auth_service_test.moc"
