import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height + Theme.paddingLarge
        Column {
            id: col
            width: parent.width
            spacing: Theme.paddingMedium
            PageHeader { title: "About" }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: "NSR Reader for Sailfish OS\nVersion 0.29.0"
                color: Theme.primaryColor
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                text: "A PDF viewer geared towards reading sheet music: pre-rendering, "
                      + "page and bar navigation, text jumps (Coda/Segno/Fine/Capo) read from "
                      + "the score, annotations, and a type-to-search file browser.\n\n"
                      + "Rendering uses poppler-qt5. Based on NSR Reader by Alexander Saprykin (GPL). "
                      + "Shares its C++ core with the MeeGo/Harmattan build."
            }
        }
        VerticalScrollDecorator {}
    }
}
