pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int  ramPct: 0
    property int  cpuPct: 0
    property int  cpuTemp: 0
    property real netDown: 0   // KB/s
    property real netUp: 0     // KB/s
    property int  uptimeSec: 0

    // --- GPU (NVIDIA) ---
    // hasGpu se queda en false si nvidia-smi no existe o muere al arrancar;
    // el panel usa eso para no dibujar la card de GPU en máquinas sin ella.
    property bool   hasGpu: false
    property string gpuName: ""
    property int    gpuPct: 0
    property int    gpuTemp: 0
    property int    vramUsedMB: 0
    property int    vramTotalMB: 0
    readonly property int vramPct: vramTotalMB > 0
        ? Math.round(vramUsedMB / vramTotalMB * 100) : 0

    // La GPU no expone unidades individuales como los núcleos del CPU, así que
    // el gráfico de barras del panel mide tiempo, no paralelismo: una barra por
    // muestra, ~1 min de historial. Arranca en ceros para que el ancho de las
    // barras no cambie mientras se llena.
    readonly property int gpuHistoryLen: 30
    property var gpuHistory: new Array(root.gpuHistoryLen).fill(0)

    // --- estado interno para deltas ---
    property var _prevCpu: null      // [idle, total]
    property var _prevNet: null      // [rx, tx]
    property double _prevNetT: 0

    property var coresPct: []        // [%, %, ...] uno por núcleo
    property var _prevCores: ({})    // idx -> [idle, total]

    // El sensor de CPU depende de la máquina (k10temp en AMD, coretemp en Intel)
    // y el índice de hwmon no es estable entre arranques, así que se resuelve al
    // arrancar. thermal_zone0 queda como último recurso: en algunas placas es
    // acpitz y reporta una temperatura que no es la del CPU.
    readonly property var tempSensors: ["k10temp", "zenpower", "coretemp", "cpu_thermal"]
    property string tempPath: "/sys/class/thermal/thermal_zone0/temp"

    // FileView estáticos con blockLoading: lectura síncrona sin subprocesos.
    // /proc y /sys son diminutos => el bloqueo es despreciable.
    FileView { id: memFile;  path: "/proc/meminfo"; blockLoading: true; printErrors: false }
    FileView { id: statFile; path: "/proc/stat";    blockLoading: true; printErrors: false }
    FileView { id: tempFile; path: root.tempPath; blockLoading: true; printErrors: false }
    FileView { id: netFile;  path: "/proc/net/dev"; blockLoading: true; printErrors: false }
    FileView { id: upFile;   path: "/proc/uptime";  blockLoading: true; printErrors: false }
    // Una instancia nueva por sonda: reasignar `path` en un FileView existente no
    // recarga de forma sincrona — text() sigue devolviendo el primer archivo leido,
    // asi que la comparacion de abajo fallaba siempre y caia al fallback acpitz.
    Component {
        id: probeComponent
        FileView { blockLoading: true; printErrors: false }
    }

    // Busca el primer hwmon cuyo nombre esté en tempSensors, por orden de
    // preferencia. Sólo corre una vez, al inicio.
    function resolveTempPath() {
        for (const wanted of root.tempSensors) {
            for (let i = 0; i < 16; i++) {
                const dir = "/sys/class/hwmon/hwmon" + i;
                const fv = probeComponent.createObject(root);
                if (!fv) continue;
                let name = "";
                try { fv.path = dir + "/name"; name = fv.text().trim(); } catch (e) {}
                fv.destroy();
                if (name === wanted) {
                    root.tempPath = dir + "/temp1_input";
                    return;
                }
            }
        }
    }

    function refresh() {
        memFile.reload(); statFile.reload(); tempFile.reload(); upFile.reload();
        // RAM desde /proc/meminfo
        try {
            const mem = memFile.text();
            const total = parseInt(mem.match(/MemTotal:\s+(\d+)/)[1]);
            const avail = parseInt(mem.match(/MemAvailable:\s+(\d+)/)[1]);
            root.ramPct = Math.round((total - avail) / total * 100);
        } catch (e) {}

        // CPU% desde /proc/stat (línea agregada "cpu ...")
        try {
            const stat = statFile.text();
            const parts = stat.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = parts[3] + (parts[4] || 0);
            const tot = parts.reduce((a, b) => a + b, 0);
            if (root._prevCpu) {
                const dIdle = idle - root._prevCpu[0];
                const dTot = tot - root._prevCpu[1];
                if (dTot > 0) root.cpuPct = Math.round((1 - dIdle / dTot) * 100);
            }
            root._prevCpu = [idle, tot];
        } catch (e) {}

        // CPU por núcleo: líneas cpu0, cpu1, ... de /proc/stat
        try {
            const cores = [];
            const next = {};
            for (const line of statFile.text().split("\n")) {
                const m = line.match(/^cpu(\d+)\s+(.*)/);
                if (!m) continue;
                const idx = parseInt(m[1]);
                const p = m[2].trim().split(/\s+/).map(Number);
                const idle = p[3] + (p[4] || 0);
                const tot = p.reduce((a, b) => a + b, 0);
                next[idx] = [idle, tot];
                if (root._prevCores[idx]) {
                    const di = idle - root._prevCores[idx][0];
                    const dt = tot - root._prevCores[idx][1];
                    cores[idx] = dt > 0 ? Math.round((1 - di / dt) * 100) : 0;
                } else cores[idx] = 0;
            }
            root._prevCores = next;
            root.coresPct = cores;
        } catch (e) {}

        // Temp CPU desde el sensor resuelto en resolveTempPath()
        try {
            const tRaw = tempFile.text();
            root.cpuTemp = Math.round(parseInt(tRaw) / 1000);
        } catch (e) {}

        // uptime
        try {
            const up = upFile.text();
            root.uptimeSec = Math.round(parseFloat(up.split(" ")[0]));
        } catch (e) {}
    }

    function refreshNet() {
        netFile.reload();
        try {
            const dev = netFile.text();
            let rx = 0, tx = 0;
            for (const line of dev.split("\n")) {
                if (!line.includes(":")) continue;
                const name = line.split(":")[0].trim();
                if (name === "lo") continue;
                const cols = line.split(":")[1].trim().split(/\s+/).map(Number);
                rx += cols[0]; tx += cols[8];
            }
            const tNow = root.uptimeSec; // segundos monotónicos aprox.
            if (root._prevNet && tNow > root._prevNetT) {
                const dt = tNow - root._prevNetT;
                root.netDown = (rx - root._prevNet[0]) / 1024 / dt;
                root.netUp = (tx - root._prevNet[1]) / 1024 / dt;
            }
            root._prevNet = [rx, tx];
            root._prevNetT = tNow;
        } catch (e) {}
    }

    // nvidia-smi en modo loop (-l 2): un unico proceso persistente que emite una
    // línea cada 2s, en vez de un fork+exec por refresco. El resto de métricas
    // salen de /proc, pero el driver propietario no publica utilización ni VRAM
    // en sysfs, así que aquí no hay alternativa sin subproceso.
    Process {
        id: gpuProc
        running: true
        command: ["nvidia-smi",
                  "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu",
                  "--format=csv,noheader,nounits", "-l", "2"]
        stdout: SplitParser { onRead: data => root.parseGpu(data) }
        onExited: {
            // Si nunca llegó un dato es que no hay GPU NVIDIA: no se reintenta.
            // Si ya la había, el proceso murió por un hipo del driver (suspend,
            // recarga de módulos) y vale la pena volver a levantarlo.
            if (root.hasGpu) gpuRetry.restart();
        }
    }
    Timer { id: gpuRetry; interval: 10000; onTriggered: gpuProc.running = true }

    function parseGpu(line) {
        const f = line.split(",").map(s => s.trim());
        if (f.length < 5) return;
        const util = parseInt(f[1]), used = parseInt(f[2]),
              total = parseInt(f[3]), temp = parseInt(f[4]);
        // "[N/A]" en cualquier campo numérico => línea inservible, se descarta.
        if (isNaN(util) || isNaN(used) || isNaN(total) || isNaN(temp)) return;

        root.gpuName = f[0];
        root.gpuPct = util;
        root.vramUsedMB = used;
        root.vramTotalMB = total;
        root.gpuTemp = temp;

        const h = root.gpuHistory.slice(1);
        h.push(util);
        root.gpuHistory = h;   // reasignar el array es lo que notifica al binding

        root.hasGpu = true;
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: root.refreshNet() }
    Component.onCompleted: { resolveTempPath(); refresh(); refreshNet(); }
}
