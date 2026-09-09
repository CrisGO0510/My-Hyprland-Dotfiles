-- █▄▀ █▀▀ █▄█ █▄▄ █ █▄░█ █▀▄ █ █▄░█ █▀▀ █▀
-- █░█ ██▄ ░█░ █▄█ █ █░▀█ █▄▀ █ █░▀█ █▄█ ▄█

local HOME     = os.getenv("HOME")
local SCR_PATH = HOME .. "/dotfiles/Scripts/hypr"

local MOD     = "SUPER"
local TERM    = "kitty"
local EDITOR  = "nvim"
local FILES   = "kitty -e lf"
local BROWSER = "firefox-nightly"

local WORKSPACE_COUNT    = 10
local SPECIAL_WORKSPACE  = "special"
local RESIZE_STEP        = 30
local MOVE_STEP          = 30


-- █░█ █▀▀ █░░ █▀█ █▀▀ █▀█ █▀
-- █▀█ ██▄ █▄▄ █▀▀ ██▄ █▀▄ ▄█

-- Estados de fullscreen segun Hyprland: 0 ninguno, 1 maximizada, 2 completa.
local FULLSCREEN_NONE = 0
local FULLSCREEN_MODE = { [1] = "maximized", [2] = "fullscreen" }

-- Con foco en una ventana a pantalla completa el movimiento direccional no
-- aplica: se cicla entre ventanas y se restaura el modo de fullscreen.
local function smartFocus(direction)
    return function()
        local win = hl.get_active_window()
        local state = win and win.fullscreen or FULLSCREEN_NONE

        if state ~= FULLSCREEN_NONE then
            local backwards = (direction == "l" or direction == "u")
            hl.dispatch(hl.dsp.window.cycle_next({ next = not backwards }))
            hl.dispatch(hl.dsp.window.fullscreen({ mode = FULLSCREEN_MODE[state], action = "set" }))
        else
            hl.dispatch(hl.dsp.focus({ direction = direction }))
        end
    end
end

-- Fijar una ventana exige que sea flotante, pero no queremos dejarla flotando
-- al desfijarla: se restaura el estado previo.
local function togglePin()
    local win = hl.get_active_window()
    if not win then return end

    local wasPinned = win.pinned

    if not win.floating and not wasPinned then
        hl.dispatch(hl.dsp.window.float({ action = "enable" }))
    end

    hl.dispatch(hl.dsp.window.pin())

    if wasPinned then
        hl.dispatch(hl.dsp.window.float({ action = "disable" }))
    end
end

-- Steam se cierra entero si se mata su ventana principal, asi que se oculta.
local STEAM_CLASS = "Steam"
local function closeWindow()
    local win = hl.get_active_window()

    if win and win.class == STEAM_CLASS then
        hl.exec_cmd("xdotool windowunmap $(xdotool getactivewindow)")
    else
        hl.dispatch(hl.dsp.window.close())
    end
end

-- Mover una ventana flotante desplaza pixeles; una tileada cambia de posicion
-- en el layout.
local function moveActiveWindow(x, y, direction)
    return function()
        local win = hl.get_active_window()

        if win and win.floating then
            hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = true }))
        else
            hl.dispatch(hl.dsp.window.move({ direction = direction }))
        end
    end
end


-- █░█░█ █ █▄░█ █▀▄ █▀█ █░█░█   ▄▀█ █▀▀ █▀▀ █ █▀█ █▄░█ █▀
-- ▀▄▀▄▀ █ █░▀█ █▄▀ █▄█ ▀▄▀▄▀   █▀█ █▄▄ █▄▄ █ █▄█ █░▀█ ▄█

