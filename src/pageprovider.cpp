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
    QImage img = m_doc->renderPage(page, scale);
    if (size) *size = img.size();
    return img;
}
