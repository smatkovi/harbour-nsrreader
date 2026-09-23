#ifndef MARKERSCANNER_H
#define MARKERSCANNER_H

#include <QObject>
#include <QMap>
#include <QStringList>
#include <QVariantList>

class PdfDocument;

class MarkerScanner : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList markerLabels READ markerLabels NOTIFY scanned)
    Q_PROPERTY(QVariantList markerPages READ markerPages NOTIFY scanned)
    Q_PROPERTY(bool scannedOk READ scannedOk NOTIFY scanned)
    Q_PROPERTY(bool hasBars READ hasBars NOTIFY scanned)
public:
    explicit MarkerScanner(QObject *parent = 0);

    Q_INVOKABLE void scan(QObject *doc);
    Q_INVOKABLE int jumpToBar(int bar) const;        // -> page (nearest lower), 0 if none
    Q_INVOKABLE int jumpToLetter(const QString &c) const;

    QStringList markerLabels() const { return m_labels; }
    QVariantList markerPages() const { return m_pages; }
    bool scannedOk() const { return m_scanned; }
    bool hasBars() const { return !m_barMap.isEmpty(); }

signals:
    void scanned();

private:
    QMap<int,int> m_barMap;
    QMap<QString,int> m_letterMap;
    QStringList m_labels;
    QVariantList m_pages;
    bool m_scanned;
};

#endif
