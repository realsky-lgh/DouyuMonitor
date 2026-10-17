#pragma once

#include "danmaku/douyu_auth_service.h"

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QWebSocket>
#include <QTimer>
#include <memory>

class DouyuDanmakuSender : public QObject {
    Q_OBJECT

public:
    explicit DouyuDanmakuSender(QNetworkAccessManager *nam = nullptr, QObject *parent = nullptr);
    ~DouyuDanmakuSender() override;

    void sendDanmaku(const QString &roomId, const QString &content, const DouyuUserSession &session);

signals:
    void danmakuSent(const QString &roomId, bool success, const QString &errorMessage);

private:
    struct PendingTask {
        QString roomId;
        QString content;
        DouyuUserSession session;
        std::unique_ptr<QWebSocket> socket;
        std::unique_ptr<QTimer> timeoutTimer;
        bool sentChat = false;
        bool finished = false;
    };

    void fetchGatewayAndConnect(std::shared_ptr<PendingTask> task);
    void connectAndSend(std::shared_ptr<PendingTask> task, const QString &wsUrl);
    void finishTask(std::shared_ptr<PendingTask> task, bool success, const QString &errorMsg);

    QNetworkAccessManager *nam_ = nullptr;
    bool ownsNam_ = false;
};
