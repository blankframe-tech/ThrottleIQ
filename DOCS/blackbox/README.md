# Black box: motorcycle data logger for ThrottleIQ

Telemetry and diagnostic logger for the **Hero XPulse 200 4V Pro** (BS6 / BS6 Phase 2 / OBD-2 / E20). 

---

## 0. Strategic Reality Check & Product Freeze

> [!WARNING]
> **Product Freeze Compliance:** Under the repository rules in `AGENTS.md` (Decision 2026-11-02), ThrottleIQ is frozen until 12 Play Store testers are opted in. Development is restricted to security, store/GTM, tester-reported bugs, and growth-loop fixes. No new production database collections or custom hardware development can block release milestones.

### The ~৳1,100 "Off-The-Shelf" Recommendation (Phase 1)
Before spending weeks sourcing discrete diodes, designing custom PCBs, and soldering perfboards:
1. A standard **mini OBD-II ELM327 v1.5 Bluetooth scanner** costs roughly **৳400 – ৳600 on Daraz BD** (prices unverified; cheap "v1.5" clones are often fake or flaky on CAN, so buy from a seller with returns).
2. Paired with a **Euro 5 6-pin to 16-pin adapter cable** (roughly **৳650 on Daraz BD**, unverified; confirm the adapter really exists for this bike's connector first), it plugs directly into the XPulse diagnostic port with zero custom soldering.
3. The ELM327 already includes on-board voltage regulation, ISO 15765-4 protocol negotiation, and connects to mobile phones over standard BLE / Bluetooth serial (SPP).
4. Running **Car Scanner ELM OBD2** on an Android phone validates the entire system in 5 minutes:
   - Verifies whether the Keihin ECU responds to Mode 01 queries over 500k CAN without proprietary security handshakes.
   - Confirms whether PID `0x05` returns valid data on the 4V head. Per SAE J1979, `0x05` is **Engine Coolant Temp**; true Engine Oil Temp is PID `0x5C`. On this oil-cooled engine the ECU may map `0x05` to an oil/head sensor: bench verification needed, try both `0x05` and `0x5C`.
   - Tests read/clear DTC capabilities (Modes 03/04/07) for the Right to Repair campaign.

**Only proceed to Phase 2 (Custom ESP32 Hardware)** if continuous autonomous SD logging without a phone is strictly required.

---

## 1. Claimed Diagnostic Port & Pinout (UNVERIFIED, needs bench verification)

> [!WARNING]
> No primary source (Hero service manual, Keihin spec) is cited for anything in this section, and several details were not independently checked. Many motorcycles use K-line (ISO 14230 / ISO 9141) or a proprietary diagnostic connector rather than J1962. Treat every item below as a hypothesis until confirmed with a multimeter and a known-good scanner (see `protocol-discovery.md` multimeter checks).

Claimed:

- **Protocol:** **ISO 15765-4 CAN** (500 kbps, 11-bit standard ID `0x7DF` request / `0x7E8` response; 29-bit variant `0x18DB33F1` / `0x18DAF1xx` possible, unconfirmed).
- **Engine Control Unit (ECU):** **Keihin** 32-bit FI ECU.
- **Physical Connector:** 6-pin waterproof connector, reportedly described as "Euro 5 / ISO 19689" (**Sumitomo TS 025 Sealed Series**, part no. **6189-7963**, red shell under the seat). Standard, part number and location are unverified; check the physical connector.
- **Harness Wire Colors & Signal Mapping (4 wires active):**
  - **Orange / White (O/W):** CAN High (`CAN-H`) $\rightarrow$ Connects to **OBD-II Pin 6**. Recessive ~2.5 V; dominant ~3.5 V nominal (a multimeter averages bus traffic, so expect roughly 2.5 V – 3.0 V).
  - **Blue / White (L/W):** CAN Low (`CAN-L`) $\rightarrow$ Connects to **OBD-II Pin 14**. Recessive ~2.5 V; dominant ~1.5 V nominal (multimeter average roughly 2.0 V – 2.5 V).
  - **Red / Black (R/B):** Battery +12 V $\rightarrow$ Connects to **OBD-II Pin 16**. **Unswitched constant 12 V power** directly from main fuse.
  - **Green (G):** Chassis / ECU Ground $\rightarrow$ Connects to **OBD-II Pin 4 & Pin 5**.

> [!IMPORTANT]
> **Remove 120 Ω Termination on CAN Board:** A properly built CAN bus has two 120 Ω terminators (~60 Ω across CAN-H/CAN-L). **Measure first** (battery disconnected, see `protocol-discovery.md`): the harness is assumed, not confirmed, to carry both. If it reads ~60 Ω, **remove the on-board 120 Ω terminator** (jumper or resistor; the reference designator varies by SN65HVD230 board) before plugging into the bike, otherwise the bus drops to ~40 Ω and errors result. If it reads ~120 Ω only one terminator exists, so leave the module's resistor in place.

---

## 2. Hardware Architecture & Electrical Hardening (Phase 2)

### A. The Input Voltage & TVS Clamping Hazard (Resolved)
- **The MP1584 Flaw:** Generic MP1584EN modules have an Absolute Maximum Input Rating of **28.0 V**. A standard 1.5KE20CA TVS diode has a maximum clamping voltage of **27.7 V** at its rated peak current, leaving almost no margin. Motorcycle charging systems can produce load-dump style transients well above 28 V (ISO 16750-2 / ISO 7637-2 test pulses go far higher for unsuppressed systems; actual levels on this bike are unmeasured), so a 28 V-rated stage is not acceptable.
- **The Trimpot Flaw:** Cheap buck modules use SMD trimpots that drift or shake loose under the intense single-cylinder vibrations of the XPulse 200, spiking output voltage to 8–10 V and instantly frying the ESP32.
- **The Correct Architecture:**
  - Use an **automotive-rated buck regulator rated for $\ge 40\text{ V} - 60\text{ V}$ input** (candidates to check against datasheets: **LM2596HV** (60 V, but ~mA-class quiescent current, bad for an always-on line), **LM5164**-class low-Iq 100 V bucks; **LM5008** needs >=9.5 V in and is only 350 mA, so it drops out during cranking sag; **TPS54302 is only 28 V and does NOT qualify**) configured with **fixed precision feedback resistors** (1% metal film), never an adjustable potentiometer. Pick a part with low quiescent current (tens of µA) if the board stays powered while parked.
  - Pair with a **1.5A fast-acting fuse**, an **SS34 Schottky diode** (reverse-polarity protection), and a **1.5KE36CA TVS diode** (36 V class: standoff ~30.8 V, max clamp ~49.9 V at rated peak current; the buck input must be rated above that). Do not substitute SMAJ33A: its clamp is ~53 V and it is a much smaller 400 W part.

```text
Bike Diagnostic Port (Red/Black +12V Constant)
          |
     [ 1.5A Fuse ]
          |
    [ SS34 Diode ]  <-- Reverse polarity protection
          |
          +-----------------------+---------------------+
          |                       |                     |
   [ 1.5KE36CA TVS ]      [ 220µF 50V Cap ]      [ 100nF 50V Ceramic ]
   (clamps spikes <50V)   (buffers cold cranks)  (high-freq filtering)
          |                       |                     |
          +-----------------------+---------------------+
          |
     [ High-Voltage Buck IN+ (>=40V-60V Rated) ]
     [ High-Voltage Buck IN- ] --------+
          |                            |
     [ Fixed 5.0V Output (No Trimpots) ]
          |                            |
     [ ESP32 VIN ]              [ ESP32 GND ] <--- Bike Port (Green Ground)
```

### B. Pin Allocations (Avoiding Strapping Pin Hazards)
This document targets the classic **ESP32 (WROOM/WROVER)**; strapping pins differ on ESP32-S3/C3, so recheck the table if the chip changes. Strapping pins are sampled at reset and can prevent boot if held in unexpected states:
- **GPIO 0** selects download mode (low at reset = download).
- **GPIO 2** must be low or floating to enter download mode; avoid driving it high from external hardware at power-up.
- **GPIO 12 (MTDI)** selects flash voltage; high at boot on a 3.3 V flash module can prevent boot.
- **GPIO 15 (MTDO)** controls boot log silencing and SDIO timing.
- **GPIO 5** controls SDIO slave timing.

**Safe, Non-Conflicting Pinout:**

| Peripheral | Signal | ESP32 GPIO | Description / Notes |
|---|---|---|---|
| **SN65HVD230 (CAN)** | 3V3 / GND | 3.3V / GND | Power transceiver from ESP32 3.3V rail |
| | CTX (TXD) | **GPIO 25** | Clean DAC/GPIO, no boot strapping |
| | CRX (RXD) | **GPIO 4** | RTC-capable GPIO for CAN RX |
| | Rs (Standby) | **GPIO 26** | HIGH = standby (transceiver off), LOW = high-speed normal. Standby current figure unverified; check datasheet |
| **MicroSD Module (SPI)** | CS | **GPIO 33** | Clean GPIO, no boot strapping |
| | MOSI | **GPIO 23** | VSPI MOSI |
| | MISO | **GPIO 19** | VSPI MISO |
| | SCK | **GPIO 18** | VSPI SCK |
| **Ignition / Voltage Sense** | V_SENSE | **GPIO 34** | ADC1 input via 100k / 22k divider. Needs a ~3.3 V clamp (e.g. zener) since the rail can reach TVS-clamp levels, and the divider itself draws ~100 µA from 12 V, which alone breaks the sleep-current target below: use much larger resistors plus a 100 nF cap, or switch the divider. Bench verify |
| **I2C Bus (Optional)** | SDA / SCL | **GPIO 21 / GPIO 22** | Reserved for DS3231 RTC or OLED display |

---

## 3. Firmware & Protocol Architecture

### A. Deadlock-Free Wakeup & Power Management
Standard OBD-II diagnostics are request-response; the ECU is not expected to send unsolicited *diagnostic* frames when the key is turned on (it may still broadcast cluster/other frames, see B; unverified). Relying on a CAN RX falling edge to wake from deep sleep creates a permanent deadlock (bus stays recessive $\rightarrow$ ESP32 never wakes up).

**Dual Wakeup Strategy:**
1. **Option A (Alternator Charging Detection - Zero Extra Wires):**
   - The ESP32 stays in Deep Sleep on the unswitched 12V line.
   - A timer wakes the ESP32 every 2.0 seconds. A full wake from deep sleep re-runs the bootloader and takes on the order of 100+ ms, not 5 ms; to sample cheaply use the ULP coprocessor, or accept the higher average draw.
   - The ADC reads battery voltage via the GPIO 34 divider:
     - Engine OFF: $V_{bat} \le 12.8\text{ V} \rightarrow$ resume Deep Sleep immediately. A rested battery is ~12.6-12.9 V, so use hysteresis rather than one threshold.
     - Engine Running: charging voltage $\ge 13.6\text{ V} \rightarrow$ full system boot and start logging. Whether this bike's stator/regulator reaches 13.6 V at idle is unmeasured.
   - The earlier "<25 µA average" figure is unsupported: a bare ESP32 deep sleeps at ~10 µA, but dev boards (USB-UART chip, LDO), the buck regulator, the sense divider and the SD module typically add far more. Measure the real quiescent current before leaving it on an unswitched line (battery drain).
2. **Option B (Switched Accessory Sense Line):**
   - Tap a switched 12V line through a voltage divider plus clamp to a **separate RTC-capable input-only GPIO, e.g. GPIO 35** (GPIO 34 is already the battery ADC, do not share it). ext0/ext1 wakeup works only on RTC GPIOs (0, 2, 4, 12-15, 25-27, 32-39).
   - GPIO 34-39 have no internal pull resistors, so add an external pull-down.
   - Configure `esp_sleep_enable_ext0_wakeup(GPIO_NUM_35, 1)` to wake on ignition HIGH.

### B. Safe Polling Rate vs. Passive Sniffing
- **Diagnostic Polling Rate:** The ECU's tolerance is unmeasured; a conservative cap of **2 Hz – 5 Hz** total (200 ms – 500 ms cycle) is used. Note the sketch cycles 4 PIDs at one query per 200 ms, so each PID updates at only ~1.25 Hz.
- **Passive Sniffing (Listen-Only):** If the cluster is on the same CAN bus it may receive broadcast RPM/speed frames, but their IDs and scaling are proprietary and undocumented, so the 20-50 Hz rate is a hypothesis requiring frame capture. In `TWAI_MODE_LISTEN_ONLY` the ESP32 does not transmit or ACK, so it cannot cause bus-off or add bus load (ECU CPU load is unaffected).

### C. BLE Telemetry Packet Format (Jitter & Sequence Proof)
To survive Bluetooth connection interval jitter (30–100 ms) and allow the mobile app to compute acceleration derivatives:

```text
Offset | Field           | Type       | Description
-------+-----------------+------------+-------------------------------------------
0x00   | Session Millis  | uint32_t   | Milliseconds elapsed since ride session start
0x04   | Sequence ID     | uint16_t   | Monotonic packet counter (detects drops)
0x06   | Engine RPM      | uint16_t   | Live RPM (0 - 16,383)
0x08   | Speed km/h      | uint8_t    | Vehicle speed (0 - 255 km/h)
0x09   | Throttle %      | uint8_t    | Throttle opening (0 - 100%)
0x0A   | Engine Temp     | int8_t     | PID 0x05 temp in °C (-40 to +127 after clamping; PID range is -40..+215 but int8_t cannot hold >127)
0x0B   | Status Flags    | uint8_t    | Bit 0: MIL active, Bit 1: SD log active
```

---

## 4. Firmware Sketch (Untested Draft, With SD Logging & BLE Sequencing)

> [!NOTE]
> Untested on hardware. Known gaps: it does not implement the battery-voltage wake gate from section 3A (every 2 s timer wake runs the full setup and waits 30 s for bus activity before sleeping again), never sets status bit 0 (MIL), and does not hold the Rs pin level during deep sleep (use `gpio_hold_en` / `rtc_gpio_hold_en` on GPIO 26, otherwise it floats). It only handles single-frame ISO-TP responses and the first ECU (`0x7E8`); multi-frame replies (e.g. Mode 03 with many DTCs) need flow-control handling.

```cpp
#include <Arduino.h>
#include <SPI.h>
#include <SD.h>
#include "driver/twai.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Safe Pin Definitions
#define CAN_TX_PIN       GPIO_NUM_25
#define CAN_RX_PIN       GPIO_NUM_4
#define CAN_RS_PIN       GPIO_NUM_26
#define SD_CS_PIN        GPIO_NUM_33
#define BATTERY_SENSE_PIN GPIO_NUM_34

#define OBD_REQ_ID       0x7DF
#define OBD_RESP_ID      0x7E8

// Mode 01 PIDs
#define PID_RPM          0x0C
#define PID_SPEED        0x0D
#define PID_THROTTLE     0x11
#define PID_ECT          0x05  // J1979: coolant temp; oil temp is 0x5C. Verify which this ECU reports

#pragma pack(push, 1)
struct TelemetryPacket {
  uint32_t session_millis;
  uint16_t sequence_id;
  uint16_t rpm;
  uint8_t  speed_kmh;
  uint8_t  throttle_pct;
  int8_t   engine_temp_c;
  uint8_t  status_flags;
} packet;
#pragma pack(pop)

// BLE Service UUIDs
#define SERVICE_UUID        "91bad492-b950-4226-aa2b-4ede9fa42f59"
#define CHARACTERISTIC_UUID "cba1d466-344c-4be3-ab3f-189f80dd7518"

BLECharacteristic *pTelemetryChar = nullptr;
bool bleConnected = false;
File logFile;
bool sdActive = false;
uint32_t lastBusActivity = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { bleConnected = true; }
  void onDisconnect(BLEServer* pServer) {
    bleConnected = false;
    BLEDevice::startAdvertising();
  }
};

void setup_twai() {
  pinMode(CAN_RS_PIN, OUTPUT);
  digitalWrite(CAN_RS_PIN, LOW); // High-speed mode

  twai_general_config_t g_config = TWAI_GENERAL_CONFIG_DEFAULT(CAN_TX_PIN, CAN_RX_PIN, TWAI_MODE_NORMAL);
  twai_timing_config_t t_config = TWAI_TIMING_CONFIG_500KBITS();
  twai_filter_config_t f_config = TWAI_FILTER_CONFIG_ACCEPT_ALL();

  ESP_ERROR_CHECK(twai_driver_install(&g_config, &t_config, &f_config));
  ESP_ERROR_CHECK(twai_start());
}

void setup_sd() {
  if (SD.begin(SD_CS_PIN)) {
    sdActive = true;
    logFile = SD.open("/ride_log.csv", FILE_APPEND);
    if (logFile) {
      logFile.println("millis,seq,rpm,speed,throttle,temp");
      logFile.flush();
    }
  }
}

void send_pid_query(uint8_t pid) {
  twai_message_t msg = {};
  msg.identifier = OBD_REQ_ID;
  msg.data_length_code = 8;
  msg.data[0] = 0x02; // Bytes to follow
  msg.data[1] = 0x01; // Mode 01
  msg.data[2] = pid;
  for (int i = 3; i < 8; i++) msg.data[i] = 0xAA;
  twai_transmit(&msg, pdMS_TO_TICKS(20));
}

void read_can_responses() {
  twai_message_t rx_msg;
  while (twai_receive(&rx_msg, 0) == ESP_OK) {
    lastBusActivity = millis();
    if (rx_msg.identifier == OBD_RESP_ID && rx_msg.data[1] == 0x41) {
      uint8_t pid = rx_msg.data[2];
      switch (pid) {
        case PID_RPM:
          packet.rpm = ((rx_msg.data[3] * 256) + rx_msg.data[4]) / 4;
          break;
        case PID_SPEED:
          packet.speed_kmh = rx_msg.data[3];
          break;
        case PID_THROTTLE:
          packet.throttle_pct = (rx_msg.data[3] * 100) / 255;
          break;
        case PID_ECT:
          { int t = (int)rx_msg.data[3] - 40; packet.engine_temp_c = t > 127 ? 127 : t; }
          break;
      }
    }
  }
}

void enter_deep_sleep() {
  if (logFile) {
    logFile.flush();
    logFile.close();
  }
  twai_stop();
  twai_driver_uninstall();
  digitalWrite(CAN_RS_PIN, HIGH); // Standby mode

  // Wake up every 2 seconds to sample battery voltage
  esp_sleep_enable_timer_wakeup(2000000);
  esp_deep_sleep_start();
}

void setup() {
  Serial.begin(115200);
  setup_twai();
  setup_sd();

  BLEDevice::init("ThrottleIQ-BlackBox");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pTelemetryChar = pService->createCharacteristic(
                     CHARACTERISTIC_UUID,
                     BLECharacteristic::PROPERTY_READ |
                     BLECharacteristic::PROPERTY_NOTIFY
                   );
  pTelemetryChar->addDescriptor(new BLE2902());
  pService->start();
  BLEDevice::startAdvertising();

  lastBusActivity = millis();
  packet.sequence_id = 0;
}

void loop() {
  static uint8_t pid_cycle = 0;
  static uint32_t last_poll = 0;

  // Safe 5 Hz polling rate (every 200 ms)
  if (millis() - last_poll >= 200) {
    last_poll = millis();
    switch (pid_cycle % 4) {
      case 0: send_pid_query(PID_RPM); break;
      case 1: send_pid_query(PID_SPEED); break;
      case 2: send_pid_query(PID_THROTTLE); break;
      case 3: send_pid_query(PID_ECT); break;
    }
    pid_cycle++;
  }

  read_can_responses();

  // 5 Hz BLE broadcast & local SD buffer
  static uint32_t last_broadcast = 0;
  if (millis() - last_broadcast >= 200) {
    last_broadcast = millis();
    packet.session_millis = millis();
    packet.sequence_id++;
    packet.status_flags = (sdActive ? 0x02 : 0x00);

    if (bleConnected && pTelemetryChar) {
      pTelemetryChar->setValue((uint8_t*)&packet, sizeof(packet));
      pTelemetryChar->notify();
    }

    if (logFile) {
      logFile.printf("%lu,%u,%u,%u,%u,%d\n",
                     packet.session_millis, packet.sequence_id,
                     packet.rpm, packet.speed_kmh,
                     packet.throttle_pct, packet.engine_temp_c);
      static uint8_t flushCount = 0;
      if (++flushCount >= 25) { // Flush every 5 seconds
        logFile.flush();
        flushCount = 0;
      }
    }
  }

  // 30 seconds of silence indicates engine shutoff
  if (millis() - lastBusActivity > 30000) {
    enter_deep_sleep();
  }
}
```

---

## 5. Data Architecture Alignment (ThrottleIQ Firebase Stack)

> [!CAUTION]
> **No Relational Row Firehose:** Streaming 10 Hz telemetry directly as individual database rows yields `36,000 writes/hour` (double at 20 Hz). A regular rider logging 1.5 hours/day produces **>1.6 million writes/month**, demolishing Firebase quotas. Furthermore, ThrottleIQ uses **Cloud Firestore**, **Firebase Auth** and Realtime Database (plus Cloud Functions), not Supabase.

### Clean Dual-Tier Cloud Architecture
1. **Live Cockpit (In-Memory / Local SQLite):**
   - High-frequency BLE notifications (5–10 Hz) drive the live speedometer, gear ratio indicator, and tachometer in the Flutter UI.
   - Downsampled data (1 Hz) records locally to SQLite on the phone via ThrottleIQ's existing `RideDao`.
2. **Cloud Sync (1 Write Per Ride Session):**
   - **Firestore:** When a ride finishes, ThrottleIQ writes **one single document** to `users/{uid}/rides/{rideId}` with ride totals (distance, top speed, max RPM, duration, start/end timestamps). Reuse the existing ride schema (`firestore.rules` `users/{uid}/rides`); new fields are a schema change that the product freeze restricts.
   - **Cloud Storage (Optional High-Res Log, NOT currently available):** The repo has no `firebase_storage` dependency and no Storage rules in `firebase.json` (media goes through Cloudinary). Uploading a gzipped 5 Hz log would add a new backend service and security rules, so it is a post-freeze decision. Until then keep the full-rate log on the phone or SD card only.

---

## 6. Right to Repair Capabilities

To support the Right to Repair campaign (`labs/bd-moto-right-to-repair`), the diagnostic interface must support fault code management, not just live Mode 01 streaming:

- **Mode 03 (Request Confirmed DTCs):** `0x7DF [0x01, 0x03, 0xAA...]` $\rightarrow$ reads stored error codes (e.g. `P0115` Engine Coolant Temp Sensor circuit malfunction).
- **Mode 07 (Request Pending DTCs):** Reads intermittent faults detected during the current driving cycle.
- **Mode 04 (Clear DTCs & Reset MIL):** `0x7DF [0x01, 0x04, 0xAA...]` $\rightarrow$ extinguishes the Check Engine Malfunction Indicator Lamp after servicing. Record all codes first (clearing also erases freeze-frame data), and run it with the engine off.

---

## 7. Pragmatic Implementation Roadmap

| Milestone | Action | Risk Gate |
|---|---|---|
| **Phase 1 (Immediate)** | Buy Euro 5 adapter (~৳650) + mini ELM327 (~৳450), prices unverified. Plug into XPulse with *Car Scanner ELM OBD2*. | Confirm the protocol really is CAN 500k (not K-line), PID `0x05` (coolant/oil?) and `0x5C` support, and Mode 03/04 DTC reading. Zero custom hardware built. |
| **Phase 2 (Post-Freeze)** | If autonomous SD logging is required: build custom ESP32 board using $\ge 40\text{ V}$ low-Iq buck IC, fixed resistors, and unstrapped GPIOs (25/4/33). | Bench test with 12V supply and a load-dump/cranking simulation; measure sleep current; verify the charging wake threshold ($\ge 13.6\text{ V}$) on the real bike. |
| **Phase 3 (App Hookup)** | Add Bluetooth serial/BLE scanner to ThrottleIQ to ingest the telemetry stream. Needs new screens/strings, so only after the product freeze lifts. | Validate 1 write/ride Firestore schema (Storage artifact only if Storage is adopted). |
