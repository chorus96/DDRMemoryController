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

# 메모리 컨트롤러 – 백엔드 아키텍처

## Architecture Diagram
<img width="1051" height="687" alt="image" src="https://github.com/user-attachments/assets/a2794179-c9d0-4941-98a7-88db08870040" />

## 아키텍처 개요

백엔드는 DRAM 명령 생성, 채널 모드 스케줄링, 타이밍 제약 준수, 채널/랭크/뱅크 수준 스케줄링, PHY 인터랙션을 담당합니다.

프론트엔드가 요청 조립(Request Assembly)과 요청/응답 중재(Request/Response Arbitration)를 관리하는 것과 달리,  
백엔드는 **모든 DRAM 타이밍 제약을 강제**하고 **랭크 및 뱅크 수준의 병렬성**을 관리합니다.

백엔드는 계층적으로 구성됩니다:

- Channel Controller  
- Rank Scheduler  
- Rank Execution Unit (Bank-level FSM 포함)  
- DDR CMD/ADDR Bus, DQ Bus Arbiter  
- Read/Write Buffer Controller  
- PHY Controller  


## 채널 모드 스케줄링 (Channel Mode Scheduling – Read/Write Request)

채널 모드는 Read와 Write 요청 시 CMD/ADDR 버스와 DQ 버스를 어떻게 사용할지를 결정합니다.

채널 모드는 다음에 따라 선택됩니다:

- **Request Volume**: 전체 랭크의 Read/Write 요청 개수  
- **Transition Readiness**: PHY Controller 및 개별 랭크로부터 수신한 채널 전환 준비 신호  
- **Subsystem Status**: 뱅크 FSM으로부터의 Idle 신호  


### 우선순위 동작 (Priority Behavior)

- **기본 우선순위**: 시스템은 기본적으로 Read Mode를 유지하여 Read 요청을 우선 처리합니다.  
- **Write Mode 진입 조건**: 쓰기 요청이 특정 임계 범위에 도달하면 시스템은 Write Mode로 전환합니다.  
  - 조건: ( Min_bound < Write Requests 수 < Max_bound )
  - 위 조건을 만족하거나 모든 랭크에 Read 요청이 없을 경우, 컨트롤러는 Write Mode로 전환되어 누적된 Write 트래픽을 처리합니다.  


## 랭크 그랜트 스케줄링 정책 (Rank Grant Scheduling Policy – Rank-level Parallelism)

랭크 선택은 다음 조건을 기준으로 이루어집니다:

- Rank Scheduler로부터의 Ready 신호 수신  
- 타이밍 제약 조건 준수 (예: tRTRS, tRTW, tWTRS, tWTRL, tCCDS, tCCDL)  
- 현재 Read/Write 채널 모드  
- 각 랭크의 요청 대기열(Queue) 깊이  


### 우선순위 동작

- **기본 우선순위**: 요청 대기열이 가장 긴 랭크를 우선 선택  
- **동일 깊이 랭크 처리 (Tie-breaking)**: 가장 깊은 랭크가 여러 개일 경우, LFSR(Random Selection) 과정을 사용하여 무작위 선택  
- **LSB 우선순위 결정**: LFSR 결과의 LSB를 기준으로 최종 선택  


### 폴백 메커니즘 (Zero-vector Handling)

LFSR 결과가 Zero-vector(선택 없음)인 경우, LSB 우선순위에 따라 사용 가능한 랭크를 선택합니다.  

**폴백 메커니즘(Fallback Mechanism)**은
원래 사용하려던 방법이 실패하거나 유효하지 않을 때, 시스템이 안정적으로 동작하도록 대체 방법을 사용하는 구조를 의미합니다.

## 뱅크 그랜트 스케줄링 정책 (Bank Grant Scheduling Policy – Bank-level Parallelism 극대화)

뱅크 스케줄러는 다음 기준에 따라 대상 뱅크를 선택합니다:

- **Bank Status**: 뱅크 FSM으로부터의 Idle 상태 신호  
- **Operational Context**: 현재 Read/Write 채널 모드  
- **FR-FCFS 스케줄링 알고리즘**: 다음 우선순위 순서로 요청 처리  

