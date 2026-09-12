#pragma once

// The host matches the Raw HID interface on usage page 0xFF60 / usage 0x61.
// These are the QMK defaults, so no override is required. They are documented here
// (commented) only so the host and firmware definitions stay visibly in sync.
//
// #define RAW_USAGE_PAGE 0xFF60
// #define RAW_USAGE_ID   0x61

// ---------------------------------------------------------------------------
// Cirque 40 mm trackpad on the right half — see plan/cirque-trackpad.md
// ---------------------------------------------------------------------------

// These THREE defines must travel together. The board config
// (platforms/chibios/boards/GENERIC_PROMICRO_RP2040/configs/config.h) supplies
// *guarded* fallbacks I2CD1 / GP2 / GP3 — and GP2 and GP3 are Totem matrix
// columns 4 and 2. This file is force-included before the board's, so ours win;
// drop any one of them and I2C silently drives two live matrix columns.
#define I2C_DRIVER   I2CD0
#define I2C1_SDA_PIN GP12  // QMK uses the I2C1_* names whichever peripheral is selected
#define I2C1_SCL_PIN GP13

#define SPLIT_POINTING_ENABLE
#define POINTING_DEVICE_RIGHT

// Pad is mounted a quarter-turn off. Derived from observed behaviour with no
// rotation set: finger right gave pointer up, finger up gave pointer left.
// 270 maps (x,y)->(-y,x), which corrects all four directions; no invert needed.
#define POINTING_DEVICE_ROTATION_270

// Explicit, not required: the cirque driver already defaults this to 10ms, and
// it wins on its own because pointing_device.h includes cirque_pinnacle.h (:54)
// *before* its own SPLIT_POINTING_ENABLE fallback of 1ms (:130-134), so the
// fallback never fires in a cirque build. Pinned anyway so the split link's
// traffic budget -- shared with the per-key 0xCC 0x02 reports -- is stated
// rather than inherited from driver include order.
#define POINTING_DEVICE_TASK_THROTTLE_MS 10

// Relative mode is load-bearing, not a preference: absolute-mode tap works only
// on the master side, relative-mode tap works on both sides of a split. The pad
// is the secondary side whenever the LEFT half is the one plugged into USB.
#define CIRQUE_PINNACLE_POSITION_MODE CIRQUE_PINNACLE_RELATIVE_MODE
#define CIRQUE_PINNACLE_TAP_ENABLE
#define CIRQUE_PINNACLE_SECONDARY_TAP_ENABLE

// Left at defaults on purpose: CIRQUE_PINNACLE_ADDR (0x2A),
// CIRQUE_PINNACLE_DIAMETER_MM (40), CIRQUE_PINNACLE_ATTENUATION (4X, correct for
// a flat overlay). CIRQUE_PINNACLE_SKIP_SENSOR_CHECK stays undefined.
