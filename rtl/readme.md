# Memory Controller – Frontend Architecture

## Overview

The frontend is responsible for handling AXI-based cache requests,
performing address translation, request classification, and arbitration
before forwarding memory transactions to the backend execution units.

It separates read and write traffic, manages request queues,
and ensures fair and deterministic arbitration across channels.

---

## Architecture Diagram
<img width="942" height="654" alt="image" src="https://github.com/user-attachments/assets/ef0a6276-4374-4758-9dec-298d1308d882" />

---

## Responsibilities

The frontend performs the following functions:

1. **AXI Request Handling**
   - Accepts AXI-AR (Read) and AXI-AW/W (Write) requests.
   - Supports multi-ID and multi-user request streams

2. **Address Translation (Fixed Address translation scheme (CH-RK-BG-BK-ROL-COL)**
   - Converts AXI physical address into structured DRAM fields:
     - Channel
     - Rank
     - Bank Group
     - Bank
     - Row
     - Column

3. **Write Assembly**
   - Combines AW and W transactions
   - Ensures write burst completion before backend dispatch

4. **Request Queue Management**
   - Separate Read and Write request queues
   - Prevents structural hazards

5. **MC Request Arbitration**
   - Selects next request for backend dispatch
   - Ensures fairness between Read and Write streams

6. **Cache Response Path Control**
   - Collects read data and write ACK from backend
   - Arbitrates AXI-R and AXI-B responses

---

## Scheduling Policy

The frontend applies a queue-based scheduling mechanism for **Memory Controller Request**:

### Read/Write Request Scheduling

- Read and Write requests are stored in independent queues.
- Requests are selected based on:
  - Queue availability
  - Backend readiness
  - Write Assembly availability

Priority behavior:
- Highest priority for assembled write request.
- If there is no assembled write request yet, then serving read request to backend


### Write Response Handling

- Write ACK responses are immediately forwarded to the cache once the write buffer controller confirms write data completion.
- No additional reordering or delay is introduced for write acknowledgments.

### Read Response Scheduling

Read responses are selected based on:

- **Read Buffer Depth per Channel**
  - Channels with deeper read buffers are prioritized to prevent buffer congestion.

- **Channel Serving Count (Aging Mechanism)**
  - The number of consecutively served read responses for the current channel is tracked.
  - If the serving count reaches a predefined threshold, the scheduler switches to the other channel to prevent starvation.

### Priority Behavior

- There is no fixed priority between Write ACK and Read responses (seperate channels for AXI-B bus and AXI-R bus).
- Fairness across channels is enforced using the serving-count-based aging mechanism.
- This ensures balanced throughput while avoiding long-term starvation.
