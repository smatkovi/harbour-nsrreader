import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            PageHeader { title: "Preferences" }
            Slider {
                width: parent.width
                minimumValue: 0; maximumValue: 8; stepSize: 1
                value: settings.renderAhead
                label: "Pre-render pages"
                valueText: value
                onValueChanged: settings.renderAhead = value
            }
            TextSwitch {
                text: "Fit new documents to width"
                checked: settings.autoFitWidth
                onCheckedChanged: settings.autoFitWidth = checked
            }
            TextSwitch {
                text: "Inverted colours"
                description: "Light text on dark background"
                checked: settings.invertedColors
                onCheckedChanged: settings.invertedColors = checked
            }
            TextSwitch {
                text: "Fullscreen"
                description: "Hide page counter and marker bar"
                checked: settings.fullscreen
                onCheckedChanged: settings.fullscreen = checked
            }
            TextSwitch {
                text: "Open last document on start"
                checked: settings.loadLastDoc
                onCheckedChanged: settings.loadLastDoc = checked
            }
            SectionHeader { text: "Text files" }
            TextSwitch {
                text: "Word wrap"
                checked: settings.wordWrap
                onCheckedChanged: settings.wordWrap = checked
            }
            Slider {
                width: parent.width
                minimumValue: 10; maximumValue: 60; stepSize: 2
                value: settings.textFontSize
                label: "Text size"
                valueText: value
                onValueChanged: settings.textFontSize = value
            }
            ValueButton {
                label: "Encoding"
                value: settings.textEncoding
                onClicked: {
                    var dlg = pageStack.push(Qt.resolvedUrl("PickListDialog.qml"),
                        { title: "Encoding", items: textdoc.encodings() })
                    dlg.accepted.connect(function() { if (dlg.selected.length) settings.textEncoding = dlg.selected })
                }
            }
        }
    }
}
