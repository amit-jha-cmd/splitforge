// split-forge: broadcast the active QMK layer to the host over Raw HID.
//
// Pattern adapted verbatim from qmk-hid-host (https://github.com/zzeneg/qmk-hid-host).
// Merge into your Totem Vial keymap in one of two ways:
//   (A) paste the functions below into your keymap's keymap.c, or
//   (B) keep this file next to keymap.c and add `SRC += keymap_broadcast.c` to rules.mk.
//
// IMPORTANT: we only ever call raw_hid_send(). We never define raw_hid_receive() —
// Vial/VIA owns it, and overriding it breaks Vial (vial-qmk issue #538). Send-only.
//
// Protocol (keep in sync with docs/PROTOCOL.md):
//   report[0] = 0xCC  magic "relay from device"
//   report[1] = 0x01  message type LAYER: report[2] = active layer (get_highest_layer)
//   report[1] = 0x02  message type KEY:   report[2]=row, report[3]=col, report[4]=pressed(1/0)

#include QMK_KEYBOARD_H
#include "raw_hid.h"
#include <string.h>

#ifndef RAW_EPSIZE
#    define RAW_EPSIZE 32
#endif

#define SF_MAGIC 0xCC
#define SF_MSG_LAYER 0x01
#define SF_MSG_KEY 0x02

static void sf_send_layer(uint8_t layer) {
    uint8_t report[RAW_EPSIZE];
    memset(report, 0, sizeof(report));
    report[0] = SF_MAGIC;
    report[1] = SF_MSG_LAYER;
    report[2] = layer;
    raw_hid_send(report, sizeof(report));
}

layer_state_t layer_state_set_user(layer_state_t state) {
    sf_send_layer(get_highest_layer(state));
    return state;
}

void keyboard_post_init_user(void) {
    // Broadcast the current layer once at boot, so a host that is already listening learns
    // the starting layer without waiting for the first change. (A host that starts later
    // still catches up on the next layer change.)
    sf_send_layer(get_highest_layer(layer_state));
}

// Hook the keyboard-level process_record_kb (NOT process_record_user — a Vial keymap already
// defines that) and call through to the keymap's process_record_user, so all its behaviour is kept.
bool process_record_kb(uint16_t keycode, keyrecord_t *record) {
    // Broadcast the physical key's matrix position on press/release so the host overlay can
    // highlight it. Skip combos / virtual events, which use a sentinel matrix position.
    if (record->event.key.row < MATRIX_ROWS && record->event.key.col < MATRIX_COLS) {
        uint8_t report[RAW_EPSIZE];
        memset(report, 0, sizeof(report));
        report[0] = SF_MAGIC;
        report[1] = SF_MSG_KEY;
        report[2] = record->event.key.row;
        report[3] = record->event.key.col;
        report[4] = record->event.pressed ? 1 : 0;
        raw_hid_send(report, sizeof(report));
    }
    return process_record_user(keycode, record); // preserve the keymap's own handler
}
