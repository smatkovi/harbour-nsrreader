import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dlg
    property string title: "Pick"
    property var items: []
    property string selected: ""
    canAccept: selected.length > 0
    SilicaListView {
        anchors.fill: parent
        header: DialogHeader { title: dlg.title }
        model: dlg.items
        delegate: ListItem {
            Label { x: Theme.horizontalPageMargin; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: highlighted ? Theme.highlightColor : Theme.primaryColor }
            onClicked: { dlg.selected = modelData; dlg.accept() }
        }
    }
}
