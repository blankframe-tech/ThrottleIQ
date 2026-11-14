# Black box: motorcycle data logger for ThrottleIQ

Telemetry and diagnostic logger for the **Hero XPulse 200 4V Pro** (BS6 / BS6 Phase 2 / OBD-2 / E20). 

---

## 0. Strategic Reality Check & Product Freeze

> [!WARNING]
> **Product Freeze Compliance:** Under the repository rules in `AGENTS.md` (Decision 2026-11-02), ThrottleIQ is frozen until 12 Play Store testers are opted in. Development is restricted to security, store/GTM, tester-reported bugs, and growth-loop fixes. No new production database collections or custom hardware development can block release milestones.

### The ৳500 "Off-The-Shelf" Recommendation (Phase 1)
Before spending weeks sourcing discrete diodes, designing custom PCBs, and soldering perfboards:
1. A standard **mini OBD-II ELM327 v1.5 Bluetooth scanner** costs **৳400 – ৳600 on Daraz BD**.
2. Paired with a **Euro 5 6-pin to 16-pin adapter cable** (**৳650 on Daraz BD**), it plugs directly into the XPulse diagnostic port with zero custom soldering.
3. The ELM327 already includes wide-range automotive voltage regulation, ISO 15765-4 protocol negotiation, and connects to mobile phones over standard BLE / Bluetooth serial (SPP).
4. Running **Car Scanner ELM OBD2** on an Android phone validates the entire system in 5 minutes:
   - Verifies whether the Keihin ECU responds to Mode 01 queries over 500k CAN without proprietary security handshakes.
   - Confirms whether PID `0x05` (Engine Oil Temp) returns valid data on the 4V head.
   - Tests read/clear DTC capabilities (Modes 03/04/07) for the Right to Repair campaign.

**Only proceed to Phase 2 (Custom ESP32 Hardware)** if continuous autonomous SD logging without a phone is strictly required.

---

## 1. Verified Diagnostic Port & Pinout

Research across Hero MotoCorp technical service manuals, workshop diagnostic guides, and Keihin ECU specifications confirms:

- **Protocol:** **ISO 15765-4 CAN** (500 kbps, 11-bit standard ID `0x7DF` / `0x7E8`, 29-bit compatible).
- **Engine Control Unit (ECU):** **Keihin** 32-bit FI ECU.
- **Physical Connector:** Standard **Euro 5 / ISO 19689** 6-pin waterproof connector (**Sumitomo TS 025 Sealed Series**, female housing part no. **6189-7963**, Red shell located under the seat).
- **Harness Wire Colors & Signal Mapping (4 wires active):**
  - **Orange / White (O/W):** CAN High (`CAN-H`) $\rightarrow$ Connects to **OBD-II Pin 6**. Idles at ~2.5 V; pulses 2.0 V – 3.3 V with key ON.
  - **Blue / White (L/W):** CAN Low (`CAN-L`) $\rightarrow$ Connects to **OBD-II Pin 14**. Idles at ~2.5 V; pulses 1.5 V – 2.5 V with key ON.
  - **Red / Black (R/B):** Battery +12 V $\rightarrow$ Connects to **OBD-II Pin 16**. **Unswitched constant 12 V power** directly from main fuse.
  - **Green (G):** Chassis / ECU Ground $\rightarrow$ Connects to **OBD-II Pin 4 & Pin 5**.

> [!IMPORTANT]
> **Remove 120 Ω Termination on CAN Board:** The motorcycle's wiring harness is already terminated with two 120 Ω resistors at the ECU and cluster endpoints (~60 Ω total across CAN-H and CAN-L). You **must desolder or cut the 120 Ω jumper/resistor (R2)** on the SN65HVD230 breakout module before plugging into the bike, otherwise the bus resistance drops to ~40 Ω, causing transmission errors.

---

## 2. Hardware Architecture & Electrical Hardening (Phase 2)

