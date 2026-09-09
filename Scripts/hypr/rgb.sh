#!/usr/bin/env bash

# Control de los LEDs RGB: placa Gigabyte B450M (chip IT8297, via USB/HID) y
# grafica RTX 4070 Eagle (via I2C).
#
#   rgb.sh on    encendidos en ON_COLOR
#   rgb.sh off   apagados
#
# Se invoca desde tres sitios, para que los LEDs solo esten encendidos dentro
# de la sesion grafica:
#   - rgb-off.service     apagado al arrancar, antes de entrar
#   - hyprland.start      encendido al entrar en la sesion
#   - hyprland.shutdown   apagado al volver a la tty
#
# La Eagle entra y sale del bus: hay ratos en los que OpenRGB la detecta y
# ratos en los que no existe, en el mismo arranque y sin tocar nada. La causa
# probable es que ese bus I2C lo comparte con el DDC de los monitores. Por eso
# no se le escribe a ciegas: se sondea hasta pillarla en una ventana buena.
#
# La placa, en cambio, siempre responde a la primera.

set -u

OPENRGB="/usr/bin/openrgb"

# Coincidencia por subcadena: OpenRGB necesita 3 caracteres o mas.
BOARD="B450M"
GPU="Eagle"

# Color de encendido, en hexadecimal RRGGBB. El magenta del borde activo del
# tema. Cambialo aqui y afecta a placa y grafica a la vez.
ON_COLOR="c74ded"

# Hasta minuto y medio esperando una ventana de la grafica.
GPU_RETRIES=10
GPU_RETRY_WAIT=6

# Escribe en la grafica, reintentando hasta que OpenRGB la vea.
gpu_write() {
    local _
    for _ in $(seq "$GPU_RETRIES"); do
        if "$OPENRGB" --list-devices 2>/dev/null | grep -q "$GPU"; then
            "$OPENRGB" --device "$GPU" "$@" >/dev/null 2>&1
            return 0
        fi
        sleep "$GPU_RETRY_WAIT"
    done
    return 1
}

# La placa tiene modo Static, que graba el color en el controlador y aguanta
# sin OpenRGB corriendo. La grafica solo ofrece Direct.
case ${1:-} in
    on)
        # Modo Direct con color explicito y brillo al maximo. Los modos de
        # efecto (Color Cycle, Wave...) se aplican sin error en la Eagle pero
        # no producen luz, asi que no sirven. Y el brillo hay que mandarlo
        # siempre: al apagar queda a cero y cambiar de modo no lo restaura.
        "$OPENRGB" --device "$BOARD" --mode direct --color "$ON_COLOR" --brightness 100 >/dev/null 2>&1
        gpu_write --mode direct --color "$ON_COLOR" --brightness 100
        ;;
    off)
        "$OPENRGB" --device "$BOARD" --mode static --color 000000 >/dev/null 2>&1
        gpu_write --mode direct --color 000000
        ;;
    *)
        echo "uso: ${0##*/} {on|off}" >&2
        exit 1
        ;;
esac

# Que la grafica no aparezca no es un fallo: el servicio no debe quedar en
# estado failed por eso.
exit 0
