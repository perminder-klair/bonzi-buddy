import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool accent: false
    implicitHeight: 34
    hoverEnabled: true
    font.pixelSize: 12
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.accent ? "#faf5ff" : "#e5d8f3"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 8
        color: control.down ? "#7542a9" : control.hovered ? "#503463" : control.accent ? "#65358c" : "#352640"
        border.color: control.activeFocus ? "#d5a4ff" : "#614472"
        border.width: 1
    }
}
