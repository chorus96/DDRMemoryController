# Memory Controller – Backend Architecture

## Overview

The backend is responsible for DRAM command generation, Channel mode scheduling
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


## Channel Mode Scheduling for Read/Write Request

The Channel Mode determines how the CMD/Addr and DQ buses are utilized for Read and Write requests.

Channel mode is selected using : 

- Request Volume: The total number of pending Read and Write requests across all ranks.
- Transition Readiness: Ready signals for channel transition received from the PHY Controller and individual ranks.
- Subsystem Status: Idle signals from the Bank Finite State Machines (FSMs).

**Priority Behavior**
- Primary Priority: Read Mode is maintained by default to prioritize Read requests.
- Write Mode Entry Condition: The system transitions to Write Mode only when the number of pending write requests reaches a predefined boundary:
  - Condition: $Min\_bound < \text{Number of Write Requests} < Max\_bound$.
  - Once this range is met or there is no read requests in ranks, the controller switches to Write Mode to service the accumulated write traffic.

## Rank Grant Scheduling Policy (Rank-level Parallelism)

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

## Bank Grant Scheduling Policy (Maximizing Bank-level Parallelism)

The Bank Grant Scheduler selects the target bank based on the following criteria:

- Bank Status: Idle signal from the Bank Finite State Machine (FSM).
- Operational Context: Current Read/Write Channel Mode.
- FR-FCFS Scheduling Algorithm: Requests are prioritized in the following order:
  - Starvation Avoidance (Age): Highest priority is given to the oldest pending requests (Maximum wait time) to prevent starvation
  - Page Policy (Efficiency):
    - Page Hit (Short): Same bank group as the previously serviced request.
    - Page Hit (Long): Different bank group from the previously serviced request.
  - Arrival Order: Standard FCFS (First-Come, First-Served)
 

## READ/WRITE BURST TIMING SCHEDULING (tCWL, tCL)

Since there is no explicit handshake for data bursting between the DRAM and the Memory Controller, 
the controller must precisely track the timing of data service to ensure bus synchronization.

**Read Request Flow **

1. Command Acknowledgment: The Channel Scheduler issues a READ CMD ACK signal to the PHY Controller once the Read command is successfully dispatched on the CMD/ADDR bus.
2. Deterministic Latency: The PHY Controller independently enforces the CAS Latency (tCL).
3. Data Capture: Upon the expiration of tCL, the PHY prepares its internal logic to receive and capture the incoming READ DATA BURST from the DRAM.

**Write Request Flow**

1. Command Acknowledgment: The Channel Scheduler issues a WRITE CMD ACK signal to the PHY Controller when the Write command is dispatched on the CMD/ADDR bus.
2. Deterministic Latency: The PHY Controller independently enforces the CAS Write Latency (tCWL).
3. Data Transmission: At the precise timing dictated by tCWL, the PHY initiates the WRITE DATA BURST transmission to the DRAM.


## Bank Finite State Machine (FSM) & Timing Management

The Bank FSM manages the operational states of each bank, ensuring compliance with DRAM timing constraints through a centralized timer mechanism.

<img width="972" height="425" alt="image" src="https://github.com/user-attachments/assets/2659534c-05f6-45b9-9532-f44403445e90" />

**Load Timer State**

The Load Timer state is a critical synchronization point that enforces deterministic latencies required for stable DRAM operations:

1. Timing Enforcement: It manages bank-specific constraints, including tRCD (Row Address to Column Address Delay), tRP (Row Precharge Time), and tRFC (Refresh Cycle Time).

**Auto-Precharge (AP) Flow**

The timing for Auto-Precharge operations is managed by the APTimingScheduler within the RankExecutionUnit.

1. AP Enrollment: When an AP-READ or AP-WRITE command is issued, the RankExecutionUnit registers the target bank in the AP Scheduler as a candidate for precharge.
2. Command Acknowledgment (Channel Scheduler): The Channel Scheduler issues an AP-CMD ACK to the PHY Controller. The PHY then tracks this command to generate a subsequent acknowledgment after the data burst is completed.
3. Data Burst Confirmation (PHY Controller): Once the burst is finished, the PHY Controller sends an AP DATA BURST ACK signal back to the Channel Scheduler, which is then relayed to the RankExecutionUnit.
4. Final Timing Enforcement: The AP Scheduler enforces the remaining recovery timings before allowing the bank to return to the IDLE state:
   - AP-READ: Calculates and enforces tRP.
   - AP-WRITE: Calculates and enforces tWR + tRP to ensure data is fully restored before precharging.
   - Resource Locking: During this period, the Rank Scheduler blocks any new requests to the bank to prevent resource conflicts.



























<img width="972" height="418" alt="image" src="https://github.com/user-attachments/assets/d863f297-a5fe-4417-ae9c-63ea11d0026b" />
