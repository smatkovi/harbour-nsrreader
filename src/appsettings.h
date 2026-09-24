#ifndef APPSETTINGS_H
#define APPSETTINGS_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariantList>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int renderAhead READ renderAhead WRITE setRenderAhead NOTIFY changed)
    Q_PROPERTY(bool autoFitWidth READ autoFitWidth WRITE setAutoFitWidth NOTIFY changed)
    Q_PROPERTY(bool invertedColors READ invertedColors WRITE setInvertedColors NOTIFY changed)
    Q_PROPERTY(bool fullscreen READ fullscreen WRITE setFullscreen NOTIFY changed)
    Q_PROPERTY(bool loadLastDoc READ loadLastDoc WRITE setLoadLastDoc NOTIFY changed)
    Q_PROPERTY(QString lastDoc READ lastDoc WRITE setLastDoc NOTIFY changed)
    Q_PROPERTY(QString lastOpenDir READ lastOpenDir WRITE setLastOpenDir NOTIFY changed)
    Q_PROPERTY(bool wordWrap READ wordWrap WRITE setWordWrap NOTIFY changed)
    Q_PROPERTY(QString textEncoding READ textEncoding WRITE setTextEncoding NOTIFY changed)
    Q_PROPERTY(int textFontSize READ textFontSize WRITE setTextFontSize NOTIFY changed)
public:
    explicit AppSettings(QObject *parent = 0);

    int renderAhead() const;
    void setRenderAhead(int n);
    bool autoFitWidth() const;
    void setAutoFitWidth(bool b);

    bool invertedColors() const;
    void setInvertedColors(bool b);
    bool fullscreen() const;
    void setFullscreen(bool b);
    bool loadLastDoc() const;
    void setLoadLastDoc(bool b);
    QString lastDoc() const;
    void setLastDoc(const QString &p);
    QString lastOpenDir() const;
    void setLastOpenDir(const QString &p);
    bool wordWrap() const;
    void setWordWrap(bool b);
    QString textEncoding() const;
    void setTextEncoding(const QString &e);
    int textFontSize() const;
    void setTextFontSize(int n);

    Q_INVOKABLE QVariantList storageDirs() const;   // [{name, path}] of usable start folders
    Q_INVOKABLE bool dirExists(const QString &path) const;

    Q_INVOKABLE int lastPage(const QString &docPath) const;
    Q_INVOKABLE void setLastPage(const QString &docPath, int page);
    Q_INVOKABLE double lastZoom(const QString &docPath) const;
    Q_INVOKABLE void setLastZoom(const QString &docPath, double z);
    Q_INVOKABLE int lastRotation(const QString &docPath) const;
    Q_INVOKABLE void setLastRotation(const QString &docPath, int r);

signals:
    void changed();

private:
    mutable QSettings m_s;
};

#endif
