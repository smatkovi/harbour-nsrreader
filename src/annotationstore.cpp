#include "annotationstore.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QStandardPaths>
#include <QCryptographicHash>

AnnotationStore::AnnotationStore(QObject *parent) : QObject(parent) {}

static QString baseDir()
{
    QString d = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                + "/harbour-nsrreader/annotations";
    QDir().mkpath(d);
    return d;
}

void AnnotationStore::setDocument(const QString &path)
{
    QByteArray h = QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Md5).toHex();
    m_sidecar = baseDir() + "/" + QString::fromLatin1(h) + ".txt";
    m_anns.clear();
    load();
}

void AnnotationStore::load()
{
    QFile f(m_sidecar);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QTextStream ts(&f);
    while (!ts.atEnd()) {
        QString line = ts.readLine();
        QStringList p = line.split('|');
        if (p.size() < 7) continue;
        Ann a;
        a.page = p.at(0).toInt();
        a.type = p.at(1).toInt();
        a.rect = QRectF(p.at(2).toDouble(), p.at(3).toDouble(), p.at(4).toDouble(), p.at(5).toDouble());
        a.color = QColor(p.at(6));
        a.text = p.size() > 7 ? p.at(7) : QString();
        if (p.size() > 8 && !p.at(8).isEmpty()) {
            QStringList cs = p.at(8).split(';', QString::SkipEmptyParts);
            for (int i = 0; i < cs.size(); ++i) {
                QStringList xy = cs.at(i).split(',');
                if (xy.size() == 2) a.pts << QPointF(xy.at(0).toDouble(), xy.at(1).toDouble());
            }
        }
        m_anns << a;
    }
}

void AnnotationStore::save()
{
    QFile f(m_sidecar);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) return;
    QTextStream ts(&f);
    for (int i = 0; i < m_anns.size(); ++i) {
        const Ann &a = m_anns.at(i);
        QString pts;
        for (int k = 0; k < a.pts.size(); ++k) {
            if (k) pts += ';';
            pts += QString::number(a.pts.at(k).x()) + ',' + QString::number(a.pts.at(k).y());
        }
        ts << a.page << '|' << a.type << '|' << a.rect.x() << '|' << a.rect.y() << '|'
           << a.rect.width() << '|' << a.rect.height() << '|' << a.color.name() << '|'
           << a.text << '|' << pts << '\n';
    }
}

QVariantList AnnotationStore::forPage(int page) const
{
    QVariantList out;
    for (int i = 0; i < m_anns.size(); ++i) {
        const Ann &a = m_anns.at(i);
        if (a.page != page) continue;
        QVariantMap m;
        m["index"] = i; m["type"] = a.type;
        m["x"] = a.rect.x(); m["y"] = a.rect.y(); m["w"] = a.rect.width(); m["h"] = a.rect.height();
        m["color"] = a.color.name(); m["text"] = a.text;
        QVariantList pts;
        for (int k = 0; k < a.pts.size(); ++k) {
            QVariantMap pm; pm["x"] = a.pts.at(k).x(); pm["y"] = a.pts.at(k).y(); pts << pm;
        }
        m["pts"] = pts;
        out << m;
    }
    return out;
}

void AnnotationStore::addCircle(int page, qreal x, qreal y, qreal w, qreal h, const QString &color)
{
    Ann a; a.page = page; a.type = 0; a.rect = QRectF(x, y, w, h); a.color = QColor(color);
    m_anns << a; save(); emit changed(page);
}
void AnnotationStore::addHairpin(int page, qreal x, qreal y, qreal w, qreal h, bool cresc, const QString &color)
{
    Ann a; a.page = page; a.type = 3; a.rect = QRectF(x, y, w, h); a.color = QColor(color);
    a.text = cresc ? "c" : "d"; m_anns << a; save(); emit changed(page);
}
void AnnotationStore::addText(int page, qreal x, qreal y, const QString &text, const QString &color)
{
    Ann a; a.page = page; a.type = 2; a.rect = QRectF(x, y, 0.08, 0.04); a.color = QColor(color); a.text = text;
    m_anns << a; save(); emit changed(page);
}
void AnnotationStore::addPen(int page, const QVariantList &pts, const QString &color)
{
    if (pts.size() < 2) return;
    Ann a; a.page = page; a.type = 1; a.color = QColor(color);
    qreal x0 = 1, y0 = 1, x1 = 0, y1 = 0;
    for (int i = 0; i < pts.size(); ++i) {
        QVariantMap pm = pts.at(i).toMap();
        qreal x = pm.value("x").toReal(), y = pm.value("y").toReal();
        a.pts << QPointF(x, y);
        if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
    a.rect = QRectF(x0, y0, x1 - x0, y1 - y0);
    m_anns << a; save(); emit changed(page);
}

void AnnotationStore::moveAnn(int index, qreal dx, qreal dy)
{
    if (index < 0 || index >= m_anns.size()) return;
    Ann &a = m_anns[index];
    a.rect.translate(dx, dy);
    for (int k = 0; k < a.pts.size(); ++k) a.pts[k] += QPointF(dx, dy);
    save(); emit changed(a.page);
}
void AnnotationStore::resizeAnn(int index, qreal sx, qreal sy)
{
    if (index < 0 || index >= m_anns.size()) return;
    Ann &a = m_anns[index];
    if (a.rect.width() < 0.005) a.rect.setWidth(0.03);
    if (a.rect.height() < 0.005) a.rect.setHeight(0.03);
    qreal ax = a.rect.left(), ay = a.rect.top();
    if (a.type == 1 && !a.pts.isEmpty()) { ax = a.pts.at(0).x(); ay = a.pts.at(0).y();
        for (int k = 1; k < a.pts.size(); ++k) { if (a.pts.at(k).x() < ax) ax = a.pts.at(k).x(); if (a.pts.at(k).y() < ay) ay = a.pts.at(k).y(); } }
    a.rect = QRectF(ax + (a.rect.left() - ax) * sx, ay + (a.rect.top() - ay) * sy, a.rect.width() * sx, a.rect.height() * sy);
    for (int k = 0; k < a.pts.size(); ++k)
        a.pts[k] = QPointF(ax + (a.pts[k].x() - ax) * sx, ay + (a.pts[k].y() - ay) * sy);
    save(); emit changed(a.page);
}
void AnnotationStore::recolorAnn(int index, const QString &color)
{
    if (index < 0 || index >= m_anns.size()) return;
    m_anns[index].color = QColor(color); save(); emit changed(m_anns[index].page);
}
void AnnotationStore::flipHairpin(int index)
{
    if (index < 0 || index >= m_anns.size()) return;
    if (m_anns[index].type != 3) return;
    m_anns[index].text = (m_anns[index].text == "c") ? QString("d") : QString("c");
    save(); emit changed(m_anns[index].page);
}

int AnnotationStore::typeOf(int index) const
{
    if (index < 0 || index >= m_anns.size()) return -1;
    return m_anns.at(index).type;
}

void AnnotationStore::deleteAnn(int index)
{
    if (index < 0 || index >= m_anns.size()) return;
    int pg = m_anns[index].page; m_anns.removeAt(index); save(); emit changed(pg);
}
