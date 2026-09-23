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
                minimumValue: 0
                maximumValue: 8
                stepSize: 1
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
        }
    }
}
