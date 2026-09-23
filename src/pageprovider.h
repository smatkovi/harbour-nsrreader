#ifndef PAGEPROVIDER_H
#define PAGEPROVIDER_H

#include <QQuickImageProvider>
class PdfDocument;

// image://pdf/<page>/<scaleMilli>   e.g. image://pdf/3/1500  => page 3 at scale 1.5
class PageProvider : public QQuickImageProvider
{
public:
    explicit PageProvider(PdfDocument *doc);
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize);
private:
    PdfDocument *m_doc;
};

#endif
