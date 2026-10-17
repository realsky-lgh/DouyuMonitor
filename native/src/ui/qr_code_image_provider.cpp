#include "ui/qr_code_image_provider.h"
#include "util/qrcodegen.hpp"

#include <QUrl>
#include <QPainter>
#include <algorithm>

QrCodeImageProvider::QrCodeImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage QrCodeImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QString content = QUrl::fromPercentEncoding(id.toUtf8());
    if (content.trimmed().isEmpty()) {
        QImage fallback(200, 200, QImage::Format_ARGB32);
        fallback.fill(Qt::white);
        if (size) *size = fallback.size();
        return fallback;
    }

    try {
        const qrcodegen::QrCode qr = qrcodegen::QrCode::encodeText(
            content.toUtf8().constData(),
            qrcodegen::QrCode::Ecc::MEDIUM
        );
        const int qrSize = qr.getSize();
        const int border = 2;
        const int fullModules = qrSize + border * 2;

        int targetDimension = 240;
        if (requestedSize.width() > 0 && requestedSize.height() > 0) {
            targetDimension = std::min(requestedSize.width(), requestedSize.height());
        }
        targetDimension = std::max(targetDimension, fullModules);

        const int scale = std::max(1, targetDimension / fullModules);
        const int finalSize = fullModules * scale;

        QImage image(finalSize, finalSize, QImage::Format_ARGB32);
        image.fill(Qt::white);

        QPainter painter(&image);
        painter.setPen(Qt::NoPen);
        painter.setBrush(Qt::black);

        for (int y = 0; y < qrSize; ++y) {
            for (int x = 0; x < qrSize; ++x) {
                if (qr.getModule(x, y)) {
                    painter.drawRect((x + border) * scale, (y + border) * scale, scale, scale);
                }
            }
        }
        painter.end();

        if (size) *size = image.size();
        return image;
    } catch (...) {
        QImage errorImg(200, 200, QImage::Format_ARGB32);
        errorImg.fill(Qt::white);
        if (size) *size = errorImg.size();
        return errorImg;
    }
}
