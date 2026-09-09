pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Pomodoro 50/10. Todo el estado y el único contador viven aquí; las ventanas
// solo pintan. La regla que gobierna el resto: el reloj solo corre después de
// un clic, así que ninguna fase arranca sola, ni el trabajo ni el descanso.
Singleton {
    id: root

    // el ciclo entero se cambia desde estas dos líneas
    readonly property int workSecs:  50 * 60
    readonly property int breakSecs: 10 * 60

    property string phase:  "work"   // "work" | "break"
    property string status: "idle"   // "idle" | "running" | "paused" | "done"
    property int remaining: root.workSecs

    function other(p)  { return p === "work" ? "break" : "work"; }
    function secsOf(p) { return p === "work" ? root.workSecs : root.breakSecs; }

    // En "done" `phase` sigue apuntando a la fase que acaba de terminar: es
    // primary() quien la voltea. La UI pinta estas dos en su lugar para
    // adelantarse a lo que viene, de modo que el clic confirme exactamente lo
    // que se está viendo.
    readonly property string shownPhase: status === "done" ? other(phase) : phase
    readonly property int    shownSecs:  status === "done" ? secsOf(other(phase)) : remaining

    function fmt(s) {
        var m = Math.floor(s / 60), r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    function start(p) {
        root.phase = p;
        root.remaining = secsOf(p);
        root.status = "running";
    }

    // clic izquierdo y keybind: arranca, pausa, reanuda o confirma la fase
    function primary() {
        if (root.status === "idle")         root.start("work");
        else if (root.status === "running") root.status = "paused";
        else if (root.status === "paused")  root.status = "running";
        else if (root.status === "done")    root.start(other(root.phase));
    }

    // reset y skip dejan el tiempo cargado pero quieto: cualquier camino que
    // ponga tiempo nuevo en el marcador espera un clic. En reposo son inocuas
    // porque el IPC las expone y un keybind puede dispararlas ahí.
    function reset() {
        if (root.status === "idle") return;
        root.remaining = secsOf(root.phase);
        root.status = "paused";
    }
    function skip() {
        if (root.status === "idle") return;
        root.phase = other(root.phase);
        root.remaining = secsOf(root.phase);
        root.status = "paused";
    }
    function stop() {
        root.status = "idle";
        root.phase = "work";
        root.remaining = root.workSecs;
    }

    // Se descuenta tick a tick en vez de derivarlo de una hora de fin: así la
    // suspensión congela el bloque en lugar de comérselo. La deriva del Timer
    // a lo largo de 3000 ticks son unos segundos, irrelevantes para esto.
    Timer {
        interval: 1000
        repeat: true
        running: root.status === "running"
        onTriggered: {
            if (root.remaining > 1) { root.remaining--; return; }
            root.remaining = 0;
            root.status = "done";     // la fase no gira hasta el clic
            root.notifyPhase();
        }
    }

    // Entra por el servidor de notificaciones propio (Notifs.qml), así que el
    // modo No molestar lo silencia solo: ahí queda el parpadeo de la isla.
    Process { id: notifyProc }
    function notifyPhase() {
        var toBreak = root.phase === "work";
        notifyProc.command = ["notify-send", "-a", "Pomodoro",
            toBreak ? "Fin del bloque"          : "Fin del descanso",
            toBreak ? "10 minutos de descanso"  : "50 minutos de trabajo"];
        notifyProc.running = true;
    }
}
