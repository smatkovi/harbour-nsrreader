import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: tpage
    property string path: ""
    property string content: ""

    allowedOrientations: Orientation.All

    function reload() {
        content = textdoc.loadText(path, settings.textEncoding)
        settings.lastDoc = path
    }
    Component.onCompleted: reload()

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: txt.height + Theme.paddingLarge * 2

        PullDownMenu {
            MenuItem { text: "Open another"; onClicked: pageStack.pop() }
            MenuItem {
                text: settings.wordWrap ? "No word wrap" : "Word wrap"
                onClicked: settings.wordWrap = !settings.wordWrap
            }
            MenuItem { text: "Encoding"; onClicked: tpage.pickEncoding() }
            MenuItem { text: "Bigger text"; onClicked: settings.textFontSize = settings.textFontSize + 2 }
            MenuItem { text: "Smaller text"; onClicked: settings.textFontSize = settings.textFontSize - 2 }
        }

        Label {
            id: txt
            x: Theme.horizontalPageMargin
            y: Theme.paddingLarge
            width: tpage.width - 2 * Theme.horizontalPageMargin
            text: tpage.content
            wrapMode: settings.wordWrap ? Text.WordWrap : Text.NoWrap
            font.pixelSize: settings.textFontSize
            color: settings.invertedColors ? "white" : Theme.primaryColor
            textFormat: Text.PlainText
        }
        VerticalScrollDecorator {}
    }

    function pickEncoding() {
        var dlg = pageStack.push(Qt.resolvedUrl("PickListDialog.qml"),
            { title: "Encoding", items: textdoc.encodings() })
        dlg.accepted.connect(function() {
            if (dlg.selected.length) { settings.textEncoding = dlg.selected; tpage.reload() }
        })
    }
}