hl.bind(MOD .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Color Picker" })
hl.bind(MOD .. " + Q", closeWindow, { description = "Cerrar ventana" })
hl.bind(MOD .. " + W", hl.dsp.window.float(), { description = "Alternar flotante" })
hl.bind("ALT + Return", hl.dsp.window.fullscreen(), { description = "Alternar pantalla completa" })
hl.bind(MOD .. " + ESCAPE", hl.dsp.exec_cmd(SCR_PATH .. "/lock.sh"), { description = "Bloquear pantalla" })
hl.bind(MOD .. " + SHIFT + F", togglePin, { description = "Fijar ventana" })
hl.bind(MOD .. " + Backspace", hl.dsp.exec_cmd(SCR_PATH .. "/logoutlaunch.sh"), { description = "Menu de cierre de sesion" })
hl.bind("CTRL + ALT + W",
    hl.dsp.exec_cmd("if qs list --all 2>/dev/null | grep -q quickshell/bar/shell.qml; then qs -c bar kill; else qs -c bar; fi"),
    { description = "Alternar barra Quickshell" })


-- ▄▀█ █▀█ █░░ █ █▀▀ ▄▀█ █▀▀ █ █▀█ █▄░█ █▀▀ █▀
-- █▀█ █▀▀ █▄▄ █ █▄▄ █▀█ █▄▄ █ █▄█ █░▀█ ██▄ ▄█

hl.bind(MOD .. " + T", hl.dsp.exec_cmd(TERM), { description = "Terminal" })
hl.bind(MOD .. " + E", hl.dsp.exec_cmd(FILES), { description = "Gestor de archivos" })
hl.bind(MOD .. " + C", hl.dsp.exec_cmd(EDITOR), { description = "Editor de texto" })
hl.bind(MOD .. " + F", hl.dsp.exec_cmd(BROWSER), { description = "Navegador" })
hl.bind("CTRL + SHIFT + Escape",
    hl.dsp.exec_cmd("kitty -e btop || kitty -e htop || kitty -e top"),
    { description = "Monitor del sistema" })

hl.bind(MOD .. " + A", hl.dsp.exec_cmd("pkill -x rofi || " .. SCR_PATH .. "/rofilaunch.sh d"), { description = "Lanzador de aplicaciones" })
hl.bind(MOD .. " + Tab", hl.dsp.exec_cmd("pkill -x rofi || " .. SCR_PATH .. "/rofilaunch.sh w"), { description = "Cambiar de ventana" })


-- █▀▄▀█ █░█ █░░ ▀█▀ █ █▀▄▀█ █▀▀ █▀▄ █ ▄▀█
-- █░▀░█ █▄█ █▄▄ ░█░ █ █░▀░█ ██▄ █▄▀ █ █▀█

-- `locked` permite usarlos con la pantalla bloqueada; `repeating`, mantener pulsado.
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(SCR_PATH .. "/volumecontrol.sh -o m"), { locked = true, description = "Silenciar audio" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(SCR_PATH .. "/volumecontrol.sh -i m"), { locked = true, description = "Silenciar microfono" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(SCR_PATH .. "/volumecontrol.sh -o d"), { locked = true, repeating = true, description = "Bajar volumen" })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(SCR_PATH .. "/volumecontrol.sh -o i"), { locked = true, repeating = true, description = "Subir volumen" })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Reproducir / pausar" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Reproducir / pausar" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Siguiente pista" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Pista anterior" })


-- █▀ █▀▀ █▀█ █ █▀█ ▀█▀ █▀
-- ▄█ █▄▄ █▀▄ █ █▀▀ ░█░ ▄█

hl.bind(MOD .. " + SHIFT + S", hl.dsp.exec_cmd(SCR_PATH .. "/screenshot.sh sf"), { description = "Captura parcial (pantalla congelada)" })
hl.bind("Print", hl.dsp.exec_cmd(SCR_PATH .. "/screenshot.sh p"), { description = "Captura de todos los monitores" })

hl.bind(MOD .. " + V", hl.dsp.exec_cmd("pkill -x rofi || " .. SCR_PATH .. "/cliphist.sh c"), { description = "Portapapeles" })
hl.bind(MOD .. " + SHIFT + V", hl.dsp.exec_cmd("pkill -x rofi || " .. SCR_PATH .. "/cliphist.sh"), { description = "Gestor del portapapeles" })
hl.bind(MOD .. " + space", hl.dsp.exec_cmd(SCR_PATH .. "/keyboardswitch.sh"), { description = "Cambiar distribucion de teclado" })
hl.bind(MOD .. " + slash", hl.dsp.exec_cmd("pkill -x rofi || " .. SCR_PATH .. "/keybinds_hint.sh c"), { description = "Ayuda de atajos" })

hl.bind(MOD .. " + N", hl.dsp.exec_cmd("qs -c bar ipc call notifs panel"), { description = "Panel de notificaciones" })
hl.bind(MOD .. " + SHIFT + N", hl.dsp.exec_cmd("qs -c bar ipc call notifs toggleDnd"), { description = "Alternar No molestar" })
hl.bind(MOD .. " + P", hl.dsp.exec_cmd("qs -c bar ipc call pomo primary"), { description = "Pomodoro: arrancar / pausar / confirmar fase" })


-- █▀▀ █▀█ █▀▀ █▀█   ░   █▀▄▀█ █▀█ █░█ █ █▀▄▀█ █ █▀▀ █▄░█ ▀█▀ █▀█
-- █▀░ █▄█ █▄▄ █▄█   ▄   █░▀░█ █▄█ ▀▄▀ █ █░▀░█ █ ██▄ █░▀█ ░█░ █▄█

hl.bind(MOD .. " + H", smartFocus("l"), { description = "Foco a la izquierda" })
hl.bind(MOD .. " + J", smartFocus("d"), { description = "Foco abajo" })
hl.bind(MOD .. " + K", smartFocus("u"), { description = "Foco arriba" })
hl.bind(MOD .. " + L", smartFocus("r"), { description = "Foco a la derecha" })

