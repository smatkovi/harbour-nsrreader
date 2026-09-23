#include <sailfishapp.h>
#include <QGuiApplication>
#include <QCoreApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlError>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <cstdio>
#include "pdfdocument.h"
#include "pageprovider.h"
#include "markerscanner.h"
#include "annotationstore.h"
#include "appsettings.h"
#include "textdocument.h"

static FILE *g_boot = 0;
#define BLOG(msg) do { if (g_boot) { fprintf(g_boot, "%s\n", msg); fflush(g_boot); } } while (0)

static QFile *g_log = 0;
static void logMsg(QtMsgType, const QMessageLogContext &, const QString &m)
{
    if (g_log) { QTextStream ts(g_log); ts << m << "\n"; g_log->flush(); }
}

int main(int argc, char *argv[])
{
    g_boot = fopen("/home/defaultuser/.local/share/harbour-nsrreader/boot.log", "w");
    if (!g_boot) g_boot = fopen("/tmp/nsrboot.log", "w");
    BLOG("01 main entered");
    QGuiApplication *app = SailfishApp::application(argc, argv);
    BLOG("02 SailfishApp::application ok");
    QCoreApplication::setOrganizationName(QStringLiteral("harbour-nsrreader"));
    QCoreApplication::setApplicationName(QStringLiteral("harbour-nsrreader"));

    QString ld = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/harbour-nsrreader";
    QDir().mkpath(ld);
    g_log = new QFile(ld + "/startup.log");
    g_log->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text);
    qInstallMessageHandler(logMsg);
    qWarning() << "=== start" << QDateTime::currentDateTime().toString();
    qWarning() << "dataloc" << ld;
    BLOG("03 logging set up");

    PdfDocument *pdf = new PdfDocument(app);
    MarkerScanner *scanner = new MarkerScanner(app);
    AnnotationStore *anns = new AnnotationStore(app);
    AppSettings *settings = new AppSettings(app);
    TextDocument *textdoc = new TextDocument(app);

    BLOG("04 backends created");
    QQuickView *view = SailfishApp::createView();
    QObject::connect(view->engine(), &QQmlEngine::warnings, [](const QList<QQmlError> &ws) {
        for (int i = 0; i < ws.size(); ++i) {
            if (g_boot) { fprintf(g_boot, "QMLWARN %s\n", ws.at(i).toString().toUtf8().constData()); fflush(g_boot); }
        }
    });
    BLOG("05 createView ok");
    view->engine()->addImageProvider(QLatin1String("pdf"), new PageProvider(pdf));
    view->rootContext()->setContextProperty(QStringLiteral("pdf"), pdf);
    view->rootContext()->setContextProperty(QStringLiteral("scanner"), scanner);
    view->rootContext()->setContextProperty(QStringLiteral("anns"), anns);
    view->rootContext()->setContextProperty(QStringLiteral("settings"), settings);
    view->rootContext()->setContextProperty(QStringLiteral("textdoc"), textdoc);

    QUrl src = SailfishApp::pathTo(QStringLiteral("qml/harbour-nsrreader.qml"));
    qWarning() << "src" << src.toString();
    BLOG("06 about to setSource");
    view->setSource(src);
    BLOG("07 setSource returned");
    qWarning() << "status" << int(view->status()) << "(0=Null 1=Ready 2=Loading 3=Error)";
    QList<QQmlError> errs = view->errors();
    for (int i = 0; i < errs.size(); ++i) { qWarning() << "QMLERR" << errs.at(i).toString();
        if (g_boot) { fprintf(g_boot, "QMLERR %s\n", errs.at(i).toString().toUtf8().constData()); fflush(g_boot); } }
    { char b[64]; snprintf(b, sizeof(b), "status=%d errs=%d", int(view->status()), errs.size()); BLOG(b); }
    BLOG("08 about to show");
    view->show();
    BLOG("09 shown, entering exec");
    qWarning() << "shown; size" << view->size() << "visible" << view->isVisible();
    int rc = app->exec();
    BLOG("10 exec returned");
    qWarning() << "exec returned" << rc;
    return rc;
}
