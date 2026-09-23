import QtQuick 2.6
import Sailfish.Silica 1.0
import Qt.labs.folderlistmodel 2.1

Page {
    id: page
    property string folder: settings.lastOpenDir.length > 0 ? settings.lastOpenDir : StandardPaths.home
    property string search: ""

    SilicaListView {
        id: list
        anchors.fill: parent
        PullDownMenu {
            MenuItem { text: "About"; onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml")) }
            MenuItem { text: "Preferences"; onClicked: pageStack.push(Qt.resolvedUrl("PreferencesPage.qml")) }
        }
        header: Column {
            width: list.width
            PageHeader { title: "Open document" }
            SearchField {
                id: sf
                width: parent.width
                placeholderText: "Type to search"
                inputMethodHints: Qt.ImhNoAutoUppercase
                onTextChanged: page.search = text.trim()
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*Theme.horizontalPageMargin
                text: folderModel.folder.toString().replace("file://","")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
            }
        }

        FolderListModel {
            id: folderModel
            folder: "file://" + page.folder
            showDirs: true
            showDotAndDotDot: true
            showOnlyReadable: true
            sortField: FolderListModel.Name
            nameFilters: page.search.length > 0
                ? ["*" + page.search + "*.pdf", "*" + page.search + "*.PDF",
                   "*" + page.search + "*.djvu", "*" + page.search + "*.txt", "*" + page.search + "*.tif*"]
                : ["*.pdf","*.PDF","*.djvu","*.txt","*.tif","*.tiff"]
        }

        // Directories always shown (search filters files only)
        model: folderModel

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeSmall
            Label {
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2*Theme.horizontalPageMargin
                text: fileIsDir ? fileName + "/" : fileName
                truncationMode: TruncationMode.Fade
                color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            onClicked: {
                if (fileIsDir) {
                    page.search = ""
                    page.folder = filePath
                    settings.lastOpenDir = filePath
                } else {
                    var lower = fileName.toLowerCase()
                    if (lower.indexOf(".txt", lower.length - 4) !== -1)
                        pageStack.push(Qt.resolvedUrl("TextReaderPage.qml"), { path: filePath })
                    else
                        pageStack.push(Qt.resolvedUrl("ReaderPage.qml"), { path: filePath })
                }
            }
        }
        VerticalScrollDecorator {}
    }
}
