# RTL Architecture Overview

The RTL directory contains the synthesizable implementation of a multi-channel DDR4 Memory Controller.

The design is hierarchically structured into:

- Frontend (Request/Repsonse arbitration + scheduling)
- Backend (Rank/Bank-level parallelism + RD/WR Data serving/receiving)


## Architecture Diagram
<img width="1217" height="668" alt="image" src="https://github.com/user-attachments/assets/7a7d33bc-419a-4fe0-a23f-541d6ba05639" />



## Directory Structure

rtl/
 ├── frontend/   → AXI handling, request arbitration, response scheduling..
 ├── backend/    → Rank/Bank scheduling, timing enforcement, FSM, data burst management..
 ├── common/     → Shared definitions and interfaces..
 ├── MemoryController.sv → Multi-channel DDR Memory Controller


 ## Management policy & DRAM Timing Constraints

Cache Request Interface & Write Assembly
  - Read Requests: Captured via the AXI-AR (Address Read) channel.
  - Write Requests: Received through the AXI-AW (Address Write) and AXI-W (Write Data) channels.
  - Write Data Assembly: Since AXI address and data packets can arrive out of phase, a dedicated assembly process is required.
    - The system synchronizes the AXI-AW and AXI-W channels by matching their respective ID and User signals.

Cache Response
  - Read Response (AXI-R Bus): Depth-based priority selection with an Aging scheme.
  - Write Response (AXI-B Bus): Transparent pass-through with no additional scheduling

Memory controller Request
  - Read Request: Transparent pass-through when no assembled write requests are pending.
  - Write Request: Preemptive serving once AXI-AW and AXI-W channels are successfully assembled (matched via ID/User).

CMD/ADDR, DQ Bus Channel 
  - Read-priority scheduling with a threshold-based transition for pending write requests.

Rank Grant Scheduling
  - Depth-based priority selection with LFSR-based tie-breaking and LSB-priority fallback.

Bank Grant Scheduling 
  - FR-FCFS with Bank Group-level parallelism, prioritizing Page-Hits based on timing constraints (Short/Long).

Open page List 
  - Forced page precharge triggered by a starvation threshold to ensure request fairness.

Auto-precharge CMD Window
  - Upon triggering a starvation signal in the OpenPageList, the Rank Scheduler is blocked from accessing the bank during the recovery period ($tRP+tWR$ for writes or $tRP$ for reads) to ensure a safe transition.

Read/Write Data Bust Request Window
  - PHY-managed Data Burst Windows for deterministic metadata (i.e., address of Read/Write data) synchronization, mapping anonymous DRAM bursts to specific Read/Write Buffer requests
