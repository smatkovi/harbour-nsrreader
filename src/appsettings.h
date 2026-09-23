#ifndef APPSETTINGS_H
#define APPSETTINGS_H

#include <QObject>
#include <QSettings>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int renderAhead READ renderAhead WRITE setRenderAhead NOTIFY changed)
    Q_PROPERTY(bool autoFitWidth READ autoFitWidth WRITE setAutoFitWidth NOTIFY changed)
public:
    explicit AppSettings(QObject *parent = 0);

    int renderAhead() const;
    void setRenderAhead(int n);
    bool autoFitWidth() const;
    void setAutoFitWidth(bool b);

    Q_INVOKABLE int lastPage(const QString &docPath) const;
    Q_INVOKABLE void setLastPage(const QString &docPath, int page);

signals:
    void changed();

private:
    mutable QSettings m_s;
};

#endif
