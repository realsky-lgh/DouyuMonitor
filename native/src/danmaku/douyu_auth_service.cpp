#include "danmaku/douyu_auth_service.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QUrlQuery>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>

namespace {
const QString kGenerateCodeUrl = QStringLiteral("https://passport.douyu.com/scan/generateCode");
const QString kCheckScanUrl = QStringLiteral("https://passport.douyu.com/lapi/passport/qrcode/check");
const QString kReferer = QStringLiteral("https://passport.douyu.com/index/login");
const QString kUserAgent = QStringLiteral("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
constexpr int kPollIntervalMs = 1500;
} // namespace

DouyuAuthService::DouyuAuthService(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , nam_(nam)
{
    if (!nam_) {
        nam_ = new QNetworkAccessManager(this);
        ownsNam_ = true;
    }
    if (!nam_->cookieJar()) {
        nam_->setCookieJar(new QNetworkCookieJar(nam_));
    }
    pollTimer_ = new QTimer(this);
    pollTimer_->setInterval(kPollIntervalMs);
    connect(pollTimer_, &QTimer::timeout, this, &DouyuAuthService::onPollTimerTick);
}

DouyuAuthService::~DouyuAuthService()
{
    if (pollTimer_) {
        pollTimer_->stop();
    }
}

void DouyuAuthService::startQrLogin()
{
    cancelQrLogin();
    currentState_ = DouyuQrLoginState::Generating;
    emit qrStateChanged(currentState_, QString(), QStringLiteral("正在获取二维码..."));
    requestGenerateCode();
}

void DouyuAuthService::cancelQrLogin()
{
    if (pollTimer_->isActive()) {
        pollTimer_->stop();
    }
    currentState_ = DouyuQrLoginState::Idle;
    currentQrUrl_.clear();
    currentQrCode_.clear();
    expireTimestampMs_ = 0;
}

void DouyuAuthService::logout()
{
    cancelQrLogin();
    clearSession();
    session_ = DouyuUserSession{};
    if (nam_ && nam_->cookieJar()) {
        nam_->setCookieJar(new QNetworkCookieJar(nam_));
    }
    emit loginStateChanged(false);
    emit userProfileChanged(QString(), QString(), QString());
}

QString DouyuAuthService::sessionFilePath() const
{
    if (!sessionFilePath_.isEmpty()) {
        return sessionFilePath_;
    }
    const QString dirPath = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    return dirPath + QStringLiteral("/auth_session.json");
}

void DouyuAuthService::saveSession()
{
    if (!session_.isValid()) return;
    const QString filePath = sessionFilePath();
    const QFileInfo fi(filePath);
    QDir().mkpath(fi.absolutePath());

    QJsonObject obj;
    obj[QStringLiteral("uid")] = session_.uid;
    obj[QStringLiteral("username")] = session_.username;
    obj[QStringLiteral("nickname")] = session_.nickname;
    obj[QStringLiteral("avatarUrl")] = session_.avatarUrl;
    obj[QStringLiteral("timestamp")] = QDateTime::currentSecsSinceEpoch();

    QJsonObject cookiesObj;
    for (auto it = session_.cookies.cbegin(); it != session_.cookies.cend(); ++it) {
        cookiesObj[it.key()] = it.value();
    }
    obj[QStringLiteral("cookies")] = cookiesObj;

    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
        file.close();
    }
}

void DouyuAuthService::loadSession()
{
    const QString filePath = sessionFilePath();
    QFile file(filePath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return;
    }

    const QByteArray data = file.readAll();
    file.close();

    const QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    const QJsonObject obj = doc.object();
    const qint64 ts = obj.value(QStringLiteral("timestamp")).toVariant().toLongLong();
    const qint64 now = QDateTime::currentSecsSinceEpoch();

    // 默认保持 30 天免登录
    constexpr qint64 kSessionTtlSecs = 30LL * 24 * 3600;
    if (ts > 0 && (now - ts > kSessionTtlSecs)) {
        clearSession();
        return;
    }

    session_.uid = obj.value(QStringLiteral("uid")).toString();
    session_.username = obj.value(QStringLiteral("username")).toString();
    session_.nickname = obj.value(QStringLiteral("nickname")).toString();
    session_.avatarUrl = obj.value(QStringLiteral("avatarUrl")).toString();

    const QJsonObject cookiesObj = obj.value(QStringLiteral("cookies")).toObject();
    for (auto it = cookiesObj.begin(); it != cookiesObj.end(); ++it) {
        session_.cookies[it.key()] = it.value().toString();
    }

    if (session_.isValid()) {
        if (nam_ && nam_->cookieJar()) {
            QList<QNetworkCookie> cookiesList;
            for (auto it = session_.cookies.cbegin(); it != session_.cookies.cend(); ++it) {
                QNetworkCookie c(it.key().toUtf8(), it.value().toUtf8());
                c.setDomain(QStringLiteral(".douyu.com"));
                c.setPath(QStringLiteral("/"));
                cookiesList.append(c);
            }
            nam_->cookieJar()->setCookiesFromUrl(cookiesList, QUrl(QStringLiteral("https://www.douyu.com")));
            nam_->cookieJar()->setCookiesFromUrl(cookiesList, QUrl(QStringLiteral("https://passport.douyu.com")));
        }

        currentState_ = DouyuQrLoginState::Success;
        emit loginStateChanged(true);
        emit userProfileChanged(session_.uid, session_.nickname, session_.avatarUrl);
    }
}

void DouyuAuthService::clearSession()
{
    const QString filePath = sessionFilePath();
    QFile::remove(filePath);
}

void DouyuAuthService::requestGenerateCode()
{
    QNetworkRequest request{QUrl(kGenerateCodeUrl)};
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    request.setRawHeader("Referer", kReferer.toUtf8());
    request.setRawHeader("User-Agent", kUserAgent.toUtf8());

    const QByteArray postData = "client_id=1";
    QNetworkReply *reply = nam_->post(request, postData);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (currentState_ != DouyuQrLoginState::Generating) return;

        if (reply->error() != QNetworkReply::NoError) {
            currentState_ = DouyuQrLoginState::Failed;
            emit qrStateChanged(currentState_, QString(), QStringLiteral("网络错误，获取二维码失败"));
            return;
        }

        const QByteArray responseData = reply->readAll();
        QJsonParseError parseErr;
        const QJsonDocument doc = QJsonDocument::fromJson(responseData, &parseErr);
        if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
            currentState_ = DouyuQrLoginState::Failed;
            emit qrStateChanged(currentState_, QString(), QStringLiteral("解析二维码数据失败"));
            return;
        }

