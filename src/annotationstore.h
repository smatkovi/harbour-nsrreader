#ifndef ANNOTATIONSTORE_H
#define ANNOTATIONSTORE_H

#include <QObject>
#include <QList>
#include <QRectF>
#include <QColor>
#include <QVariantList>
#include <QPointF>

class AnnotationStore : public QObject
{
    Q_OBJECT
public:
    explicit AnnotationStore(QObject *parent = 0);

    Q_INVOKABLE void setDocument(const QString &path);
    Q_INVOKABLE QVariantList forPage(int page) const;   // list of {index,type,x,y,w,h,color,text,pts}

    Q_INVOKABLE void addCircle(int page, qreal x, qreal y, qreal w, qreal h, const QString &color);
    Q_INVOKABLE void addHairpin(int page, qreal x, qreal y, qreal w, qreal h, bool cresc, const QString &color);
    Q_INVOKABLE void addText(int page, qreal x, qreal y, const QString &text, const QString &color);
    Q_INVOKABLE void addPen(int page, const QVariantList &pts, const QString &color); // pts: [{x,y},...]

    Q_INVOKABLE void moveAnn(int index, qreal dx, qreal dy);
    Q_INVOKABLE void resizeAnn(int index, qreal sx, qreal sy);
    Q_INVOKABLE void recolorAnn(int index, const QString &color);
    Q_INVOKABLE void flipHairpin(int index);
    Q_INVOKABLE int typeOf(int index) const;
    Q_INVOKABLE void deleteAnn(int index);

signals:
    void changed(int page);

private:
    struct Ann { int page; int type; QRectF rect; QColor color; QString text; QList<QPointF> pts; };
    void save();
    void load();
    QString m_sidecar;
    QList<Ann> m_anns;
};

#endif
