#pragma once

#include <QQuickImageProvider>
#include <QImage>

class QrCodeImageProvider : public QQuickImageProvider {
public:
    QrCodeImageProvider();
    ~QrCodeImageProvider() override = default;

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