        const QJsonObject root = doc.object();
        if (root.value(QStringLiteral("error")).toInt(-1) != 0) {
            currentState_ = DouyuQrLoginState::Failed;
            emit qrStateChanged(currentState_, QString(), QStringLiteral("服务器返回错误"));
            return;
        }

        const QJsonObject data = root.value(QStringLiteral("data")).toObject();
        currentQrUrl_ = data.value(QStringLiteral("url")).toString();
        currentQrCode_ = data.value(QStringLiteral("code")).toString();
        const int expireSec = data.value(QStringLiteral("expire")).toInt(300);
        expireTimestampMs_ = QDateTime::currentMSecsSinceEpoch() + expireSec * 1000;

        if (currentQrUrl_.isEmpty() || currentQrCode_.isEmpty()) {
            currentState_ = DouyuQrLoginState::Failed;
            emit qrStateChanged(currentState_, QString(), QStringLiteral("无效的二维码链接"));
            return;
        }

        currentState_ = DouyuQrLoginState::WaitingScan;
        emit qrStateChanged(currentState_, currentQrUrl_, QStringLiteral("请使用斗鱼手机App扫描二维码"));
        pollTimer_->start();
    });
}

void DouyuAuthService::onPollTimerTick()
{
    if (currentState_ != DouyuQrLoginState::WaitingScan &&
        currentState_ != DouyuQrLoginState::ScannedWaitingConfirm) {
        pollTimer_->stop();
        return;
    }

    if (expireTimestampMs_ > 0 && QDateTime::currentMSecsSinceEpoch() > expireTimestampMs_) {
        pollTimer_->stop();
        currentState_ = DouyuQrLoginState::Expired;
        emit qrStateChanged(currentState_, currentQrUrl_, QStringLiteral("二维码已过期，请刷新"));
        return;
    }

    checkQrCodeStatus();
}

