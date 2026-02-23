# Verification Architecture

This directory contains a UVM-like verification environment
for the DDR4 Memory Controller.

The testbench validates functional correctness, protocol compliance,
and DRAM timing behavior.

---

## Verification Overview

<img src="verification_overview.png" width="100%">

---

## Architecture Components

### 1️⃣ AXI Driver (Stimulus Generator)

- Generates AXI-compliant traffic:
  - AXI-AR (Read Address)
  - AXI-AW (Write Address)
  - AXI-W  (Write Data)
- Supports out-of-order and burst-based transactions
- Configurable traffic generation patterns

---

### 2️⃣ Monitor

The monitor observes both:

- Cache ↔ Memory Controller events
- DDR CMD/ADDR and DQ bus activity

It extracts:

- Read/Write request issue events
- Read/Write response events
- DRAM command issuance timing
- Data burst timing

All extracted events are forwarded to the Scoreboard.

---

### 3️⃣ Scoreboard

The scoreboard performs:

- AXI ID/User matching (Req ↔ Resp)
- DRAM timing validation:
  - tCL
  - tCWL
  - tCCD
  - tRCD
- Deadlock detection
- Data burst timing validation

Verification results are summarized at simulation end.

---

### 4️⃣ DDR BFM

The BFM models:

- Multi-channel DDR interface
- Rank/Bank behavior
- Timing-accurate command handling
- Burst-based data transfer

The BFM interacts with the DUT via:
- CMD/ADDR bus
- DQ bus
- DQS signaling

---

## Verification Strategy

The testbench follows a layered architecture:

Driver → DUT → Monitor → Scoreboard

The DUT is validated against:

- AXI protocol correctness
- DRAM timing constraints
- Scheduling fairness
- Data consistency
- Starvation handling

---

## Simulation Flow

Run using:

```bash
./scripts/run_sim_xsim.sh
