#include "markerscanner.h"
#include "pdfdocument.h"
#include <QRegExp>
#include <QChar>

MarkerScanner::MarkerScanner(QObject *parent) : QObject(parent), m_scanned(false) {}

void MarkerScanner::scan(QObject *docObj)
{
    PdfDocument *doc = qobject_cast<PdfDocument *>(docObj);
    m_barMap.clear(); m_letterMap.clear(); m_labels.clear(); m_pages.clear();
    m_scanned = false;
    if (!doc || !doc->loaded()) { emit scanned(); return; }

    QRegExp re("\\d{1,4}");
    QRegExp rpm(", *m\\.? *(\\d+)");   // measure ref inside "D.S. al Coda (p.N, m.M)"
    int codaP = -1, segnoP = -1, fineP = -1, alCodaP = -1, segnoMeasure = -1;
    int voicePage = -1;
    bool hasDC = false, hasDS = false, hasAlFine = false;
    int n = doc->pageCount();

    for (int pg = 1; pg <= n; ++pg) {
        QString t = doc->textForPage(pg);
        int pos = 0;
        while ((pos = re.indexIn(t, pos)) != -1) {
            int v = re.cap(0).toInt();
            if (v >= 1 && v <= 9999 && !m_barMap.contains(v)) m_barMap.insert(v, pg);
            pos += re.matchedLength();
        }
        QString tl = t.toLower();
        int cpos = tl.indexOf("coda");
        while (cpos != -1) {
            QString bef = (cpos >= 3) ? tl.mid(cpos - 3, 3) : QString();
            QChar cb = (cpos >= 1) ? tl.at(cpos - 1) : QChar(32);
            QChar ca = (cpos + 4 < tl.length()) ? tl.at(cpos + 4) : QChar(32);
            if (!cb.isLetter() && !ca.isLetter() && !bef.endsWith("to ") && !bef.endsWith("al ")) codaP = pg;
            cpos = tl.indexOf("coda", cpos + 4);
        }
        if (tl.contains("da capo") || tl.contains("d.c.")) hasDC = true;
        if (tl.contains("d.s.") || tl.contains("dal segno")) hasDS = true;
        if (tl.contains("al fine")) hasAlFine = true;
        if (tl.contains("al coda")) alCodaP = pg;
        if (voicePage < 0 && (tl.contains("soprano") || tl.contains("sopran") || tl.contains("tenor")
                || tl.contains("bariton") || tl.contains("mezzo") || tl.contains("alto") || tl.contains("bass")))
            voicePage = pg;
        {
            int dspos = tl.indexOf("d.s.");
            if (dspos < 0) dspos = tl.indexOf("dal segno");
            if (dspos >= 0 && rpm.indexIn(tl.mid(dspos, 60)) >= 0) segnoMeasure = rpm.cap(1).toInt();
        }
        int fpos = tl.indexOf("fine");
        while (fpos != -1) {
            QString fbef = (fpos >= 3) ? tl.mid(fpos - 3, 3) : QString();
            QChar fb = (fpos >= 1) ? tl.at(fpos - 1) : QChar(32);
            QChar fa = (fpos + 4 < tl.length()) ? tl.at(fpos + 4) : QChar(32);
            if (!fb.isLetter() && !fa.isLetter() && !fbef.endsWith("al ")) fineP = pg;
            fpos = tl.indexOf("fine", fpos + 4);
        }
        for (int i = 0; i < t.length(); ++i) {
            QChar ch = t.at(i);
            if (ch >= QChar('A') && ch <= QChar('Z')) {
                QChar pb = (i >= 1) ? t.at(i - 1) : QChar(32);
                QChar pa = (i + 1 < t.length()) ? t.at(i + 1) : QChar(32);
                if (!pb.isLetterOrNumber() && !pa.isLetterOrNumber()) {
                    QString lk(ch);
                    if (!m_letterMap.contains(lk)) m_letterMap.insert(lk, pg);
                }
            }
        }
    }

    if (codaP <= 0 && alCodaP > 0) codaP = alCodaP;              // Coda glyph fallback (validated 17/17)
    if (hasDS && segnoMeasure > 0 && !m_barMap.isEmpty()) {       // Segno only when a real measure pins it
        QMap<int,int>::const_iterator it = m_barMap.upperBound(segnoMeasure);
        if (it != m_barMap.constBegin()) { --it; segnoP = it.value(); }
    }
    if (segnoP > 0) { m_labels << "Segno"; m_pages << segnoP; }
    if (codaP > 0)  { m_labels << "Coda";  m_pages << codaP; }
    if (fineP > 0 && hasAlFine) { m_labels << "Fine"; m_pages << fineP; }
    if (hasDC) { m_labels.prepend("Capo"); m_pages.prepend(voicePage > 0 ? voicePage : 1); }

    m_scanned = true;
    emit scanned();
}

int MarkerScanner::jumpToBar(int bar) const
{
    if (m_barMap.isEmpty() || bar < 1) return 0;
    QMap<int,int>::const_iterator it = m_barMap.upperBound(bar);
    if (it == m_barMap.constBegin()) return 0;
    --it;
    return it.value();
}

int MarkerScanner::jumpToLetter(const QString &c) const
{
    QString L = c.toUpper();
    return m_letterMap.contains(L) ? m_letterMap.value(L) : 0;
}
