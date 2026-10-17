#include "danmaku/douyu_danmaku_sender.h"
#include "danmaku/douyu_danmaku_protocol.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

namespace {
constexpr int kConnectTimeoutMs = 7000;
constexpr int kAfterSendWaitMs = 1200;
const QString kDefaultWssUrl = QStringLiteral("wss://wsproxy.douyu.com:6671/");
} // namespace

DouyuDanmakuSender::DouyuDanmakuSender(QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent)
    , nam_(nam)
{
    if (!nam_) {
        nam_ = new QNetworkAccessManager(this);
        ownsNam_ = true;
    }
}

DouyuDanmakuSender::~DouyuDanmakuSender() = default;

void DouyuDanmakuSender::sendDanmaku(const QString &roomId, const QString &content, const DouyuUserSession &session)
{
    if (roomId.trimmed().isEmpty()) {
        emit danmakuSent(roomId, false, QStringLiteral("房间号为空"));
        return;
    }
    if (content.trimmed().isEmpty()) {
        emit danmakuSent(roomId, false, QStringLiteral("弹幕内容不能为空"));
        return;
    }
    if (!session.isValid()) {
        emit danmakuSent(roomId, false, QStringLiteral("未登录，请先使用手机斗鱼扫码登录"));
        return;
    }

    auto task = std::make_shared<PendingTask>();
    task->roomId = roomId.trimmed();
    task->content = content.trimmed();
    task->session = session;

    fetchGatewayAndConnect(task);
}

void DouyuDanmakuSender::fetchGatewayAndConnect(std::shared_ptr<PendingTask> task)
{
    const QString gatewayApi = QStringLiteral("https://www.douyu.com/lapi/live/gateway/web/%1?isH5=1").arg(task->roomId);
    QNetworkRequest request{QUrl(gatewayApi)};
    request.setRawHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
    request.setRawHeader("Referer", QStringLiteral("https://www.douyu.com/%1").arg(task->roomId).toUtf8());

    QNetworkReply *reply = nam_->post(request, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [this, task, reply]() {
        reply->deleteLater();
        QString targetWss = kDefaultWssUrl;

        if (reply->error() == QNetworkReply::NoError) {
            const QByteArray body = reply->readAll();
            const QJsonDocument doc = QJsonDocument::fromJson(body);
            if (doc.isObject()) {
                const QJsonObject data = doc.object().value(QStringLiteral("data")).toObject();
                const QJsonArray wssArray = data.value(QStringLiteral("wss")).toArray();
                if (!wssArray.isEmpty()) {
                    const QJsonObject node = wssArray.at(0).toObject();
                    const QString domain = node.value(QStringLiteral("domain")).toString();
                    const int port = node.value(QStringLiteral("port")).toInt(0);
                    if (!domain.isEmpty() && port > 0) {
                        targetWss = QStringLiteral("wss://%1:%2/").arg(domain).arg(port);
                    }
                }
            }
        }
        connectAndSend(task, targetWss);
    });
}