### A. The Input Voltage & TVS Clamping Hazard (Resolved)
- **The MP1584 Flaw:** Generic MP1584EN modules have an Absolute Maximum Input Rating of **28.0 V**. A standard 1.5KE20CA TVS diode has a maximum clamping voltage of **27.7 V** (which surges above 28 V under peak automotive transient currents). A 0.3 V safety margin is fatal on a single-cylinder motorcycle where stator load dumps can reach 35 V–45 V.
- **The Trimpot Flaw:** Cheap buck modules use SMD trimpots that drift or shake loose under the intense single-cylinder vibrations of the XPulse 200, spiking output voltage to 8–10 V and instantly frying the ESP32.
- **The Correct Architecture:**
  - Use an **automotive-rated buck regulator rated for $\ge 40\text{ V} - 60\text{ V}$ input** (e.g., **LM2596HV**, **LM5008**, or **TPS54302**) configured with **fixed precision feedback resistors** (1% metal film), never an adjustable potentiometer.
  - Pair with a **1.5A fast-acting fuse**, an **SS34 Schottky diode** (reverse-polarity protection), and a **1.5KE36CA / SMAJ33A TVS diode** (standoff 33V, clamps transients safely below 50V).

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
Strapping pins control ESP32 bootloader modes and will hang the microcontroller if held in unexpected logic states during startup:
- **GPIO 2** controls flash download mode. Tying CAN_TX to GPIO 2 risks bootloader deadlocks if the transceiver floats or pulls the line high during power-up.
- **GPIO 5** controls SDIO timing and MTDO boot strapping.

**Safe, Non-Conflicting Pinout:**

| Peripheral | Signal | ESP32 GPIO | Description / Notes |
|---|---|---|---|
| **SN65HVD230 (CAN)** | 3V3 / GND | 3.3V / GND | Power transceiver from ESP32 3.3V rail |
| | CTX (TXD) | **GPIO 25** | Clean DAC/GPIO, no boot strapping |
| | CRX (RXD) | **GPIO 4** | RTC-capable GPIO for CAN RX |
| | Rs (Standby) | **GPIO 26** | HIGH = low-power standby (~370 µA), LOW = normal |
| **MicroSD Module (SPI)** | CS | **GPIO 33** | Clean GPIO, no boot strapping |
| | MOSI | **GPIO 23** | VSPI MOSI |
| | MISO | **GPIO 19** | VSPI MISO |
| | SCK | **GPIO 18** | VSPI SCK |
| **Ignition / Voltage Sense** | V_SENSE | **GPIO 34** | ADC1 input via 100k / 22k voltage divider |
| **I2C Bus (Optional)** | SDA / SCL | **GPIO 21 / GPIO 22** | Reserved for DS3231 RTC or OLED display |

---

## 3. Firmware & Protocol Architecture

### A. Deadlock-Free Wakeup & Power Management
Standard OBD-II is strictly request-response; the Keihin ECU will **not** transmit unsolicited diagnostic frames when the key is turned on. Relying on a CAN RX falling edge to wake from deep sleep creates a permanent deadlock (bus stays recessive $\rightarrow$ ESP32 never wakes up).

**Dual Wakeup Strategy:**
1. **Option A (Alternator Charging Detection - Zero Extra Wires):**
   - The ESP32 stays in Deep Sleep on the unswitched 12V line.
   - An ultra-low-power RTC timer wakes the ESP32 for 5 ms every 2.0 seconds.
   - The ADC reads battery voltage via the GPIO 34 divider:
     - Engine OFF: $V_{bat} \le 12.8\text{ V} \rightarrow$ resume Deep Sleep immediately (average draw $<25\ \mu\text{A}$).
     - Engine Running: Stator charges battery to $V_{bat} \ge 13.6\text{ V} \rightarrow$ full system boot and start logging.
2. **Option B (Switched Accessory Sense Line):**
   - Tap a switched 12V line (tail light or USB port) through a voltage divider to RTC GPIO 34.
   - Configure `esp_sleep_enable_ext0_wakeup(GPIO_NUM_34, 1)` to wake instantly on ignition HIGH.

