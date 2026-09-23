import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dlg
    property string title: "Go to"
    property bool numeric: true
    property string value: ""
    Column {
        width: parent.width
        DialogHeader {}
        TextField {
            id: tf
            width: parent.width
            label: dlg.title
            placeholderText: dlg.title
            inputMethodHints: dlg.numeric ? Qt.ImhDigitsOnly : Qt.ImhNoAutoUppercase
            EnterKey.onClicked: dlg.accept()
            Component.onCompleted: forceActiveFocus()
        }
    }
    onAccepted: value = tf.text
}
