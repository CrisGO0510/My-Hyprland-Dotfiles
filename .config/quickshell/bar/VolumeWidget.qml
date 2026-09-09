import QtQuick
import Quickshell.Services.Pipewire

MouseArea {
    id: root
    // necesario para que volume/muted sean válidos
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }
    PwObjectTracker { objects: Pipewire.defaultAudioSource ? [Pipewire.defaultAudioSource] : [] }

    // Este widget hace de OSD: los binds de volumen ya no notifican, asoman
    // el tooltip un momento. Se apaga en los monitores sin foco.
    property bool osdEnabled: true

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int pct: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    readonly property string sinkText: muted ? "silenciado" : "volumen " + pct + "%"
    readonly property string micText: micMuted ? "micro silenciado" : "micro activo"

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    onClicked: if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    onWheel: (wheel) => {
        if (!sink || !sink.audio) return;
        const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + step));
    }

    function volIcon(p, m) {
        if (m || p === 0) return "󰝟";   // silencio
        if (p < 34) return "󰕿";          // bajo
        if (p < 67) return "󰖀";          // medio
        return "󰕾";                       // alto
    }

    // █▀█ █▀ █▀▄
    // █▄█ ▄█ █▄▀

    // que aviso pidio el ultimo cambio; el texto se lee vivo, no congelado,
    // porque al disparar el handler la propiedad todavia trae el valor previo
    property bool osdMic: false
    // Pipewire tarda en asentar sus valores: sin esto la barra saluda con un
    // tooltip cada vez que arranca.
    property bool armed: false
    Timer { interval: 2000; running: true; onTriggered: root.armed = true }
    Timer { id: osd; interval: 1400 }

    function showOsd(mic) {
        if (!root.armed || !root.osdEnabled) return;
        root.osdMic = mic;
        osd.restart();
    }

    onPctChanged: showOsd(false)
    onMutedChanged: showOsd(false)
    onMicMutedChanged: showOsd(true)

    Text {
        id: icon
        text: root.volIcon(root.pct, root.muted)
        color: root.muted ? Theme.muted : Theme.textBase
        font.family: Theme.monoFamily
        font.pixelSize: Theme.clockPx
    }

    // el OSD no espera; pasando el raton si, para no parpadear de paso
    property bool hoverTip: false
    Timer { id: hoverDelay; interval: 150; onTriggered: root.hoverTip = true }

    HoverHandler {
        id: hh
        onHoveredChanged: {
            if (hovered) {
                hoverDelay.restart();
            } else {
                hoverDelay.stop();
                root.hoverTip = false;
            }
        }
    }

    NeonTooltipPopup {
        anchorItem: root
        visible: root.hoverTip || osd.running
        text: osd.running && root.osdMic ? root.micText : root.sinkText
    }
}