1. **Starvation 회피 (Age)**: 대기 시간이 가장 오래된 요청을 최우선으로 처리  
2. **페이지 정책 (Page Policy – 효율성)**  
   - Page Hit (Short): 이전 요청과 동일한 뱅크 그룹  
   - Page Hit (Long): 이전 요청과 다른 뱅크 그룹  
3. **도착 순서 (Arrival Order)**: FCFS(First-Come, First-Served) 방식  


## READ/WRITE 버스트 타이밍 스케줄링 (tCWL, tCL)

DRAM과 메모리 컨트롤러 간에 데이터 버스트 핸드셰이크가 존재하지 않기 때문에, 컨트롤러는 데이터 서비스 타이밍을 정확히 추적해야 버스 동기화를 보장할 수 있습니다.

### Read 요청 흐름

1. **Command Acknowledgment**: Channel Scheduler는 READ 명령이 CMD/ADDR 버스에 성공적으로 전송되면 PHY Controller에 READ CMD ACK 신호를 전달.  
2. **Deterministic Latency**: PHY Controller는 독립적으로 CAS Latency(tCL)를 적용.  
3. **Data Capture**: tCL 이후 PHY는 DRAM에서 수신되는 READ DATA BURST를 캡처할 준비를 함.  


### Write 요청 흐름

1. **Command Acknowledgment**: WRITE 명령이 CMD/ADDR 버스에 송신되면 Channel Scheduler는 PHY Controller에 WRITE CMD ACK 신호를 전송.  
2. **Deterministic Latency**: PHY Controller는 독립적으로 CAS Write Latency(tCWL)을 적용.  
3. **Data Transmission**: tCWL 타이밍에 따라 PHY가 WRITE DATA BURST 전송을 시작.  


## 뱅크 FSM 및 타이밍 관리 (Bank FSM & Timing Management)

Bank FSM은 각 뱅크의 동작 상태를 관리하고, 중앙 타이머 메커니즘을 통해 DRAM 타이밍 제약을 준수합니다.

<img width="972" height="425" alt="image" src="https://github.com/user-attachments/assets/2659534c-05f6-45b9-9532-f44403445e90" />

### Load Timer State

Load Timer 상태는 안정적인 DRAM 동작을 위해 결정적 지연(latency)을 강제하는 핵심 동기화 지점입니다:

1. **Timing Enforcement**: 은행별(tRCD, tRP, tRFC 등) 주요 타이밍 제약을 관리.  


## 오토 프리차지 (Auto-Precharge, AP) 동작

Auto-Precharge 타이밍은 RankExecutionUnit 내 **APTimingScheduler**에 의해 관리됩니다.

1. **AP 등록 (Enrollment)**: AP-READ 또는 AP-WRITE 명령이 발행되면 해당 뱅크가 AP Scheduler에 프리차지 후보로 등록.  
2. **명령 확인 (Command Acknowledgment)**: Channel Scheduler는 PHY Controller에 AP-CMD ACK를 전송하고 PHY는 데이터 버스트 완료 후 추가 ACK를 생성함.  
3. **데이터 버스트 확인 (Data Burst Confirmation)**: PHY Controller는 버스트 완료 시 AP DATA BURST ACK를 Channel Scheduler에 전송, 이후 RankExecutionUnit으로 전달됨.  
4. **최종 타이밍 강제 (Final Timing Enforcement)**: AP Scheduler는 복구 타이밍을 계산 및 적용 후, 뱅크를 IDLE 상태로 전환하기 전에 대기함.  
   - **AP-READ**: tRP 적용  
   - **AP-WRITE**: tWR + tRP 적용 (데이터 복원 완료 보장)  
5. **자원 잠금 (Resource Locking)**: 해당 기간 동안 Rank Scheduler는 해당 뱅크에 새로운 요청이 진입하지 못하도록 차단.  

<img width="972" height="425" alt="image" src="https://github.com/user-attachments/assets/2659534c-05f6-45b9-9532-f44403445e90" />
