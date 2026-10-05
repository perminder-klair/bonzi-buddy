import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: row
    property string text
    property string description: ""
    property bool checked: false
    signal toggled(bool value)
    spacing: 10
    ColumnLayout {
        Layout.fillWidth: true; spacing: 2
        Text { text: row.text; color: row.enabled ? "#eee1fa" : "#8c7c96"; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { text: row.description; visible: text !== ""; color: "#a38cb0"; font.pixelSize: 10; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    }
    Switch { checked: row.checked; onToggled: row.toggled(checked) }
}
