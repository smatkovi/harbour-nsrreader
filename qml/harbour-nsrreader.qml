import QtQuick 2.6
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
    id: app
    property string openPath: ""
    initialPage: Component { FilePickerPage {} }
    cover: Component { Qt.resolvedUrl("cover/CoverPage.qml") }
    allowedOrientations: Orientation.All
}
