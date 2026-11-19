# Protocol discovery: XPulse 200 4V Pro diagnostic port

Goal: verify and document the protocol (CAN vs K-line), the 6-pin connector pinout, wire colors, and adapter cables for the Hero XPulse 200 4V (BS6 / BS6 Phase 2 / OBD-2 / Pro).

## Claimed protocol & hardware specifications (UNVERIFIED, needs bench verification)

> [!WARNING]
> No primary source is cited for these claims, and pin numbering below is internally inconsistent in places (ECU harness pin vs 6-pin socket pin). Many motorcycles use K-line (ISO 14230 / ISO 9141) or proprietary connectors rather than J1962. Confirm with the multimeter checks below and a known-good scanner before building anything.

Claimed:

1. **Protocol:** **ISO 15765-4 CAN (Controller Area Network)** operating at **500 kbps** with standard 11-bit identifiers (broadcast request `0x7DF`, ECU response `0x7E8`). A 29-bit variant (request `0x18DB33F1`, response `0x18DAF1xx` where xx is the ECU address, e.g. `10`) exists in ISO 15765-4; whether this ECU uses it is unconfirmed.
2. **ECU:** **Keihin** 32-bit FI Engine Control Unit.
3. **Physical Connector:** 6-pin waterproof diagnostic socket (reportedly "Euro 5 / ISO 19689", unverified) (**Sumitomo TS 025 Sealed Series**, female housing part no. **6189-7963**, typically red housing located under the seat near the battery and ECU).
4. **Active Wires:** 4 wires populated in the 6-pin housing:
   - **Orange / White (O/W):** CAN High (`CAN-H`) — ECU-side pin number unverified. Recessive ~2.5 V; dominant ~3.5 V nominal (multimeter average roughly 2.5 V – 3.0 V).
   - **Blue / White (L/W):** CAN Low (`CAN-L`) — ECU-side pin number unverified. Recessive ~2.5 V; dominant ~1.5 V nominal (multimeter average roughly 2.0 V – 2.5 V).
   - **Red / Black (R/B):** Battery +12 V (**Constant unswitched battery power** via main fuse).
   - **Green (G):** Chassis / ECU Ground (0 V).
5. **Bus Resistance:** ~60 Ω measured across CAN-H and CAN-L with ignition off and battery disconnected (consistent with two 120 Ω terminators; ~120 Ω would mean only one).

---

## Connector Pinout & Wire Color Mapping

Looking directly into the front face of the **female diagnostic socket (Sumitomo 6189-7963)** on the motorcycle with the **locking latch at the top**:

```text
               [ Locking Latch ]
         +---------------------------+
         |   Pin 1   | Pin 2 | Pin 3 |  <- Top row
         |-----------+-------+-------|
         |   Pin 4   | Pin 5 | Pin 6 |  <- Bottom row
         +---------------------------+
```

### Pin-to-Signal & OBD-II (16-pin) Conversion

| Socket Pin | Hero Wire Color | Signal Function | Voltage (Ignition ON) | Standard OBD-II 16-Pin |
|---|---|---|---|---|
| **Pin 1** | *Unpopulated or OEM* | Switched / Vendor | N/A | Pin 1 |
| **Pin 2** | **Orange / White (O/W)** | **CAN High (`CAN+`)** | ~2.5 V – 3.3 V | **Pin 6** (`CAN High`) |
| **Pin 3** | **Green (G)** | **Chassis / Signal Ground** | 0.0 V (Continuity to GND) | **Pin 4 & Pin 5** (`Ground`) |
| **Pin 4** | **Red / Black (R/B)** | **Battery +12 V (Constant)** | ~12.4 V – 14.4 V | **Pin 16** (`+12V Power`) |
| **Pin 5** | **Blue / White (L/W)** | **CAN Low (`CAN-`)** | ~1.5 V – 2.5 V | **Pin 14** (`CAN Low`) |
| **Pin 6** | *Unpopulated* | Legacy K-Line | N/A | Pin 7 (`K-Line`) |

*(Note: pin numbers in this table are unverified. Note on pin numbering: Some aftermarket manufacturers number pins in columns `[1, 4]`, `[2, 5]`, `[3, 6]`. Always rely on wire colors and multimeter confirmation below rather than terminal numbering stamped on plastic shells).*

---

## Pre-Connection Multimeter Verification (Do NOT Skip)

Before plugging in any custom harness or ESP32 board, confirm these 4 checks with a digital multimeter:

1. **Ground Check (Ignition OFF):**
   - Probe the **Green wire** to battery negative terminal or bare engine/frame ground.
   - Multimeter in Continuity / Resistance mode: must show `< 0.5 Ω`.
2. **Power Check (Ignition OFF, then ON):**
   - Red probe on **Red/Black wire**, black probe on **Green wire**.
   - Voltage must read battery voltage (`~12.4 V – 12.8 V`).
   - Turn Key OFF: voltage remains `~12.4 V` (confirms unswitched battery line).
3. **CAN Bus Differential Voltages (Ignition ON):**
   - Red probe on **Orange/White wire**, black probe on **Green wire**: must read **2.4 V – 3.2 V**.
   - Red probe on **Blue/White wire**, black probe on **Green wire**: must read **1.8 V – 2.5 V**.
   - These are single-ended readings to ground; a multimeter averages the bus, so values are approximate. If either reads ~12 V, do not proceed (not a CAN signal; possibly K-line).
