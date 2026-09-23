#include "pageprovider.h"
#include "pdfdocument.h"
#include <QStringList>

PageProvider::PageProvider(PdfDocument *doc)
    : QQuickImageProvider(QQuickImageProvider::Image), m_doc(doc) {}

QImage PageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    Q_UNUSED(requestedSize);
    QStringList parts = id.split('/');
    if (parts.size() < 2) return QImage();
    int page = parts.at(0).toInt();
    qreal scale = parts.at(1).toInt() / 1000.0;
    if (scale <= 0) scale = 1.0;
    int rotation = (parts.size() > 2) ? parts.at(2).toInt() : 0;
    bool inverted = (parts.size() > 3) ? (parts.at(3).toInt() != 0) : false;
    QImage img = m_doc->renderPage(page, scale, rotation, inverted);
    if (size) *size = img.size();
    return img;
}
