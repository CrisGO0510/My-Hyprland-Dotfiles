import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight

    // margen interno lateral
    readonly property int pad: 6

    // El OSD de volumen solo asoma en el monitor con foco.
    readonly property bool focused: Hyprland.focusedMonitor !== null
                                    && modelData.name === Hyprland.focusedMonitor.name

    // IZQUIERDA — workspaces
    Island {
        id: leftIsland
        anchors { left: parent.left; leftMargin: bar.pad; verticalCenter: parent.verticalCenter }
        WorkspacesWidget {}
    }

    // Pomodoro: cápsula propia a la derecha de los workspaces
    Island {
        id: pomoIsland
        anchors { left: leftIsland.right; leftMargin: bar.pad; verticalCenter: parent.verticalCenter }
        PomodoroWidget { id: pomo }
    }

    // CENTRO — reloj
    Island {
        id: centerIsland
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
        ClockWidget { id: clock }
    }

    // DERECHA — música, red, volumen, wifi, teclado, batería, tray, stats
    // (las acciones de power viven dentro del StatsPopup, abierto por el botón 󰓅)
    Island {
        id: rightIsland
        anchors { right: parent.right; rightMargin: bar.pad; verticalCenter: parent.verticalCenter }
        // Los widgets van directos: Island ya los coloca en su Row interno (centrado).
        MusicWidget    { id: music }
        NetspeedWidget {}
        VolumeWidget   { osdEnabled: bar.focused }
        KeyboardWidget {}
        BatteryWidget  {}
        TrayWidget     {}
        StatsWidget    { id: stats }
    }

    // El panel se ancla a la isla derecha (Rectangle); se posiciona a la derecha bajo la barra
    StatsPopup  { id: statsPopup; anchorItem: rightIsland }
    Connections { target: stats; function onClicked() { statsPopup.visible = !statsPopup.visible } }

    CalendarPopup { id: calPopup; anchorItem: centerIsland }
    Connections { target: clock; function onClicked() { calPopup.visible = !calPopup.visible } }

    PomodoroPopup { id: pomoPopup; anchorItem: pomoIsland }
    Connections { target: pomo
        function onClicked() { Pomo.primary() }
        function onMenuRequested() { pomoPopup.visible = !pomoPopup.visible } }

    MusicPopup  { id: musicPopup; anchorItem: rightIsland }
    Connections { target: music; function onClicked() { musicPopup.visible = !musicPopup.visible } }

    // abrir el panel de stats desde el bind mod+N (solo en el monitor con foco)
    Connections {
        target: Notifs
        function onPanelRequested() {
            if (Hyprland.focusedMonitor && bar.modelData.name === Hyprland.focusedMonitor.name)
                statsPopup.visible = !statsPopup.visible;
        }
    }
}
