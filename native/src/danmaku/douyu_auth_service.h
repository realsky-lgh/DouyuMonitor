#pragma once

#include <QObject>
#include <QString>
#include <QMap>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkCookieJar>
#include <QNetworkCookie>

#include <functional>

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

    bool isLoggedIn() const { return !isSessionExpired_ && session_.isValid(); }
    bool isSessionExpired() const { return isSessionExpired_; }
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
    void validateSession(std::function<void(bool valid)> callback = nullptr);
    void markSessionExpired(const QString &reason = QString());
    void setSessionFilePath(const QString &filePath) { sessionFilePath_ = filePath; }
    QString sessionFilePath() const;

signals:
    void qrStateChanged(DouyuQrLoginState state, const QString &qrUrl, const QString &statusText);
    void loginStateChanged(bool loggedIn);
    void sessionExpired(const QString &reason);
    void userProfileChanged(const QString &uid, const QString &nickname, const QString &avatarUrl);

private slots:
    void onPollTimerTick();
    void onValidationTimerTick();

private:
    void requestGenerateCode();
    void checkQrCodeStatus();
    void fetchLoginCookies(const QString &targetUrl);
    void parseCookies(const QStringList &rawCookies);

    QNetworkAccessManager *nam_ = nullptr;
    bool ownsNam_ = false;
    QTimer *pollTimer_ = nullptr;
    QTimer *validationTimer_ = nullptr;

    DouyuQrLoginState currentState_ = DouyuQrLoginState::Idle;
    QString currentQrUrl_;
    QString currentQrCode_;
    qint64 expireTimestampMs_ = 0;

    DouyuUserSession session_;
    QString sessionFilePath_;
    bool isSessionExpired_ = false;
};