void DouyuDanmakuSender::connectAndSend(std::shared_ptr<PendingTask> task, const QString &wsUrl)
{
    task->socket = std::make_unique<QWebSocket>();
    task->timeoutTimer = std::make_unique<QTimer>();
    task->timeoutTimer->setSingleShot(true);

    auto *sock = task->socket.get();
    auto *timer = task->timeoutTimer.get();

    connect(timer, &QTimer::timeout, this, [this, task]() {
        if (task->sentChat) {
            // 发送了弹幕且未收到报错，正常判定为成功
            finishTask(task, true, QString());
        } else {
            finishTask(task, false, QStringLiteral("连接弹幕网关超时"));
        }
    });
    timer->start(kConnectTimeoutMs);

    connect(sock, &QWebSocket::connected, this, [this, task, sock, timer]() {
        const qint64 ts = QDateTime::currentSecsSinceEpoch();
        QString did = task->session.cookies.value(QStringLiteral("dy_did"));
        if (did.isEmpty()) {
            did = QStringLiteral("10000000000000000000000000001501");
        }
        const QString secret = QString::number(ts) + QStringLiteral("r5*^5;}2#${XF[h+;'./.Q'1;,-]f'p[") + did;
        const QByteArray vk = QCryptographicHash::hash(secret.toUtf8(), QCryptographicHash::Md5).toHex();

        const QMap<QString, QString> loginFields = {
            {QStringLiteral("type"), QStringLiteral("loginreq")},
            {QStringLiteral("roomid"), task->roomId},
            {QStringLiteral("dfl"), QStringLiteral("sn@AA=107@ASss@AA=1@Ssn@AA=108@ASss@AA=1@Ssn@AA=105@ASss@AA=1@Ssn@AA=110@ASss@AA=1")},
            {QStringLiteral("username"), task->session.username.isEmpty() ? task->session.uid : task->session.username},
            {QStringLiteral("password"), QString()},
            {QStringLiteral("ltkid"), task->session.cookies.value(QStringLiteral("acf_ltkid"))},
            {QStringLiteral("biz"), task->session.cookies.value(QStringLiteral("acf_biz"))},
            {QStringLiteral("stk"), task->session.cookies.value(QStringLiteral("acf_stk"))},
            {QStringLiteral("devid"), did},
            {QStringLiteral("ct"), task->session.cookies.value(QStringLiteral("acf_ct"), QStringLiteral("0"))},
            {QStringLiteral("pt"), QStringLiteral("2")},
            {QStringLiteral("cvr"), QStringLiteral("0")},
            {QStringLiteral("tvr"), QStringLiteral("7")},
            {QStringLiteral("apd"), QString()},
            {QStringLiteral("rt"), QString::number(ts)},
            {QStringLiteral("vk"), QString::fromLatin1(vk)},
            {QStringLiteral("ver"), QStringLiteral("20190610")},
            {QStringLiteral("aver"), QStringLiteral("218101901")},
            {QStringLiteral("dmbt"), QStringLiteral("chrome")},
            {QStringLiteral("dmbv"), QStringLiteral("81")}
        };

        const QString loginMsg = DouyuDanmakuProtocol::serializeStt(loginFields);
        sock->sendBinaryMessage(DouyuDanmakuProtocol::encodeFrame(loginMsg));

        const qint64 cst = QDateTime::currentMSecsSinceEpoch();
        const qint64 tts = cst / 1000;
        const QMap<QString, QString> chatFields = {
            {QStringLiteral("type"), QStringLiteral("chatmessage")},
            {QStringLiteral("content"), task->content},
            {QStringLiteral("admzq"), QStringLiteral("0")},
            {QStringLiteral("cst"), QString::number(cst)},
            {QStringLiteral("tts"), QString::number(tts)},
        };
        const QString chatMsg = DouyuDanmakuProtocol::serializeStt(chatFields);
        sock->sendBinaryMessage(DouyuDanmakuProtocol::encodeFrame(chatMsg));

        task->sentChat = true;
        // 等待稍许时间检查是否有错误帧返回
        timer->start(kAfterSendWaitMs);
    });

    connect(sock, &QWebSocket::binaryMessageReceived, this, [this, task](const QByteArray &message) {
        DouyuDanmakuProtocol::FrameDecoder decoder;
        const auto res = decoder.push(message);
        for (const QString &frame : res.frames) {
            const auto fields = DouyuDanmakuProtocol::parseStt(frame);
            const QString type = fields.value(QStringLiteral("type"));
            if (type == QLatin1String("error")) {
                const QString code = fields.value(QStringLiteral("code"));
                QString msg = QStringLiteral("发送失败（错误码: %1）").arg(code);
                if (code == QLatin1String("51")) {
                    msg = QStringLiteral("您已被房管禁言，暂时无法发言");
                } else if (code == QLatin1String("60")) {
                    msg = QStringLiteral("弹幕包含违禁敏感词，未发出");
                } else if (code == QLatin1String("205") || code == QLatin1String("206")) {
                    msg = QStringLiteral("发言太快，请稍后再试");
                } else if (code == QLatin1String("50")) {
                    msg = QStringLiteral("该房间开启了发言限制（如等级或粉丝牌）");
                } else if (code == QLatin1String("301") || code == QLatin1String("302")) {
                    msg = QStringLiteral("登录凭证已失效，请重新扫码登录");
                }
                finishTask(task, false, msg);
                return;
            } else if (type == QLatin1String("chatmsg")) {
                if (fields.value(QStringLiteral("txt")) == task->content) {
                    finishTask(task, true, QString());
                    return;
                }
            }
        }
    });

    connect(sock, &QWebSocket::errorOccurred, this, [this, task](QAbstractSocket::SocketError) {
        if (!task->sentChat) {
            finishTask(task, false, QStringLiteral("弹幕网关网络连接失败"));
        }
    });

    sock->open(QUrl(wsUrl));
}

void DouyuDanmakuSender::finishTask(std::shared_ptr<PendingTask> task, bool success, const QString &errorMsg)
{
    if (!task || task->finished) {
        return;
    }
    task->finished = true;

    if (task->timeoutTimer) {
        task->timeoutTimer->stop();
    }
    if (task->socket) {
        task->socket->close();
    }
    emit danmakuSent(task->roomId, success, errorMsg);
}
