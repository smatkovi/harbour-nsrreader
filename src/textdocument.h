#ifndef TEXTDOCUMENT_H
#define TEXTDOCUMENT_H

#include <QObject>
#include <QString>
#include <QStringList>

class TextDocument : public QObject
{
    Q_OBJECT
public:
    explicit TextDocument(QObject *parent = 0);
    Q_INVOKABLE QString loadText(const QString &path, const QString &encoding);
    Q_INVOKABLE QStringList encodings() const;
};

#endif
