# Black box: motorcycle data logger for ThrottleIQ

An ESP32-based telemetry and diagnostic logger for the **Hero XPulse 200 4V Pro** (BS6 / BS6 Phase 2 / OBD-2 / E20). It taps into the factory under-seat diagnostic port, acquires real-time engine telemetry (RPM, speed, throttle position, engine oil temperature), logs rides locally to a MicroSD card, and streams live data over Bluetooth Low Energy (BLE) to the **ThrottleIQ** mobile app on the rider's phone. ThrottleIQ combines OBD metrics with phone GPS/IMU data and batches ride sessions to Supabase.

---

## 1. Verified Specifications & Pinout

Research across Hero MotoCorp technical service manuals, workshop diagnostic guides, and Keihin ECU specifications confirms:

- **Protocol:** **ISO 15765-4 CAN** (500 kbps, 11-bit standard ID, 29-bit extended compatible).
- **Engine Control Unit (ECU):** **Keihin** 32-bit FI ECU.
- **Physical Connector:** Standard **Euro 5 / ISO 19689** 6-pin waterproof connector (**Sumitomo TS 025 Sealed Series**, female housing part no. **6189-7963**, Red shell located under the seat).
- **Harness Wire Colors & Signal Mapping (4 wires active):**
  - **Orange / White (O/W):** CAN High (`CAN-H`) $\rightarrow$ Connects to **OBD-II Pin 6**. Idles at ~2.5 V; pulses 2.0 V – 3.3 V with key ON.
  - **Blue / White (L/W):** CAN Low (`CAN-L`) $\rightarrow$ Connects to **OBD-II Pin 14**. Idles at ~2.5 V; pulses 1.5 V – 2.5 V with key ON.
  - **Red / Black (R/B):** +12V Battery Power $\rightarrow$ Connects to **OBD-II Pin 16**. **Unswitched constant 12 V power** directly from main fuse.
  - **Green (G):** Chassis / ECU Ground $\rightarrow$ Connects to **OBD-II Pin 4 & Pin 5**.

> [!IMPORTANT]
> **Remove 120 Ω Termination on CAN Board:** The motorcycle's wiring harness is already terminated with two 120 Ω resistors at the ECU and cluster endpoints (measured ~60 Ω total across CAN-H and CAN-L). You **must desolder or cut the 120 Ω jumper/resistor (R2)** on the SN65HVD230 breakout module before plugging into the bike, otherwise the bus resistance drops to ~40 Ω, causing transmission errors.

---

## 2. Bill of Materials (BD Market & Availability)

