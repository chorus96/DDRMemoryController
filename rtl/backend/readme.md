# Memory Controller – Backend Architecture

## Overview

The backend is responsible for DRAM command generation,
timing enforcement, Channel/Rank/Bank-level scheduling, and PHY interaction.

Unlike the frontend (which manages request assembly and reqeust/response arbitration),
the backend enforces all DRAM timing constraints and manages
rank-level and bank-level parallelism.

The backend is organized hierarchically:

- Channel Controller
- Rank Scheduler
- Rank Execution Unit (including bank-level FSMs)
- DDR CMD/ADDR Bus, DQ Bus Arbiter
- Read/Write Buffer Controller
- PHY Controller


## Channel Controller

The Channel Controller manages per-channel request dispatch
and rank-level arbitration, Read/Write mode selection.

### Responsibilities

- Read/Write Request arbitration to specific ranks.
- Rank Grant Scheduling
- Channel-level DRAM Timing enforcement

### Channel-Level Timing Considerations

The Channel Controller enforces:

- tCCD (short/long based on bank-group)
- Bus conflicts (CMD/ADDR structural hazard)
- Read/Write turnaround constraints
- Data bus availability

Timing-aware rank grant scheduling prevents illegal command overlap
across ranks within the same channel.

### Rank Grant Scheduling Policy

Ranks are selected using:

- Receipt of a ready signal from the Rank Scheduler.
- Compliance with timing constraints (e.g., tRTRS, tRTW, tWTRS, tWTRL, tCCDS, tCCDL).
- The current Read/Write channel mode
- The number of pending Read/Write requests associated with each rank.

**Priority Behavior**
- Primary Priority: The rank with the highest request depth (queue occupancy) is selected first.
- Tie-breaking (Random Selection): If no single "deepest" rank exists, the selection defaults to a random process via LFSR.
  - The selection is determined based on LSB priority.
- Fallback Mechanism (Zero-vector Handling):
  - If the LFSR output results in a zero-vector (no selection), the system selects an available rank following LSB priority.****








































<img width="972" height="418" alt="image" src="https://github.com/user-attachments/assets/d863f297-a5fe-4417-ae9c-63ea11d0026b" />