void DouyuAuthService::checkQrCodeStatus()
{
    QUrl url(kCheckScanUrl);
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("time"), QString::number(QDateTime::currentMSecsSinceEpoch()));
    query.addQueryItem(QStringLiteral("code"), currentQrCode_);
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setRawHeader("Referer", kReferer.toUtf8());
    request.setRawHeader("User-Agent", kUserAgent.toUtf8());

    QNetworkReply *reply = nam_->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (currentState_ != DouyuQrLoginState::WaitingScan &&
            currentState_ != DouyuQrLoginState::ScannedWaitingConfirm) {
            return;
        }

        if (reply->error() != QNetworkReply::NoError) {
            return;
        }

        const QByteArray responseData = reply->readAll();
        const QJsonDocument doc = QJsonDocument::fromJson(responseData);
        if (!doc.isObject()) return;

        const QJsonObject root = doc.object();
        const int error = root.value(QStringLiteral("error")).toInt(-999);

        if (error == 0) {
            pollTimer_->stop();
            QString loginUrl;
            const QJsonValue dataVal = root.value(QStringLiteral("data"));
            if (dataVal.isObject()) {
                const QJsonObject dataObj = dataVal.toObject();
                loginUrl = dataObj.value(QStringLiteral("url")).toString();
                if (loginUrl.isEmpty()) {
                    loginUrl = dataObj.value(QStringLiteral("login_url")).toString();
                }
                if (dataObj.contains(QStringLiteral("uid"))) {
                    session_.uid = dataObj.value(QStringLiteral("uid")).toVariant().toString();
                }
                if (dataObj.contains(QStringLiteral("nickname"))) {
                    session_.nickname = dataObj.value(QStringLiteral("nickname")).toString();
                }
                if (dataObj.contains(QStringLiteral("avatar"))) {
                    session_.avatarUrl = dataObj.value(QStringLiteral("avatar")).toString();
                }
            } else if (dataVal.isString()) {
                loginUrl = dataVal.toString();
            }

            currentState_ = DouyuQrLoginState::Success;
            emit qrStateChanged(currentState_, currentQrUrl_, QStringLiteral("登录成功，正在同步账号信息..."));

            if (!loginUrl.isEmpty()) {
                fetchLoginCookies(loginUrl);
            } else if (session_.isValid()) {
                emit loginStateChanged(true);
                emit userProfileChanged(session_.uid, session_.nickname, session_.avatarUrl);
            } else {
                currentState_ = DouyuQrLoginState::Failed;
                emit qrStateChanged(currentState_, currentQrUrl_, QStringLiteral("获取登录凭据失败，请重试"));
            }
        } else if (error == -1) {
            if (currentState_ != DouyuQrLoginState::ScannedWaitingConfirm) {
                currentState_ = DouyuQrLoginState::ScannedWaitingConfirm;
                emit qrStateChanged(currentState_, currentQrUrl_, QStringLiteral("已扫描，请在手机斗鱼上确认登录"));
            }
        } else if (error == -3) {
            pollTimer_->stop();
            currentState_ = DouyuQrLoginState::Expired;
            emit qrStateChanged(currentState_, currentQrUrl_, QStringLiteral("二维码已失效，请刷新"));
        } else {
            // error == -2 等待扫描，继续保持
        }
    });
}

