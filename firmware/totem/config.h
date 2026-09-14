#pragma once

// The host matches the Raw HID interface on usage page 0xFF60 / usage 0x61.
// These are the QMK defaults, so no override is required. They are documented here
// (commented) only so the host and firmware definitions stay visibly in sync.
//
// #define RAW_USAGE_PAGE 0xFF60
// #define RAW_USAGE_ID   0x61

// ---------------------------------------------------------------------------
// Split link: HALF-DUPLEX on D7/GP1  (NOT the stock Totem configuration)
// ---------------------------------------------------------------------------
// D6's path is dead on this board - pin, trace, TRRS jack pin or cable
// conductor; never isolated, and it doesn't matter. Full duplex needs BOTH D6
// and D7 in BOTH roles (the master sends on one and listens on the other, the
// slave does the reverse), so one dead line kills the link whichever half is
// plugged into USB. Half duplex uses a single wire.
//
// Safe because the Totem's split runs on the RP2040 PIO driver
// (split.serial.driver = "vendor"), which will put a UART on any GPIO and needs
// no external pull-up.
//
// This file is force-included AFTER the keyboard-level config.h, so the stock
// full-duplex settings are undef'd here rather than edited upstream - that is
// what keeps firmware/totem/ a keymap overlay instead of a fork.
//
// Do NOT restore the full-duplex lines. FULL_DUPLEX, RX_PIN and PIN_SWAP are
// full-duplex-only concepts and must all end up undefined.
#undef  SERIAL_USART_FULL_DUPLEX
#undef  SERIAL_USART_RX_PIN
#undef  SERIAL_USART_PIN_SWAP
#undef  SERIAL_USART_TX_PIN
#define SERIAL_USART_TX_PIN GP1