4. **CAN Bus Impedance (Ignition OFF, Battery Disconnected):**
   - Probe between **Orange/White** and **Blue/White**.
   - Resistance must read **~60 Ω** ($\pm 4\ \Omega$).
   - If reading ~60 Ω, the on-bike bus is already terminated. **You must remove / desolder the 120 Ω terminating resistor on the SN65HVD230 module** before connecting. If reading ~120 Ω, keep the module's resistor.

---

## Supported Mode 01 Parameter IDs (PIDs)

Standard SAE J1979 diagnostic queries over CAN ID `0x7DF`:

| PID (Hex) | Parameter | Formula | Scale / Unit |
|---|---|---|---|
| `0x00` | Supported PIDs `[01-20]` | Bitmask | Bit flags |
| `0x01` | Status since DTCs cleared | MIL status + DTC count | Bit flags |
| `0x04` | Calculated Engine Load | `(A * 100) / 255` | `0 – 100 %` |
| `0x05` | Engine Coolant Temp (ECT) per J1979 | `A - 40` | `-40 to +215 °C` (this oil-cooled engine may map it to an oil/head sensor: verify) |
| `0x5C` | Engine Oil Temp (J1979) | `A - 40` | `-40 to +210 °C` (support on this ECU unknown) |
| `0x0C` | Engine Speed (RPM) | `((A * 256) + B) / 4` | `0 – 16,383.75 rpm` |
| `0x0D` | Vehicle Speed | `A` | `0 – 255 km/h` |
| `0x0E` | Timing Advance | `(A / 2) - 64` | `-64 to +63.5 °` |
| `0x0F` | Intake Air Temp (IAT) | `A - 40` | `-40 to +215 °C` |
| `0x11` | Throttle Position (TPS) | `(A * 100) / 255` | `0 – 100 %` |

---

## Right to Repair: Diagnostic Trouble Code (DTC) Modes

To support the Right to Repair initiative (`labs/bd-moto-right-to-repair`), the diagnostic interface supports reading and resetting engine fault codes:

* **Mode 03 (Request Confirmed DTCs):** Query `0x7DF [0x01, 0x03, 0xAA...]` $\rightarrow$ ECU responds on `0x7E8` with active fault codes (e.g. `P0115` for Engine Coolant Temp sensor circuit fault, `P0122` for TPS/Throttle Position Sensor A circuit low input).
* **Mode 07 (Request Pending DTCs):** Reads pending faults detected during the current or last completed driving cycle, before the MIL lamp illuminates.
* **Mode 04 (Clear DTCs / Reset MIL):** Query `0x7DF [0x01, 0x04, 0xAA...]` $\rightarrow$ clears stored fault codes and turns off the Malfunction Indicator Lamp after mechanical repair. Record all codes first (freeze-frame data is erased too) and run it with the engine off.

---

## Phase 1 ELM327 Terminal Verification Commands

When testing with a generic ELM327 Bluetooth dongle connected via the Euro 5 adapter cable, send these standard AT commands over serial:

```text
AT Z         -> Reset ELM327
AT E0        -> Echo Off
AT SP 6      -> Force Protocol: ISO 15765-4 CAN (11 bit ID, 500 kbaud)
AT SH 7DF    -> Set Header to 0x7DF (Broadcast Request)
01 00        -> Query Supported PIDs (Expect: 41 00 [4 bytes bitmask])
01 0C        -> Query RPM (Expect: 41 0C [A] [B])
01 05        -> Query Engine Coolant Temp per J1979 (Expect: 41 05 [A])
01 5C        -> Query Engine Oil Temp (Expect: 41 5C [A], may be unsupported)
03           -> Read Confirmed Fault Codes (Expect: 43 [DTC count] [DTC bytes])
04           -> Clear Fault Codes (Expect: 44)
```

---

## Answers log

| Date | Source | Protocol | Pinout | Cable | Notes |
|---|---|---|---|---|---|
| 2026-11-14 | Hero MotoCorp BS6 Service Schematics & Training Manuals (Splendor+, Xpulse, Glamour) | **ISO 15765-4 CAN** (500 kbps, 11-bit) | R/B: +12V, G: GND, O/W: CAN-H, L/W: CAN-L (ECU pin numbers unverified) | Standard Euro 5 (ISO 19689) 6-pin to OBD-II 16-pin | Source claims are unverified and not independently cited. Pin numbering conflicts with the table above (socket pin 4 = +12 V there, ECU pin 4 = CAN-H here); resolve on the bench. |
| 2026-11-14 | Keihin Powertrain Technical Specifications & ECU Pin Mapping | CAN 2.0B / ISO 15765-4 | Differential CAN-H / CAN-L | Sumitomo 6189-7963 connector | Standard 500k baud, 0x7DF request, 0x7E8 response. Claims PIDs 0C, 0D, 11, 05 are supported: unverified; 05 is coolant temp per J1979. |
| 2026-11-14 | Daraz Bangladesh & Local Importers | Euro 5 Motorcycle Cable | 6-pin Sumitomo to 16-pin OBD2 Female | Daraz BD (৳650–1,200) | Red Euro 5 6-pin connector with OBD2 Pin 6/14 wired for CAN. |

