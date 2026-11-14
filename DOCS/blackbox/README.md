# Black box: motorcycle data logger for ThrottleIQ

Idea (not built, uncommitted draft). An ESP32 in the XPulse 200 4V Pro diagnostic port logs RPM, speed and throttle twice a second to an SD card, then batch-uploads to a Supabase table that ThrottleIQ graphs. This also feeds the Right to Repair campaign (`labs/bd-moto-right-to-repair`) with real diagnostic data.

**Merge with InGeo:** no project, file or repo called InGeo exists on this machine or under the-abraar / blankframe-tech (searched 2026-11-14). Add its notes here once it is identified. Nearest name: `Indriyo` (ADAS, archived).

## Biggest risk: the protocol is unconfirmed

The original plan assumed CAN. Nobody has verified it. Hero has used K-line (ISO 14230) on older bikes (HIDI tool manual: CAN, LIN or K-line; Xtreme uses K-line). The bike uses a 6-pin Hero connector, not the 16-pin car port, so car pinouts do not apply. Treat K-line as at least as likely as CAN. **Do not buy the SN65HVD230 until tested.** See `protocol-discovery.md`.

If K-line: single wire, 10.4 kbaud, 12 V logic, ISO 9141-2 / 14230 (KWP2000) with slow/fast init, and an L9637D-style transceiver instead of TWAI.

## Original plan (CAN version)

### BOM (BD prices, estimated)

| Part | Purpose | Cost | Source |
|---|---|---|---|
| ESP32 NodeMCU 38-pin | processor | ৳550-650 | TechShopBD / Daraz |
| SN65HVD230 CAN module | 3.3 V CAN transceiver | ৳350-790 | RoboticsBD / Daraz |
| LM2596 buck converter | 12 V to 5 V | ৳120-150 | local |
| MicroSD module | offline buffer | ৳150-200 | local |
| Euro5 6-pin to 16-pin cable | diagnostic port | ৳650-1,200 | Daraz |
| OBD2 pigtail | wire the 16-pin end | ৳300 | Daraz |

The cable and the four-wire pinout (12 V, GND, CAN-H, CAN-L) are unverified.

### Wiring

- Power: 12 V and GND to LM2596 IN+/IN-. Set OUT+ to exactly 5.0 V with a multimeter first. OUT+ to ESP32 VIN, OUT- to GND.
- CAN: ESP32 3V3/GND to the transceiver. Original had CTX 21, CRX 22. **Move these**: 21/22 are the default I2C pins and a DS3231 RTC needs them.
- SD (SPI): VCC 5 V or 3.3 V per module, CS 5, MOSI 23, MISO 19, SCK 18.

### Firmware sketch (TWAI, Mode 01 PIDs 0x0C RPM, 0x0D speed, 0x11 throttle)

```cpp
#include "driver/twai.h"
#define PID_ENGINE_RPM 0x0C
#define PID_SPEED 0x0D
#define PID_THROTTLE 0x11

void setup_can() {
  twai_general_config_t g = TWAI_GENERAL_CONFIG_DEFAULT(GPIO_NUM_21, GPIO_NUM_22, TWAI_MODE_NORMAL);
  twai_timing_config_t t = TWAI_TIMING_CONFIG_500KBITS(); // assumed, not confirmed
  twai_filter_config_t f = TWAI_FILTER_CONFIG_ACCEPT_ALL();
  twai_driver_install(&g, &t, &f);
  twai_start();
}

void request_obd_data(uint8_t pid) {
  twai_message_t m = {};
  m.identifier = 0x7DF; m.extd = 0; m.rtr = 0; m.data_length_code = 8;
  m.data[0] = 0x02; m.data[1] = 0x01; m.data[2] = pid;
  for (int i = 3; i < 8; i++) m.data[i] = 0xAA;
  twai_transmit(&m, pdMS_TO_TICKS(1000));
}
```

Transmit only: no reply reading or parsing yet.

### Supabase schema

```sql
CREATE TABLE public.telemetry_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  vehicle_id VARCHAR NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  engine_rpm INTEGER, speed_kmh INTEGER,
  throttle_position NUMERIC(5,2), engine_temp_c INTEGER
);
CREATE INDEX idx_telemetry_time ON public.telemetry_logs (vehicle_id, timestamp DESC);
```

### Implementation phases

1. Bench: breadboard ESP32 + transceiver + buck, 12 V wall adapter. Not on the bike yet.
2. Sniff raw frames with the key ON. If silent, swap CAN-H/L.
3. Poll PIDs twice a second, append to SD.
4. Wi-Fi batch sync via FreeRTOS task to a Supabase Edge Function.
5. Harden: perfboard, coating, box under the seat.

## Review findings to fix before building

**Verify first**
- Protocol (CAN vs K-line); measure the pins with ignition on: CAN lines idle near 2.5 V each, K-line near battery voltage. Get the pinout first; don't probe blind.
- The ECU may ignore generic Mode 01. Query PID 0x00 for supported PIDs. Check 29-bit IDs (0x18DAF110 style) as well as 0x7E8+.
- Oil-cooled 4V may not expose a temperature PID; `engine_temp_c` is not polled by the sketch.

**Power**
- The port's 12 V is probably always-on: ESP32 with Wi-Fi draws ~100-250 mA and will flatten the battery. Needs ignition sensing and deep sleep.
- Switched power kills Wi-Fi sync at home with the bike off. Pick one: sync while ignition is on (garage or phone hotspot); supercap or small battery plus a sense line to finish and sync after key-off; or BLE sync to a phone.
- Add fuse, reverse-polarity protection, TVS diode. LM2596 has no clamp.
- 12 V into VIN will not "fry instantly" but runs the onboard regulator hot.

**Bus**
- Remove the SN65HVD230's 120 Ω termination (bus already terminated).
- Sniff in `TWAI_MODE_LISTEN_ONLY`, not NORMAL.

**Firmware**
- No clock: ESP32 has no RTC. Add a DS3231 (CAN off pins 21/22) and set it by NTP over Wi-Fi.
- Log in its own FreeRTOS task with a queue; flush often (reduces, not prevents, corruption); use a power-loss sense line to close files; consider a supercap.
- You can't delete rows from a FAT file: one file per ride, delete whole files after the server confirms, or keep a synced-offset marker.
- Retries duplicate rows: unique constraint on (vehicle_id, timestamp) or a per-ride sequence number, and upsert.
- ESP32 HTTPS needs root-cert handling.

**Supabase**
- No service key on the device: per-device token via an Edge Function with RLS.
- Use `gen_random_uuid()`, not uuid-ossp.
- Add a `rides` table; batch inserts (2 Hz is ~7,200 rows/hour).
- Index should include `user_id`.

**Hardening**
- Full epoxy potting blocks repair and traps heat. Use conformal coating and a sealed box; keep the SD slot reachable.

## Recommended first step

Skip building. Borrow or buy a decent OBD adapter and the right bike cable, log with a phone app, and see which protocol and PIDs respond. A few hundred taka decides whether the rest is worth building. Cheap ELM327 v1.5 clones are often fake and flaky, so treat the result with care. A revised plan around a supercap + BLE-to-phone sync avoids the power conflict.
