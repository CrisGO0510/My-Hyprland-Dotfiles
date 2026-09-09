import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Component { Bar {} }
    }

    // popups de notificación en pantalla (servidor de notificaciones nativo)
    NotificationToasts {}

    // IPC para los binds de Hyprland (mod+N / mod+Shift+N)
    IpcHandler {
        target: "notifs"
        function toggleDnd(): void { Notifs.toggleDnd() }
        function panel(): void { Notifs.panelRequested() }
    }

    // IPC del pomodoro (mod+P)
    IpcHandler {
        target: "pomo"
        function primary(): void { Pomo.primary() }
        function reset(): void { Pomo.reset() }
        function skip(): void { Pomo.skip() }
        function stop(): void { Pomo.stop() }
    }
}
