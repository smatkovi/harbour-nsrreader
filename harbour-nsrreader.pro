TARGET = harbour-nsrreader
CONFIG += sailfishapp c++11 link_pkgconfig
PKGCONFIG += poppler-qt5
QT += core gui qml quick
QMAKE_CXXFLAGS_RELEASE += -O3 -ftree-vectorize -ffast-math
QMAKE_CFLAGS_RELEASE += -O3 -ftree-vectorize
LIBS += -lsailfishapp

SOURCES += \
    src/harbour-nsrreader.cpp \
    src/pdfdocument.cpp \
    src/pageprovider.cpp \
    src/markerscanner.cpp \
    src/annotationstore.cpp \
    src/appsettings.cpp \
    src/textdocument.cpp

HEADERS += \
    src/pdfdocument.h \
    src/pageprovider.h \
    src/markerscanner.h \
    src/annotationstore.h \
    src/appsettings.h \
    src/textdocument.h

DISTFILES += \
    qml/harbour-nsrreader.qml \
    qml/pages/FilePickerPage.qml \
    qml/pages/ReaderPage.qml \
    qml/pages/GoToDialog.qml \
    qml/pages/PickListDialog.qml \
    qml/pages/PreferencesPage.qml \
    qml/pages/TextReaderPage.qml \
    qml/pages/AboutPage.qml \
    qml/cover/CoverPage.qml \
    rpm/harbour-nsrreader.spec \
    harbour-nsrreader.desktop

icon86.files = icons/86x86/harbour-nsrreader.png
icon86.path = /usr/share/icons/hicolor/86x86/apps
icon108.files = icons/108x108/harbour-nsrreader.png
icon108.path = /usr/share/icons/hicolor/108x108/apps
icon128.files = icons/128x128/harbour-nsrreader.png
icon128.path = /usr/share/icons/hicolor/128x128/apps
icon172.files = icons/172x172/harbour-nsrreader.png
icon172.path = /usr/share/icons/hicolor/172x172/apps
INSTALLS += icon86 icon108 icon128 icon172
