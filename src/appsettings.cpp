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
