#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include "pdfdocument.h"
#include "pageprovider.h"
#include "markerscanner.h"
#include "annotationstore.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);

    PdfDocument *pdf = new PdfDocument(app);
    MarkerScanner *scanner = new MarkerScanner(app);
    AnnotationStore *anns = new AnnotationStore(app);

    QQuickView *view = SailfishApp::createView();
    view->engine()->addImageProvider(QLatin1String("pdf"), new PageProvider(pdf));
    view->rootContext()->setContextProperty("pdf", pdf);
    view->rootContext()->setContextProperty("scanner", scanner);
    view->rootContext()->setContextProperty("anns", anns);

    view->setSource(SailfishApp::pathToMainQml());
    view->show();
    return app->exec();
}
