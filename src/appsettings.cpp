#include "appsettings.h"
#include <QCryptographicHash>

AppSettings::AppSettings(QObject *parent) : QObject(parent) {}

int AppSettings::renderAhead() const { return m_s.value("renderAhead", 2).toInt(); }
void AppSettings::setRenderAhead(int n)
{
    if (n < 0) n = 0; if (n > 8) n = 8;
    if (n == renderAhead()) return;
    m_s.setValue("renderAhead", n); m_s.sync(); emit changed();
}
bool AppSettings::autoFitWidth() const { return m_s.value("autoFitWidth", true).toBool(); }
void AppSettings::setAutoFitWidth(bool b)
{
    if (b == autoFitWidth()) return;
    m_s.setValue("autoFitWidth", b); m_s.sync(); emit changed();
}

static QString keyFor(const QString &docPath)
{
    return QString::fromLatin1(QCryptographicHash::hash(docPath.toUtf8(), QCryptographicHash::Md5).toHex());
}

bool AppSettings::invertedColors() const { return m_s.value("invertedColors", false).toBool(); }
void AppSettings::setInvertedColors(bool b)
{
    if (b == invertedColors()) return;
    m_s.setValue("invertedColors", b); m_s.sync(); emit changed();
}
bool AppSettings::fullscreen() const { return m_s.value("fullscreen", false).toBool(); }
void AppSettings::setFullscreen(bool b)
{
    if (b == fullscreen()) return;
    m_s.setValue("fullscreen", b); m_s.sync(); emit changed();
}
bool AppSettings::loadLastDoc() const { return m_s.value("loadLastDoc", false).toBool(); }
void AppSettings::setLoadLastDoc(bool b)
{
    if (b == loadLastDoc()) return;
    m_s.setValue("loadLastDoc", b); m_s.sync(); emit changed();
}
QString AppSettings::lastDoc() const { return m_s.value("lastDoc", QString()).toString(); }
void AppSettings::setLastDoc(const QString &p)
{
    if (p == lastDoc()) return;
    m_s.setValue("lastDoc", p); m_s.sync(); emit changed();
}
QString AppSettings::lastOpenDir() const { return m_s.value("lastOpenDir", QString()).toString(); }
void AppSettings::setLastOpenDir(const QString &p)
{
    if (p == lastOpenDir()) return;
    m_s.setValue("lastOpenDir", p); m_s.sync(); emit changed();
}

double AppSettings::lastZoom(const QString &docPath) const
{
    if (docPath.isEmpty()) return 1.0;
    return m_s.value("lastzoom/" + keyFor(docPath), 1.0).toDouble();
}
void AppSettings::setLastZoom(const QString &docPath, double z)
{
    if (docPath.isEmpty() || z <= 0) return;
    m_s.setValue("lastzoom/" + keyFor(docPath), z);
}
int AppSettings::lastRotation(const QString &docPath) const
{
    if (docPath.isEmpty()) return 0;
    return m_s.value("lastrot/" + keyFor(docPath), 0).toInt();
}
void AppSettings::setLastRotation(const QString &docPath, int r)
{
    if (docPath.isEmpty()) return;
    m_s.setValue("lastrot/" + keyFor(docPath), r);
}

int AppSettings::lastPage(const QString &docPath) const
{
    if (docPath.isEmpty()) return 1;
    return m_s.value("lastpage/" + keyFor(docPath), 1).toInt();
}
void AppSettings::setLastPage(const QString &docPath, int page)
{
    if (docPath.isEmpty() || page < 1) return;
    m_s.setValue("lastpage/" + keyFor(docPath), page);
}
