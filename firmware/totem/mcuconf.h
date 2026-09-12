// split-forge: enable RP2040 I2C0 for the Cirque trackpad on the right half.
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include_next <mcuconf.h>

// GP12/GP13 are an I2C0-only pair on RP2040. The board config
// (GENERIC_PROMICRO_RP2040) ships `RP_I2C_USE_I2C0 FALSE` *unguarded*, so a -D
// cannot override it and this file must. Lives in the keymap directory: there is
// no MCUCONFDIR make variable, mcuconf.h is found purely by -I order, and the
// keymap dir is -I entry #1 (the board configs are #8).
#undef  RP_I2C_USE_I2C0
#define RP_I2C_USE_I2C0 TRUE