void DouyuAuthService::fetchLoginCookies(const QString &targetUrl)
{
    QString fullUrl = targetUrl;
    if (fullUrl.startsWith(QStringLiteral("//"))) {
        fullUrl = QStringLiteral("https:") + fullUrl;
    } else if (fullUrl.startsWith(QStringLiteral("/"))) {
        fullUrl = QStringLiteral("https://passport.douyu.com") + fullUrl;
    }

    const QUrl parsedUrl(fullUrl);
    const QUrlQuery urlQuery(parsedUrl.query());
    if (session_.uid.isEmpty() && urlQuery.hasQueryItem(QStringLiteral("uid"))) {
        session_.uid = urlQuery.queryItemValue(QStringLiteral("uid"));
    }
    if (urlQuery.hasQueryItem(QStringLiteral("code"))) {
        session_.cookies[QStringLiteral("auth_code")] = urlQuery.queryItemValue(QStringLiteral("code"));
    }

    if (!fullUrl.contains(QStringLiteral("callback="))) {
        fullUrl += (fullUrl.contains(QLatin1Char('?')) ? QStringLiteral("&") : QStringLiteral("?"))
                 + QStringLiteral("callback=appClient_json_callback&_=")
                 + QString::number(QDateTime::currentMSecsSinceEpoch());
    }

    QNetworkRequest request{QUrl(fullUrl)};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("Referer", kReferer.toUtf8());
    request.setRawHeader("User-Agent", kUserAgent.toUtf8());

    QNetworkReply *reply = nam_->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        QStringList rawCookies;
        const auto rawHeaderPairs = reply->rawHeaderPairs();
        for (const auto &pair : rawHeaderPairs) {
            if (pair.first.compare("Set-Cookie", Qt::CaseInsensitive) == 0) {
                rawCookies.append(QString::fromUtf8(pair.second));
            }
        }

        if (nam_->cookieJar()) {
            for (const QString &domain : {QStringLiteral("https://www.douyu.com"),
                                          QStringLiteral("https://douyu.com"),
                                          QStringLiteral("https://passport.douyu.com")}) {
                const auto jarCookies = nam_->cookieJar()->cookiesForUrl(QUrl(domain));
                for (const auto &c : jarCookies) {
                    session_.cookies[QString::fromUtf8(c.name())] = QString::fromUtf8(c.value());
                }
            }
        }

        const QByteArray body = reply->readAll().trimmed();
        QByteArray jsonBytes = body;
        if (jsonBytes.startsWith("appClient_json_callback(")) {
            jsonBytes = jsonBytes.mid(24);
            if (jsonBytes.endsWith(')')) {
                jsonBytes.chop(1);
            } else if (jsonBytes.endsWith(");")) {
                jsonBytes.chop(2);
            }
        }
        const QJsonDocument doc = QJsonDocument::fromJson(jsonBytes);
        if (doc.isObject()) {
            const QJsonObject rootObj = doc.object();
            const QJsonObject dataObj = rootObj.value(QStringLiteral("data")).toObject();
            if (session_.uid.isEmpty()) {
                if (dataObj.contains(QStringLiteral("uid"))) {
                    session_.uid = dataObj.value(QStringLiteral("uid")).toVariant().toString();
                } else if (rootObj.contains(QStringLiteral("uid"))) {
                    session_.uid = rootObj.value(QStringLiteral("uid")).toVariant().toString();
                }
            }
            if (dataObj.contains(QStringLiteral("nickname"))) {
                session_.nickname = dataObj.value(QStringLiteral("nickname")).toString();
            } else if (rootObj.contains(QStringLiteral("nickname"))) {
                session_.nickname = rootObj.value(QStringLiteral("nickname")).toString();
            }
            if (dataObj.contains(QStringLiteral("avatar"))) {
                session_.avatarUrl = dataObj.value(QStringLiteral("avatar")).toString();
            }
            if (dataObj.contains(QStringLiteral("token"))) {
                session_.cookies[QStringLiteral("token")] = dataObj.value(QStringLiteral("token")).toString();
            }
        }

        parseCookies(rawCookies);
    });
}

void DouyuAuthService::parseCookies(const QStringList &rawCookies)
{
    for (const QString &raw : rawCookies) {
        const QString firstPart = raw.section(QLatin1Char(';'), 0, 0).trimmed();
        const int eqIdx = firstPart.indexOf(QLatin1Char('='));
        if (eqIdx > 0) {
            const QString key = firstPart.left(eqIdx).trimmed();
            const QString val = firstPart.mid(eqIdx + 1).trimmed();
            session_.cookies[key] = val;
        }
    }

    if (session_.uid.isEmpty() && session_.cookies.contains(QStringLiteral("acf_uid"))) {
        session_.uid = session_.cookies.value(QStringLiteral("acf_uid"));
    }
    if (session_.cookies.contains(QStringLiteral("acf_username"))) {
        session_.username = session_.cookies.value(QStringLiteral("acf_username"));
    }
    if (session_.cookies.contains(QStringLiteral("acf_nickname"))) {
        session_.nickname = QUrl::fromPercentEncoding(session_.cookies.value(QStringLiteral("acf_nickname")).toUtf8());
    } else if (session_.nickname.isEmpty() && !session_.username.isEmpty()) {
        session_.nickname = session_.username;
    } else if (session_.nickname.isEmpty() && !session_.uid.isEmpty()) {
        session_.nickname = QStringLiteral("斗鱼用户 %1").arg(session_.uid);
    }
    if (session_.cookies.contains(QStringLiteral("acf_avatar"))) {
        session_.avatarUrl = QUrl::fromPercentEncoding(session_.cookies.value(QStringLiteral("acf_avatar")).toUtf8());
    }

    if (session_.isValid()) {
        currentState_ = DouyuQrLoginState::Success;
        saveSession();
        emit loginStateChanged(true);
        emit userProfileChanged(session_.uid, session_.nickname, session_.avatarUrl);
    } else {
        currentState_ = DouyuQrLoginState::Failed;
        emit qrStateChanged(currentState_, currentQrUrl_, QStringLiteral("获取登录凭据失败，请重试"));
    }
}
