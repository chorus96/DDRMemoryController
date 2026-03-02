# Memory Controller – Backend Architecture

## Architecture Diagram
<img width="1051" height="687" alt="image" src="https://github.com/user-attachments/assets/a2794179-c9d0-4941-98a7-88db08870040" />

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

---

Memory Controller – Backend Architecture 해석

1️⃣ Backend의 역할 (Overview)

Backend는 DRAM과 직접 상호작용하는 실행 영역으로, 다음 책임을 가집니다.

DRAM 명령(Command) 생성

Read/Write에 따른 채널 모드 스케줄링

모든 DRAM 타이밍 제약(timing constraint) 강제

Channel / Rank / Bank 단위 병렬성 관리

PHY와의 인터페이스 및 동기화


👉 Frontend가 요청 조립·중재를 담당한다면,
👉 Backend는 *“언제, 어떤 DRAM 명령을 실제로 낼 수 있는가”*를 책임집니다.


---

2️⃣ Backend의 계층적 구조

Backend는 다음과 같은 계층 구조로 구성됩니다.

Channel Controller

Rank Scheduler

Rank Execution Unit

Bank-level FSM 포함


DDR CMD/ADDR Bus, DQ Bus Arbiter

Read/Write Buffer Controller

PHY Controller


➡ 위에서 아래로 갈수록 구체적이고 물리적인 제어를 담당합니다.


---

3️⃣ Channel Mode Scheduling (Read / Write 모드)

Channel Mode의 의미

Channel Mode는 CMD/ADDR 버스와 DQ 버스를 Read 중심으로 쓸지, Write 중심으로 쓸지를 결정합니다.

Mode 결정 기준

전체 Rank에 쌓인 Read / Write 요청 개수

PHY 및 Rank로부터의 모드 전환 가능 신호

Bank FSM의 Idle 상태 여부


우선순위 정책

기본값은 Read Mode

Read latency 최소화 목적


Write Mode 전환 조건:

Write 요청 개수가 특정 범위에 들어올 때



Min\_bound < Write\_count < Max\_bound

➡ Write는 누적될 때만 의도적으로 몰아서 처리 (Write Drain)


---

4️⃣ Rank Grant Scheduling (Rank 단위 병렬성)

Rank 선택 시 고려 요소:

Rank Scheduler의 ready 신호

DRAM 타이밍 제약:

tRTRS, tRTW, tWTRS, tWTRL, tCCDS, tCCDL


현재 Channel Mode (Read / Write)

Rank별 Read/Write 요청 개수


우선순위 정책

1. 요청 depth가 가장 깊은 Rank 우선


2. 동률일 경우:

LFSR 기반 랜덤 선택

LSB 우선



3. 예외 처리:

랜덤 결과가 zero-vector면

LSB 기준으로 강제 선택




➡ Rank 간 부하 균형 + Starvation 방지


---

5️⃣ Bank Grant Scheduling (Bank 단위 병렬성 극대화)

Bank Scheduler는 다음 조건으로 Bank를 선택합니다.

Bank FSM이 Idle

현재 Channel Mode

FR-FCFS 스케줄링 알고리즘


FR-FCFS 우선순위 순서

1. Aging (기아 방지)

가장 오래 기다린 요청 우선



2. Page Policy (효율성)

Page Hit (Short): 같은 Bank Group

Page Hit (Long): 다른 Bank Group



3. FCFS

도착 순서




➡ Latency + Throughput + Fairness를 동시에 고려한 구조


---

6️⃣ READ / WRITE Burst 타이밍 관리 (tCL, tCWL)

DRAM과 Memory Controller 사이에는
“데이터가 오간다”는 명시적 handshake가 없음

➡ 따라서 정확한 타이밍 추적이 필수


---

🔹 Read 동작 흐름

1. Backend가 READ CMD를 CMD/ADDR 버스에 발행


2. Channel Scheduler가 READ CMD ACK를 PHY로 전달


3. PHY는 **tCL(CAS Latency)**를 내부적으로 카운트


4. tCL 후 DRAM이 DQ로 데이터를 내보내고


5. PHY가 이를 정확히 캡처




---

🔹 Write 동작 흐름

1. WRITE CMD 발행


2. Channel Scheduler가 WRITE CMD ACK를 PHY로 전달


3. PHY가 **tCWL(CAS Write Latency)**를 카운트


4. tCWL 시점에 PHY가 DQ로 Write Data Burst 전송



➡ CMD와 DQ 타이밍을 PHY가 결정론적으로 맞춤


---

7️⃣ Bank FSM & 타이밍 관리

각 Bank는 FSM으로 관리되며,
중앙 Timer를 통해 DRAM 제약을 강제합니다.

Load Timer State의 역할

tRCD (ACT → RD/WR)

tRP (PRE → ACT)

tRFC (REFRESH) 등 Bank 단위 필수 대기 시간 관리


➡ DRAM 안정성의 핵심 상태


---

8️⃣ Auto-Precharge (AP) 처리 흐름

AP는 Read/Write 이후 자동으로 Precharge 수행하는 동작입니다.

AP 처리 단계

1. AP 등록

AP-READ / AP-WRITE 발행 시

대상 Bank를 AP Scheduler에 등록



2. CMD ACK

Channel Scheduler → PHY



3. Data Burst 종료 ACK

PHY → Channel Scheduler → RankExecutionUnit



4. 최종 타이밍 강제

AP-READ: tRP

AP-WRITE: tWR + tRP



5. 자원 잠금

이 기간 동안 해당 Bank는 새 요청 차단




➡ 데이터 안정성 + Bank 충돌 방지


---

9️⃣ 전체 구조 한 줄 요약

> Frontend가 “무엇을 할지” 결정한다면,
Backend는 “언제 DRAM이 허용하는 방식으로 실행할지”를 책임진다.




---

원하시면 다음도 이어서 설명할 수 있습니다:

Channel Mode 전환 히스테리시스 설계

RankExecutionUnit 내부 FSM 상세

FR-FCFS에서 Page Hit Short/Long의 실제 성능 차이

PHY ACK 신호가 필요한 정확한 이유
