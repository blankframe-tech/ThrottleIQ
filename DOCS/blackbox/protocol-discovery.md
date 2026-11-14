# Protocol discovery: XPulse 200 4V Pro diagnostic port

Goal: learn the protocol (CAN or K-line), the 6-pin pinout and a cable that works, before buying parts.

Not found in manuals, launch coverage or forums (searched 2026-11-14). Known: the 2023 update made the bike OBD-II and E20 compliant with a malfunction lamp; Hero's HIDI tool talks CAN, LIN or K-line through a 6-pin connector.

## Method

1. Get the pinout for this exact bike (service tech or workshop manual). Don't probe blind.
2. Ignition on, measure: two pins near 2.5 V suggests CAN; one pin near battery voltage suggests K-line.
3. Or use an ELM327 with a 6-to-16-pin adapter and read the protocol it reports (beware fake clones).

Service centre is the most reliable source for the pinout; owners who have used an ELM327 are the best source for the protocol. Ask for a photo of the connector.

## Message: owners' group / forum

Hi everyone, I own a Hero XPulse 200 4V Pro (Bangladesh market) and I'm working on a small data logging project. Has anyone here connected a scan tool or OBD adapter to the 6-pin diagnostic port?

I'm trying to find out:
1. Does the bike talk over CAN or K-line? (ISO 15765-4 vs ISO 14230 / 9141)
2. What is the pinout of the 6-pin connector? (power, ground, and data pins)
3. Which cable or adapter worked for you? (6-pin to 16-pin OBD2, and where you bought it)
4. If you used an ELM327 app like Torque or Car Scanner, which protocol did it show, and did it read RPM, speed, or throttle?

I don't want to probe the port blindly and risk shorting something, so any photo of the connector or a pinout diagram would help a lot. Thanks!

## Message: Hero service centre

Assalamu alaikum / Hello,

I have a Hero XPulse 200 4V Pro and I'd like to confirm some details about its diagnostic port for a personal project. Could you please tell me:

1. Which communication protocol the ECU uses on the diagnostic connector (CAN or K-line)?
2. The pin layout of the 6-pin diagnostic connector (which pins are battery +12V, ground, and data)?
3. Which Hero diagnostic tool or cable your workshop uses to connect to this bike?

If there is a workshop manual or wiring diagram you can share, that would be very helpful. Thank you.

## Answers log

| Date | Source | Protocol | Pinout | Cable |
|---|---|---|---|---|
| | | | | |
