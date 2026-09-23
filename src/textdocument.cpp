#include "textdocument.h"
#include <QFile>
#include <QUrl>
#include <QTextCodec>

TextDocument::TextDocument(QObject *parent) : QObject(parent) {}

QString TextDocument::loadText(const QString &path, const QString &encoding)
{
    QString p = path;
    if (p.startsWith("file://")) p = QUrl(p).toLocalFile();
    QFile f(p);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    QByteArray raw = f.readAll();
    f.close();
    QTextCodec *codec = QTextCodec::codecForName(encoding.toLatin1());
    if (!codec) codec = QTextCodec::codecForName("UTF-8");
    return codec->toUnicode(raw);
}

QStringList TextDocument::encodings() const
{
    QStringList l;
    l << "UTF-8" << "ISO-8859-1" << "ISO-8859-15" << "windows-1250"
      << "windows-1251" << "windows-1252" << "KOI8-R" << "UTF-16";
    return l;
}
