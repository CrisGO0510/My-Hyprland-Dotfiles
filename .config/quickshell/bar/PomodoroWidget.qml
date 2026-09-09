import QtQuick

// Contador del pomodoro para la barra. Solo pinta el estado de Pomo y traduce
// clics: izquierdo arranca/pausa/confirma fase, derecho abre el panel.
Item {
    id: root
    signal clicked()
    signal menuRequested()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // parpadeo mientras espera confirmación de fase
    property color blink: Theme.purple
    SequentialAnimation on blink {
        running: Pomo.status === "done"
        loops: Animation.Infinite
        ColorAnimation { from: Theme.purple; to: Theme.cyan;   duration: 600; easing.type: Easing.InOutQuad }
        ColorAnimation { from: Theme.cyan;   to: Theme.purple; duration: 600; easing.type: Easing.InOutQuad }
    }

    readonly property color accent: Pomo.status === "done" ? root.blink
                                  : Pomo.status === "idle" ? Theme.muted
                                  : Pomo.shownPhase === "work" ? Theme.purple : Theme.cyan
    readonly property color timeColor: Pomo.status === "done" ? root.blink
                                     : Pomo.status === "idle" ? Theme.muted
                                     : Pomo.shownPhase === "work" ? Theme.clockText : Theme.cyan
    readonly property string glyph: Pomo.status === "paused" ? "󰏤"
                                  : Pomo.shownPhase === "work" ? "󰔟" : "󰅶"

    // en pausa se atenúa, sin perder el color de la fase
    opacity: Pomo.status === "paused" ? 0.6 : 1
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Row {
        id: row
        spacing: 6
        Text {
            text: root.glyph
            color: root.accent
            font.family: Theme.monoFamily
            font.pixelSize: Theme.clockPx
        }
        Text {
            text: Pomo.fmt(Pomo.shownSecs)
            color: root.timeColor
            font.family: Theme.monoFamily
            font.pixelSize: Theme.clockPx
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) root.menuRequested();
            else root.clicked();
        }
    }
}
