import QtQuick 2.6
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app
    initialPage: Component { FilePickerPage {} }
    cover: Component { CoverPage {} }
    allowedOrientations: Orientation.All
    Component.onCompleted: {
        if (settings.loadLastDoc && settings.lastDoc.length > 0)
            pageStack.push(Qt.resolvedUrl("pages/ReaderPage.qml"), { path: settings.lastDoc })
    }
}