### B. Safe Polling Rate vs. Passive Sniffing
- **Diagnostic Polling Rate:** Querying PIDs at 40 Hz overwhelms small single-cylinder ECUs. Active queries are capped at **2 Hz – 5 Hz** (200 ms – 500 ms cycle).
- **Passive Sniffing (Listen-Only):** The XPulse 200 4V digital LCD cluster continuously receives RPM, wheel speed, and gear indicator data from the ECU over CAN. In `TWAI_MODE_LISTEN_ONLY`, the ESP32 sniffs these broadcast frames at 20–50 Hz with **zero ECU CPU load** and zero risk of bus-off errors.

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
0x0A   | Engine Temp     | int8_t     | Engine Oil Temp in °C (-40 to +215)
0x0B   | Status Flags    | uint8_t    | Bit 0: MIL active, Bit 1: SD log active
```

---

## 4. Production Firmware Sketch (With SD Logging & BLE Sequencing)

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
#define PID_EOT          0x05

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
      logFile.println("millis,seq,rpm,speed,throttle,eot");
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
        case PID_EOT:
          packet.engine_temp_c = (int8_t)rx_msg.data[3] - 40;
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
      case 3: send_pid_query(PID_EOT); break;
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
> **No Relational Row Firehose:** Streaming 10–20 Hz telemetry directly as individual database rows yields `36,000 writes/hour`. A regular rider logging 1.5 hours/day produces **>1.6 million writes/month**, instantly demolishing Firebase quotas. Furthermore, ThrottleIQ uses **Cloud Firestore** and **Firebase Auth**, not Supabase.

### Clean Dual-Tier Cloud Architecture
1. **Live Cockpit (In-Memory / Local SQLite):**
   - High-frequency BLE notifications (5–10 Hz) drive the live speedometer, gear ratio indicator, and tachometer in the Flutter UI.
   - Downsampled data (1 Hz) records locally to SQLite on the phone via ThrottleIQ's existing `RideDao`.
2. **Cloud Sync (1 Write Per Ride Session):**
   - **Firestore:** When a ride finishes, ThrottleIQ writes **one single document** to `users/{uid}/rides/{rideId}` with ride totals (distance, top speed, max RPM, duration, start/end timestamps, BRTA fuel economy metrics).
   - **Cloud Storage (Optional High-Res Log):** The full 5 Hz CSV/binary telemetry log is gzipped on the phone and uploaded to Firebase Storage (`rides/{uid}/{rideId}.csv.gz`) as an analytical artifact, costing **1 single upload**.

---

## 6. Right to Repair Capabilities

To support the Right to Repair campaign (`labs/bd-moto-right-to-repair`), the diagnostic interface must support fault code management, not just live Mode 01 streaming:

- **Mode 03 (Request Confirmed DTCs):** `0x7DF [0x01, 0x03, 0xAA...]` $\rightarrow$ reads stored error codes (e.g. `P0115` Engine Coolant/Oil Temp Sensor circuit malfunction).
- **Mode 07 (Request Pending DTCs):** Reads intermittent faults detected during the current driving cycle.
- **Mode 04 (Clear DTCs & Reset MIL):** `0x7DF [0x01, 0x04, 0xAA...]` $\rightarrow$ extinguishes the Check Engine Malfunction Indicator Lamp after servicing.

---

## 7. Pragmatic Implementation Roadmap

| Milestone | Action | Risk Gate |
|---|---|---|
| **Phase 1 (Immediate)** | Buy Euro 5 adapter (৳650) + mini ELM327 v1.5 (৳450). Plug into XPulse with *Car Scanner ELM OBD2*. | Confirm CAN 500k negotiation, PID `0x05` EOT support, and Mode 03/04 DTC reading. Zero custom hardware built. |
| **Phase 2 (Post-Freeze)** | If autonomous SD logging is required: build custom ESP32 board using $\ge 40\text{ V}$ buck IC, fixed resistors, and unstrapped GPIOs (25/4/33). | Bench test with 12V supply; verify alternator charging wake threshold ($\ge 13.6\text{ V}$). |
| **Phase 3 (App Hookup)** | Add Bluetooth serial/BLE scanner to ThrottleIQ to ingest the verified telemetry stream. | Validate 1 write/ride Firestore schema with compressed Storage artifact. |
