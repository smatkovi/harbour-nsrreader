#include "pdfdocument.h"
#include <poppler-qt5.h>
#include <QUrl>
#include <QFileInfo>

PdfDocument::PdfDocument(QObject *parent)
    : QObject(parent), m_doc(0), m_pageCount(0), m_locked(false) {}

PdfDocument::~PdfDocument() { clear(); }

void PdfDocument::clear()
{
    delete m_doc; m_doc = 0;
    m_pageCount = 0; m_locked = false;
    m_textCache.clear();
}

void PdfDocument::setSource(const QString &s)
{
    QString path = s;
    if (path.startsWith("file://")) path = QUrl(path).toLocalFile();
    if (path == m_source) return;
    m_source = path;
    emit sourceChanged();
    load();
}

void PdfDocument::load()
{
    clear();
    if (m_source.isEmpty() || !QFileInfo(m_source).exists()) { emit loadedChanged(); return; }
    m_doc = Poppler::Document::load(m_source);
    if (!m_doc) { emit loadedChanged(); return; }
    if (m_doc->isLocked()) {
        m_locked = true;
        emit loadedChanged();
        return;
    }
    m_doc->setRenderHint(Poppler::Document::Antialiasing, true);
    m_doc->setRenderHint(Poppler::Document::TextAntialiasing, true);
    m_doc->setRenderHint(Poppler::Document::TextHinting, true);
    m_pageCount = m_doc->numPages();
    emit loadedChanged();
}

bool PdfDocument::unlock(const QString &password)
{
    if (!m_doc || !m_locked) return false;
    if (m_doc->unlock(password.toUtf8(), password.toUtf8())) return false; // returns true on FAILURE
    m_locked = false;
    m_doc->setRenderHint(Poppler::Document::Antialiasing, true);
    m_doc->setRenderHint(Poppler::Document::TextAntialiasing, true);
    m_pageCount = m_doc->numPages();
    emit loadedChanged();
    return true;
}

QImage PdfDocument::renderPage(int page, qreal scale, int rotation, bool inverted)
{
    QMutexLocker lock(&m_mutex);
    if (!m_doc || page < 1 || page > m_pageCount) return QImage();
    Poppler::Page *p = m_doc->page(page - 1);
    if (!p) return QImage();
    qreal dpi = 72.0 * scale;
    Poppler::Page::Rotation rot = Poppler::Page::Rotate0;
    if (rotation == 90) rot = Poppler::Page::Rotate90;
    else if (rotation == 180) rot = Poppler::Page::Rotate180;
    else if (rotation == 270) rot = Poppler::Page::Rotate270;
    QImage img = p->renderToImage(dpi, dpi, -1, -1, -1, -1, rot);
    delete p;
    if (inverted && !img.isNull()) img.invertPixels(QImage::InvertRgb);
    return img;
}

QSizeF PdfDocument::pageSizePoints(int page, int rotation)
{
    QMutexLocker lock(&m_mutex);
    if (!m_doc || page < 1 || page > m_pageCount) return QSizeF();
    Poppler::Page *p = m_doc->page(page - 1);
    if (!p) return QSizeF();
    QSizeF s = p->pageSizeF();
    delete p;
    if (rotation == 90 || rotation == 270) return QSizeF(s.height(), s.width());
    return s;
}

QString PdfDocument::textForPage(int page)
{
    QMutexLocker lock(&m_mutex);
    if (!m_doc || page < 1 || page > m_pageCount) return QString();
    if (m_textCache.contains(page)) return m_textCache.value(page);
    Poppler::Page *p = m_doc->page(page - 1);
    if (!p) return QString();
    QString t = p->text(QRectF());
    delete p;
    m_textCache.insert(page, t);
    return t;
}
