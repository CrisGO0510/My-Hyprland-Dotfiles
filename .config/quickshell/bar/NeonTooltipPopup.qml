import QtQuick
import Quickshell

// Mismo aspecto que NeonTooltip, pero en su propia ventana. La barra mide
// 38 px y Qt encaja sus popups dentro de ella, asi que un ToolTip normal se
// queda encima de los iconos por mucho que se le mueva la `y`: este cuelga
// por debajo de la barra.
PopupWindow {
    id: root
    property Item anchorItem
    property alias text: label.text

    // franja transparente que separa la burbuja de la barra: `anchor.margins`
    // no la desplaza, asi que el hueco va dentro de la ventana
    readonly property int gap: 6

    implicitWidth: label.implicitWidth + 22
    implicitHeight: label.implicitHeight + 17 + gap
    color: "transparent"

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    onVisibleChanged: bubble.opacity = visible ? 1 : 0

    Rectangle {
        id: bubble
        anchors.fill: parent
        anchors.topMargin: root.gap
        color: Theme.islandBg
        radius: 10
        border.color: Theme.purple
        border.width: 1
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

        Text {
            id: label
            anchors.centerIn: parent
            color: Theme.textBase
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontPx
        }
    }
}