hl.bind(MOD .. " + SHIFT + L", hl.dsp.window.resize({ x = RESIZE_STEP, y = 0, relative = true }), { repeating = true, description = "Ensanchar ventana" })
hl.bind(MOD .. " + SHIFT + H", hl.dsp.window.resize({ x = -RESIZE_STEP, y = 0, relative = true }), { repeating = true, description = "Estrechar ventana" })
hl.bind(MOD .. " + SHIFT + K", hl.dsp.window.resize({ x = 0, y = -RESIZE_STEP, relative = true }), { repeating = true, description = "Encoger ventana" })
hl.bind(MOD .. " + SHIFT + J", hl.dsp.window.resize({ x = 0, y = RESIZE_STEP, relative = true }), { repeating = true, description = "Agrandar ventana" })

hl.bind(MOD .. " + SHIFT + CTRL + H", moveActiveWindow(-MOVE_STEP, 0, "l"), { description = "Mover ventana a la izquierda" })
hl.bind(MOD .. " + SHIFT + CTRL + L", moveActiveWindow(MOVE_STEP, 0, "r"), { description = "Mover ventana a la derecha" })
hl.bind(MOD .. " + SHIFT + CTRL + K", moveActiveWindow(0, -MOVE_STEP, "u"), { description = "Mover ventana arriba" })
hl.bind(MOD .. " + SHIFT + CTRL + J", moveActiveWindow(0, MOVE_STEP, "d"), { description = "Mover ventana abajo" })

hl.bind(MOD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Arrastrar ventana" })
hl.bind(MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Redimensionar ventana" })

hl.bind(MOD .. " + M", hl.dsp.layout("togglesplit"), { description = "Alternar orientacion del split" })


-- █░█░█ █▀█ █▀█ █▄▀ █▀ █▀█ ▄▀█ █▀▀ █▀▀ █▀
-- ▀▄▀▄▀ █▄█ █▀▄ █░█ ▄█ █▀▀ █▀█ █▄▄ ██▄ ▄█

for i = 1, WORKSPACE_COUNT do
    local key = i % WORKSPACE_COUNT -- el workspace 10 vive en la tecla 0

    hl.bind(MOD .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Ir al workspace " .. i })
    hl.bind(MOD .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), { description = "Mover ventana al workspace " .. i })
    hl.bind(MOD .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), { description = "Mover ventana al workspace " .. i .. " en silencio" })
end

hl.bind(MOD .. " + CTRL + L", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace siguiente" })
hl.bind(MOD .. " + CTRL + H", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace anterior" })
hl.bind(MOD .. " + CTRL + J", hl.dsp.focus({ workspace = "empty" }), { description = "Primer workspace vacio" })

hl.bind(MOD .. " + CTRL + ALT + L", hl.dsp.window.move({ workspace = "r+1", follow = true }), { description = "Mover ventana al workspace siguiente" })
hl.bind(MOD .. " + CTRL + ALT + H", hl.dsp.window.move({ workspace = "r-1", follow = true }), { description = "Mover ventana al workspace anterior" })

hl.bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspace siguiente (rueda)" })
hl.bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspace anterior (rueda)" })

hl.bind(MOD .. " + S", hl.dsp.workspace.toggle_special(SPECIAL_WORKSPACE), { description = "Alternar workspace especial" })
hl.bind(MOD .. " + ALT + S", hl.dsp.window.move({ workspace = SPECIAL_WORKSPACE, follow = false }), { description = "Mover ventana al workspace especial" })


-- ▀█▀ ▄▀█ █▀█ ▄▀█   █▀▄ █▀▀ █░░   █▀█ █▀█ █▀█ ▀█▀ ▄▀█ ▀█▀ █ █░░
-- ░█░ █▀█ █▀▀ █▀█   █▄▀ ██▄ █▄▄   █▀▀ █▄█ █▀▄ ░█░ █▀█ ░█░ █ █▄▄
--
-- logind ignora la tapa (ver Scripts/installer/lid-behavior.sh) para que la
-- sesion siga viva y accesible por SSH. Aca solo apagamos el panel interno:
-- el resto de monitores y todos los procesos siguen igual.
-- `locked` es necesario para que tambien actue con la pantalla bloqueada.

local LID_SWITCH     = "Lid Switch"
local INTERNAL_PANEL = "eDP-1"

hl.bind("switch:on:" .. LID_SWITCH, hl.dsp.dpms("off", INTERNAL_PANEL),
    { locked = true, description = "Apagar panel interno al cerrar la tapa" })
hl.bind("switch:off:" .. LID_SWITCH, hl.dsp.dpms("on", INTERNAL_PANEL),
    { locked = true, description = "Encender panel interno al abrir la tapa" })
