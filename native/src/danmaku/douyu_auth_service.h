#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkCookieJar>
#include <QNetworkCookie>

enum class DouyuQrLoginState {
    Idle,
    Generating,
    WaitingScan,
    ScannedWaitingConfirm,
    Success,
    Expired,
    Failed,
};

struct DouyuUserSession {
    QString uid;
    QString username;
    QString nickname;
    QString avatarUrl;
    QMap<QString, QString> cookies;
    bool isValid() const {
        return !uid.isEmpty() || (!cookies.isEmpty() && (cookies.contains(QStringLiteral("acf_uid")) || cookies.contains(QStringLiteral("acf_auth"))));
    }
};

class DouyuAuthService : public QObject {
    Q_OBJECT

public:
    explicit DouyuAuthService(QNetworkAccessManager *nam = nullptr, QObject *parent = nullptr);
    ~DouyuAuthService() override;

    bool isLoggedIn() const { return session_.isValid(); }
    const DouyuUserSession &session() const { return session_; }

    QString uid() const { return session_.uid; }
    QString username() const { return session_.username; }
    QString nickname() const { return session_.nickname; }
    QString avatarUrl() const { return session_.avatarUrl; }

    void startQrLogin();
    void cancelQrLogin();
    void logout();

    void loadSession();
    void saveSession();
    void clearSession();
    void setSessionFilePath(const QString &filePath) { sessionFilePath_ = filePath; }
    QString sessionFilePath() const;

signals:
    void qrStateChanged(DouyuQrLoginState state, const QString &qrUrl, const QString &statusText);
    void loginStateChanged(bool loggedIn);
    void userProfileChanged(const QString &uid, const QString &nickname, const QString &avatarUrl);

private slots:
    void onPollTimerTick();

private:
    void requestGenerateCode();
    void checkQrCodeStatus();
    void fetchLoginCookies(const QString &targetUrl);
    void parseCookies(const QStringList &rawCookies);

    QNetworkAccessManager *nam_ = nullptr;
    bool ownsNam_ = false;
    QTimer *pollTimer_ = nullptr;

    DouyuQrLoginState currentState_ = DouyuQrLoginState::Idle;
    QString currentQrUrl_;
    QString currentQrCode_;
    qint64 expireTimestampMs_ = 0;

    DouyuUserSession session_;
    QString sessionFilePath_;
};
