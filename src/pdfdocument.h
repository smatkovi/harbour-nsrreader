#ifndef PDFDOCUMENT_H
#define PDFDOCUMENT_H

#include <QObject>
#include <QImage>
#include <QString>
#include <QStringList>
#include <QHash>
#include <QMutex>
#include <QCache>

namespace Poppler { class Document; }

class PdfDocument : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY loadedChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(bool locked READ locked NOTIFY loadedChanged)
    Q_PROPERTY(int generation READ generation NOTIFY loadedChanged)
public:
    explicit PdfDocument(QObject *parent = 0);
    ~PdfDocument();

    QString source() const { return m_source; }
    void setSource(const QString &s);
    int pageCount() const { return m_pageCount; }
    bool loaded() const { return m_doc != 0; }
    bool locked() const { return m_locked; }
    int generation() const { return m_generation; }

    // Render page (1-based) at the given scale (1.0 == 72dpi == PDF points). Cached-friendly.
    QImage renderPage(int page, qreal scale, int rotation, bool inverted);
    // Page size in PDF points (72dpi).
    Q_INVOKABLE QSizeF pageSizePoints(int page, int rotation = 0);
    // Full text of a page (1-based), cheap physical-layout extraction.
    Q_INVOKABLE QString textForPage(int page);

    Q_INVOKABLE bool unlock(const QString &password);

signals:
    void sourceChanged();
    void loadedChanged();

private:
    void load();
    void clear();

    QString m_source;
    Poppler::Document *m_doc;
    int m_pageCount;
    int m_generation;
    bool m_locked;
    QHash<int, QString> m_textCache;
    QCache<QString, QImage> m_imgCache;
    QMutex m_mutex;
};

#endif