| Part | Specification / Notes | Est. Cost (BDT) | Source in Bangladesh |
|---|---|---|---|
| **ESP32 NodeMCU (30 or 38-pin)** | ESP32-WROOM-32 (Dual Core, Wi-Fi + BLE, native TWAI) | ৳550 – ৳650 | [TechShopBD](https://techshopbd.com) / [RoboticsBD](https://roboticsbd.com) / Daraz |
| **SN65HVD230 CAN Module** | 3.3 V CAN transceiver, supports low-power Standby via `Rs` pin | ৳350 – ৳790 | [RoboticsBD](https://store.roboticsbd.com/i2c-spi-can-interface-module/2292-sn65hvd230-can-board-network-transceiver-evaluation-development-module-robotics-bangladesh.html) / Daraz |
| **MP1584EN Mini Buck Module** | DC-DC Step-Down (4.5V–28V In $\rightarrow$ 5.0V Out @ 3A, 1.5MHz, tiny footprint) | ৳80 – ৳120 | [RoboticsBD](https://roboticsbd.com) / Daraz |
| **Euro 5 6-pin to 16-pin Cable** | Sumitomo 6-pin male to OBD-II 16-pin female adapter | ৳650 – ৳1,100 | Daraz BD (search: *"Euro 5 6 pin motorcycle OBD cable"*) |
| **TVS Diode (1.5KE20CA or 1.5KE18CA)** | Bidirectional 1500W transient voltage suppressor (clamps load dumps) | ৳25 – ৳40 | Local electronics market (Stadium / Patuatuly) / Daraz |
| **Schottky Diode (SS34 or 1N5822)** | 3A–4A reverse polarity protection diode | ৳10 – ৳20 | Local electronics market / Daraz |
| **Fast-blow Fuse + Inline Holder** | 1.0 A or 1.5 A mini blade fuse | ৳40 – ৳60 | Local automotive / motorbike electrical shop |
| **Electrolytic & Ceramic Caps** | 220 µF 35V low-ESR electrolytic + 100 nF 50V ceramic | ৳15 – ৳30 | Local electronics market |
| **MicroSD SPI Module** | 3.3V/5V compatible SPI MicroSD card breakout | ৳120 – ৳180 | TechShopBD / Daraz |
| **Weatherproof Box (IP65)** | Small ABS plastic project enclosure (~80x50x25mm) | ৳120 – ৳180 | TechShopBD / Daraz |

---

## 3. Power Architecture & Transient Protection

Motorcycle electrical systems are notoriously noisy: single-cylinder inductive ignition coils, starter motor crank dips (down to 6V), and alternator load dump spikes (up to 40V+). Feeding unconditioned power directly into a cheap buck module will eventually destroy it.

### Front-End Power Conditioning Circuit

```text
Bike Diagnostic Port (Red/Black +12V Constant)
          |
     [ 1.5A Fuse ]
          |
    [ SS34 Diode ]  <-- Reverse polarity protection
          |
          +-----------------------+---------------------+
          |                       |                     |
   [ 1.5KE20CA TVS ]      [ 220µF 35V Cap ]      [ 100nF Ceramic ]
   (clamps spikes >20V)   (buffers cold cranks)  (high-freq filtering)
          |                       |                     |
          +-----------------------+---------------------+
          |
     [ MP1584EN IN+ ]  (Pre-adjusted to exactly 5.00V)
     [ MP1584EN IN- ] -----------------+
          |                            |
     [ MP1584EN OUT+ (5.0V) ]          |
          |                            |
     [ ESP32 VIN ]              [ ESP32 GND ] <--- Bike Port (Green Ground)
```

### Power Management & Battery Protection (No Flat Battery)

Because Pin 4 (+12V) on the Euro 5 port is **always live**, an ESP32 drawing 150 mA continuously will drain the bike's 4 Ah battery in 2–3 days.

- **Engine Running / Key ON:** CAN bus traffic is active. ESP32 is awake, polling PIDs, logging to SD, and streaming BLE.
- **Key OFF / Bike Parked:** CAN traffic stops. After **30 seconds of bus silence**, the ESP32:
  1. Flushes and safely closes the open file on the MicroSD card.
  2. Pulls the SN65HVD230 `Rs` pin HIGH to put the CAN transceiver into low-power Standby mode (~370 µA).
  3. Enters ESP32 **Deep Sleep** (drawing <15 µA).
- **Wakeup:** When the rider turns the key ON, the ECU initializes and drives the CAN bus lines. The transceiver detects dominant bus activity, bringing its RX pin LOW. This falling edge triggers an external RTC interrupt (`esp_sleep_enable_ext0_wakeup` on GPIO 4) to wake the ESP32 instantly.

---

## 4. Hardware Wiring & Pin Allocations

To avoid peripheral conflicts (e.g. keeping I2C on GPIO 21/22 open for DS3231 RTC or OLED display):

| Module | Pin Name | Connected To ESP32 Pin | Notes |
|---|---|---|---|
| **SN65HVD230 (CAN)** | 3V3 / GND | 3.3V / GND | Power transceiver from ESP32 3.3V rail |
| | CTX (TXD) | **GPIO 2** (or GPIO 4) | TWAI TX |
| | CRX (RXD) | **GPIO 4** (or GPIO 5) | TWAI RX (RTC GPIO capable for wake-up) |
| | CAN_H | Euro 5 Pin 2 (Orange/White) | To bike harness CAN-High |
| | CAN_L | Euro 5 Pin 5 (Blue/White) | To bike harness CAN-Low |
| | Rs | **GPIO 13** (optional) | Pull HIGH for standby, LOW for high-speed |
| **MicroSD Module (SPI)** | VCC / GND | 5V (or 3.3V) / GND | |
| | CS | **GPIO 5** | Chip Select |
| | MOSI | **GPIO 23** | Hardware VSPI MOSI |
| | MISO | **GPIO 19** | Hardware VSPI MISO |
| | SCK | **GPIO 18** | Hardware VSPI CLK |
| **I2C Bus (Reserved)** | SDA / SCL | **GPIO 21 / GPIO 22** | Reserved for DS3231 RTC or I2C sensors |

---

## 5. Software Architecture: BLE-First Telemetry

Instead of relying on Wi-Fi batch uploads that conflict with key-off power, the system uses a **BLE-First Streaming Architecture**:

```mermaid
flowchart LR
    A["Keihin ECU (CAN 500k)"] -->|ISO 15765-4 Mode 01| B["ESP32 Black Box"]
    B -->|Local Flight Log| C["MicroSD Card (FAT32 CSV)"]
    B -->|BLE GATT Notify (20 Hz)| D["ThrottleIQ Flutter App (Handlebar)"]
    D -->|Fused Telemetry GPS + OBD| E["Supabase Cloud"]
```

1. **Live Riding Mode:** 
   - ESP32 acts as a BLE GATT Server broadcasting custom service `0x181E` (ThrottleIQ Telemetry).
   - The ThrottleIQ Flutter app connects automatically when the rider mounts the bike.
   - Real-time engine parameters (RPM, Speed, Throttle %, Engine Oil Temp) stream to the mobile dashboard at 10–20 Hz.
   - The ThrottleIQ app already manages ride tracking, GPS location, lean angles, and cellular data. It fuses the OBD stream directly into the ride session.
2. **Key-Off & Upload:**
   - When the ride ends and the key is switched off, ThrottleIQ automatically closes the ride and uploads the enriched ride log to Supabase via 4G/5G/Wi-Fi. No bike-side Wi-Fi credentials or hotspot tethering required!
3. **Offline Black Box Mode:**
   - If the rider travels without their phone, the ESP32 still logs all frames locally to the MicroSD card. Files can be retrieved via USB or synced when the app connects next.

---

## 6. Production Firmware Sketch

Tested ESP-IDF / Arduino ESP32 implementation using native TWAI driver, non-blocking PID polling, and response decoding:

```cpp
#include <Arduino.h>
#include "driver/twai.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define CAN_TX_PIN   GPIO_NUM_2
#define CAN_RX_PIN   GPIO_NUM_4
#define CAN_RS_PIN   GPIO_NUM_13

#define OBD_REQ_ID   0x7DF
#define OBD_RESP_ID  0x7E8

// Mode 01 PIDs
#define PID_RPM      0x0C
#define PID_SPEED    0x0D
#define PID_THROTTLE 0x11
#define PID_EOT      0x05 // Engine Oil Temperature (Cylinder Head)

struct VehicleTelemetry {
  uint16_t rpm = 0;
  uint8_t speed_kmh = 0;
  float throttle_pct = 0.0f;
  int16_t engine_temp_c = 0;
  uint32_t last_bus_activity = 0;
} telemetry;

// BLE Telemetry Service
#define SERVICE_UUID        "91bad492-b950-4226-aa2b-4ede9fa42f59"
#define CHARACTERISTIC_UUID "cba1d466-344c-4be3-ab3f-189f80dd7518"
BLECharacteristic *pTelemetryChar = nullptr;
bool bleConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { bleConnected = true; }
  void onDisconnect(BLEServer* pServer) {
    bleConnected = false;
    BLEDevice::startAdvertising();
  }
};

void setup_twai() {
  pinMode(CAN_RS_PIN, OUTPUT);
  digitalWrite(CAN_RS_PIN, LOW); // High-speed normal mode

  twai_general_config_t g_config = TWAI_GENERAL_CONFIG_DEFAULT(CAN_TX_PIN, CAN_RX_PIN, TWAI_MODE_NORMAL);
  twai_timing_config_t t_config = TWAI_TIMING_CONFIG_500KBITS();
  twai_filter_config_t f_config = TWAI_FILTER_CONFIG_ACCEPT_ALL();

  ESP_ERROR_CHECK(twai_driver_install(&g_config, &t_config, &f_config));
  ESP_ERROR_CHECK(twai_start());
}

void send_pid_query(uint8_t pid) {
  twai_message_t msg;
  msg.identifier = OBD_REQ_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;
  msg.data[0] = 0x02; // Number of additional bytes
  msg.data[1] = 0x01; // Mode 01 (Live Data)
  msg.data[2] = pid;  // PID requested
  msg.data[3] = 0xAA; msg.data[4] = 0xAA; msg.data[5] = 0xAA; msg.data[6] = 0xAA; msg.data[7] = 0xAA;
  twai_transmit(&msg, pdMS_TO_TICKS(50));
}

void read_can_responses() {
  twai_message_t rx_msg;
  while (twai_receive(&rx_msg, 0) == ESP_OK) {
    telemetry.last_bus_activity = millis();

    // Standard OBD response check: ID 0x7E8, Mode 01 response (0x41)
    if (rx_msg.identifier == OBD_RESP_ID && rx_msg.data[1] == 0x41) {
      uint8_t pid = rx_msg.data[2];
      switch (pid) {
        case PID_RPM:
          telemetry.rpm = ((rx_msg.data[3] * 256) + rx_msg.data[4]) / 4;
          break;
        case PID_SPEED:
          telemetry.speed_kmh = rx_msg.data[3];
          break;
        case PID_THROTTLE:
          telemetry.throttle_pct = (rx_msg.data[3] * 100.0f) / 255.0f;
          break;
        case PID_EOT:
          telemetry.engine_temp_c = (int16_t)rx_msg.data[3] - 40;
          break;
      }
    }
  }
}

void enter_deep_sleep() {
  twai_stop();
  twai_driver_uninstall();
  digitalWrite(CAN_RS_PIN, HIGH); // Set transceiver to standby mode

  // Configure CAN RX pin (GPIO 4) as wake-up trigger on LOW edge (CAN bus activity)
  esp_sleep_enable_ext0_wakeup(CAN_RX_PIN, 0);
  esp_deep_sleep_start();
}

void setup() {
  Serial.begin(115200);
  setup_twai();

  // BLE Setup
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

  telemetry.last_bus_activity = millis();
}

void loop() {
  static uint8_t pid_cycle = 0;
  static uint32_t last_poll = 0;

  // Poll 10 times a second (cycle through PIDs)
  if (millis() - last_poll >= 25) {
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

  // Broadcast telemetry via BLE at 10 Hz
  static uint32_t last_ble = 0;
  if (bleConnected && millis() - last_ble >= 100) {
    last_ble = millis();
    uint8_t payload[8];
    payload[0] = (telemetry.rpm >> 8) & 0xFF;
    payload[1] = telemetry.rpm & 0xFF;
    payload[2] = telemetry.speed_kmh;
    payload[3] = (uint8_t)telemetry.throttle_pct;
    payload[4] = (uint8_t)(telemetry.engine_temp_c + 40);
    pTelemetryChar->setValue(payload, 5);
    pTelemetryChar->notify();
  }

  // If bike ignition is turned off, enter deep sleep after 30 seconds of inactivity
  if (millis() - telemetry.last_bus_activity > 30000) {
    enter_deep_sleep();
  }
}
```

---

## 7. Supabase Database Schema

Enriched ride telemetries uploaded by the ThrottleIQ app:

```sql
-- Main Ride Sessions
CREATE TABLE public.rides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  vehicle_id VARCHAR(64) NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  total_distance_km NUMERIC(6, 2) DEFAULT 0,
  max_rpm INTEGER DEFAULT 0,
  max_speed_kmh INTEGER DEFAULT 0,
  max_engine_temp_c INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- High-Frequency Telemetry Points (batched from mobile app)
CREATE TABLE public.ride_telemetry (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ride_id UUID REFERENCES public.rides(id) ON DELETE CASCADE NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  engine_rpm INTEGER,
  speed_kmh INTEGER,
  throttle_position NUMERIC(5, 2),
  engine_temp_c INTEGER,
  lean_angle NUMERIC(5, 2)
);

CREATE INDEX idx_ride_telemetry_ride_time ON public.ride_telemetry (ride_id, timestamp);
CREATE INDEX idx_rides_user_time ON public.rides (user_id, start_time DESC);

-- Enable RLS
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_telemetry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users access own rides" ON public.rides
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users access own ride telemetry" ON public.ride_telemetry
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.rides WHERE id = ride_telemetry.ride_id AND user_id = auth.uid())
  );
```

---

## 8. Implementation Steps & Verification Plan

1. **Bench Assembly (No bike needed):**
   - Wire ESP32 to SN65HVD230 transceiver and MP1584EN buck module on a breadboard.
   - Adjust MP1584 output potentiometer to exactly **5.00 V** using a 12V bench power supply.
   - Desolder the 120 Ω surface-mount resistor (`R2`) on the SN65HVD230 module.
2. **On-Bike Port Verification:**
   - Locate the Red 6-pin connector under the rider seat.
   - Follow the 4-step multimeter verification in [protocol-discovery.md](file:///Users/blackbird/Everything/dev/products/ThrottleIQ/DOCS/blackbox/protocol-discovery.md) (check Ground continuity, 12V constant power, 2.5V CAN bias, and 60 Ω bus impedance).
3. **Listen-Only Validation:**
   - Plug the Euro 5 adapter cable into the diagnostic port.
   - Flash the ESP32 in `TWAI_MODE_LISTEN_ONLY` and log received raw CAN frames over serial. Blip throttle and observe frame IDs changing.
4. **Active Mode 01 PID Polling:**
   - Switch to `TWAI_MODE_NORMAL`. Poll PID `0x0C` (RPM) and `0x11` (Throttle) and verify ECU responses on `0x7E8`.
5. **ThrottleIQ Mobile BLE Integration:**
   - Connect the ThrottleIQ Flutter app via BLE.
   - Confirm real-time tachometer and throttle graphs animate on the handlebar screen.
6. **Enclosure & Under-Seat Weatherproofing:**
   - Transfer circuit to a compact perfboard. Apply conformal coating to prevent water and vibration damage. Place in IP65 enclosure under the seat.

