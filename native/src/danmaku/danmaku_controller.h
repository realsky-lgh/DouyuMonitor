#pragma once

#include "danmaku/danmaku_session_manager.h"
#include "danmaku/douyu_auth_service.h"
#include "workspace/native_workspace_types.h"

#include <QObject>
#include <QVariantMap>

class DanmakuController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool globalEnabled READ globalEnabled NOTIFY settingsChanged)
    Q_PROPERTY(QVariantMap displaySettings READ displaySettings NOTIFY settingsChanged)
    Q_PROPERTY(QVariantMap governanceSettings READ governanceSettings NOTIFY settingsChanged)
    Q_PROPERTY(bool presentationSuspended READ presentationSuspended NOTIFY presentationSuspendedChanged)

public:
    explicit DanmakuController(DanmakuClientFactory factory = {}, QObject *parent = nullptr);

    bool globalEnabled() const noexcept;
    QVariantMap displaySettings() const;
    QVariantMap governanceSettings() const;
    const NativeDanmakuConfiguration &configuration() const noexcept;
    bool presentationSuspended() const noexcept;
    void setPresentationSuspended(bool suspended);

    void setConfiguration(const NativeDanmakuConfiguration &configuration);
    void setSessionProvider(std::function<DouyuUserSession()> provider);
    void synchronize(const QVector<DanmakuRoomEligibility> &rooms);
    void stopAll();

    Q_INVOKABLE void setGlobalEnabled(bool enabled);
    Q_INVOKABLE void setDisplaySetting(const QString &key, const QVariant &value);
    Q_INVOKABLE void setGovernanceSetting(const QString &roomId,
                                          const QString &key,
                                          const QVariant &value);
    Q_INVOKABLE void clearRoomGovernanceOverride(const QString &roomId);
    Q_INVOKABLE QVariantMap takeNextMessage(const QString &roomId);
    Q_INVOKABLE QVariantMap statusForRoom(const QString &roomId) const;
    Q_INVOKABLE QVariantMap statsForRoom(const QString &roomId) const;
    Q_INVOKABLE void clearStats(const QString &roomId);
    Q_INVOKABLE void retry(const QString &roomId);
    Q_INVOKABLE void clearRoom(const QString &roomId);
    Q_INVOKABLE void blockDanmaku(const QString &roomId, const QString &text);
    Q_INVOKABLE bool isDanmakuBlocked(const QString &roomId, const QString &text) const;
    Q_INVOKABLE void copyToClipboard(const QString &text);

#ifdef DOUYU_TESTING
    int activeSessionCountForTest() const;
#endif

signals:
    void settingsChanged();
    void roomStateChanged(const QString &roomId);
    void messageAvailable(const QString &roomId);
    void danmakuBlocked(const QString &roomId, const QString &text);
    void presentationSuspendedChanged();

private:
    static DanmakuGovernanceOverride overrideWithSetting(
        DanmakuGovernanceOverride current, const QString &key, const QVariant &value);
    static void applyGovernanceSetting(DanmakuGovernanceSettings &settings,
                                       const QString &key,
                                       const QVariant &value);
    void emitSettingsIfChanged(const NativeDanmakuConfiguration &previous);

    NativeDanmakuConfiguration configuration_;
    std::function<DouyuUserSession()> sessionProvider_;
    DanmakuSessionManager sessions_;
    QHash<QString, QSet<QString>> sessionBlockedTexts_;
    bool presentationSuspended_ = false;
};
