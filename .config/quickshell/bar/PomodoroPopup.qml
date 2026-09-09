import QtQuick
import Quickshell

// Panel de acciones del pomodoro (clic derecho en el contador). Calcado del
// CalendarPopup, incluido el anclaje: cuelga de la ventana de la barra, con la
// x del isla que lo abre y la y bajo la barra.
//
// Ese anclaje no es un detalle. Colgado de una ventana propia pequeña y con
// ExclusionMode.Ignore —como estuvo mientras el contador flotaba bajo la
// barra— el compositor desmapeaba el popup a los ~80 ms, con QML creyendo
// todavía que seguía visible. Daba igual grabFocus, el anclaje por item o por
// ventana, el tamaño fijo o dónde estuviera el puntero. Colgado de la barra,
// que es ancha y con zona exclusiva, se comporta como el resto de paneles.
PopupWindow {
    id: root
    property var anchorItem

    implicitWidth: 228
    implicitHeight: col.implicitHeight + 40
    color: "transparent"
    grabFocus: true

    anchor.window: anchorItem ? anchorItem.QsWindow.window : null
    anchor.rect.x: anchorItem ? anchorItem.x : 0
    anchor.rect.y: Theme.barHeight + 4

    // con la sesión parada el panel abre igual, pero sin acciones vivas: el
    // gesto responde en vez de parecer que el contador está roto
    readonly property bool live: Pomo.status !== "idle"

    readonly property string headText: Pomo.status === "idle" ? "EN REPOSO"
                                     : Pomo.shownPhase === "work" ? "TRABAJO" : "DESCANSO"
    readonly property string skipText: "saltar a " + (Pomo.other(Pomo.phase) === "work" ? "trabajo" : "descanso")

    // 1,5 s, no los 250 ms del calendario: el panel es un menú de acciones, hay
    // que poder salirse y volver a entrar sin que se cierre en la cara.
    property bool entered: false
    Timer { id: closeTimer; interval: 1500; onTriggered: if (!hover.hovered) root.visible = false }
    onVisibleChanged: root.entered = false

    function act(a) {
        if (!root.live) return;
        if (a === "reset") Pomo.reset();
        else if (a === "skip") Pomo.skip();
        else Pomo.stop();
        root.visible = false;
    }

    Rectangle {
        id: panel
        anchors.fill: parent; anchors.margins: 6
        radius: 14; color: Theme.islandBg; border.color: Theme.purple; border.width: 1

        opacity: 0
        transform: Translate { id: slide; y: -10 }
        states: State { name: "open"; when: root.visible
            PropertyChanges { target: panel; opacity: 1 }
            PropertyChanges { target: slide; y: 0 } }
        transitions: Transition {
            NumberAnimation { target: panel; property: "opacity"; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: slide; property: "y"; duration: 150; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) { root.entered = true; closeTimer.stop(); }
                else if (root.entered) closeTimer.restart();
            }
        }

        Column {
            id: col
            anchors.fill: parent; anchors.margins: 14; spacing: 8

            // la cabecera dice lo mismo que el contador, no el valor crudo de
            // `phase`: en "done" ya se ha adelantado a la fase que viene
            Item {
                width: parent.width; height: Theme.clockPx + 4
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: root.headText
                    color: root.live ? Theme.clockText : Theme.muted
                    font.family: Theme.monoFamily; font.pixelSize: Theme.fontPx
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: Pomo.fmt(Pomo.shownSecs)
                    color: root.live ? Theme.cyan : Theme.muted
                    font.family: Theme.monoFamily; font.pixelSize: Theme.clockPx
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.purple; opacity: 0.4 }

            Repeater {
                model: [
                    { glyph: "󰑐", label: "reiniciar fase", act: "reset" },
                    { glyph: "󰒭", label: root.skipText,    act: "skip"  },
                    { glyph: "󰓛", label: "detener",        act: "stop"  }
                ]
                delegate: Item {
                    id: row
                    required property var modelData
                    width: parent.width
                    height: Theme.clockPx + 8
                    property bool hot: false

                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Text {
                            text: row.modelData.glyph
                            color: !root.live ? Theme.muted : row.hot ? Theme.cyan : Theme.textBase
                            font.family: Theme.monoFamily; font.pixelSize: Theme.fontPx
                        }
                        Text {
                            text: row.modelData.label
                            color: !root.live ? Theme.muted : row.hot ? Theme.cyan : Theme.textBase
                            font.family: Theme.monoFamily; font.pixelSize: Theme.fontPx
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: root.live
                        cursorShape: root.live ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: row.hot = true
                        onExited: row.hot = false
                        onClicked: root.act(row.modelData.act)
                    }
                }
            }
        }
    }
}
