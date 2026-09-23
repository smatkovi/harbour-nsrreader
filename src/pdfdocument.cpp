#include "pdfdocument.h"
#include <poppler-qt5.h>
#include <QUrl>
#include <QFileInfo>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QStandardPaths>

static void renderLog(const QString &line)
{
    static QString path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                          + "/harbour-nsrreader/render.log";
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) return;
    QTextStream ts(&f);
    ts << QDateTime::currentDateTime().toString("HH:mm:ss.zzz") << " " << line << "\n";
}

PdfDocument::PdfDocument(QObject *parent)
    : QObject(parent), m_doc(0), m_pageCount(0), m_generation(0), m_locked(false)
{
    m_imgCache.setMaxCost(64 * 1024 * 1024);   // bytes of decoded page images
}

PdfDocument::~PdfDocument() { clear(); }

void PdfDocument::clear()
{
    delete m_doc; m_doc = 0;
    m_pageCount = 0; m_locked = false;
    m_textCache.clear();
    m_imgCache.clear();
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
    ++m_generation;
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
    const QString key = QString("%1|%2|%3|%4").arg(page).arg(qRound(scale * 1000)).arg(rotation).arg(inverted ? 1 : 0);
    QImage *hit = m_imgCache.object(key);
    if (hit) { renderLog("HIT  page=" + QString::number(page) + " key=" + key); return *hit; }
    renderLog("MISS page=" + QString::number(page) + " key=" + key);
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
    if (!img.isNull()) {
        int cost = img.bytesPerLine() * img.height();
        if (cost > 0) m_imgCache.insert(key, new QImage(img), cost);
    }
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
