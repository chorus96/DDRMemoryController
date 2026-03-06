# Memory Controller – Frontend Architecture

## Overview

**The frontend is responsible for handling AXI-based cache requests, AXI-based cache response, 
performing address translation, request classification, and arbitration
before forwarding memory transactions to the backend execution units.**

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

**Priority Behavior**
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

**Priority Behavior**

- There is no fixed priority between Write ACK and Read responses (seperate channels for AXI-B bus and AXI-R bus).
- Fairness across channels is enforced using the serving-count-based aging mechanism.
- This ensures balanced throughput while avoiding long-term starvation.

---

# 메모리 컨트롤러 – 프론트엔드 아키텍처

## 개요

**프론트엔드는 AXI 기반 캐시 요청과 AXI 기반 캐시 응답을 처리하고,  
주소 변환(Address Translation), 요청 분류(Request Classification), 그리고 중재(Arbitration)를 수행한 후  
메모리 트랜잭션을 백엔드 실행 유닛으로 전달하는 역할을 담당합니다.**

프론트엔드는 읽기(Read)와 쓰기(Write) 트래픽을 분리하여 처리하고, 요청 큐를 관리하며,  
채널 간 공정하고 결정적인 중재(arbitration)가 이루어지도록 보장합니다.

---

## 아키텍처 다이어그램
<img width="942" height="654" alt="image" src="https://github.com/user-attachments/assets/ef0a6276-4374-4758-9dec-298d1308d882" />

---

## 역할 (Responsibilities)

프론트엔드는 다음과 같은 기능을 수행합니다.

1. **AXI 요청 처리 (AXI Request Handling)**  
   - AXI-AR(Read) 및 AXI-AW/W(Write) 요청을 수신합니다.  
   - 다중 ID 및 다중 사용자(Multi-ID, Multi-user) 요청 스트림을 지원합니다.

2. **주소 변환 (Address Translation)**  
   **(고정 주소 변환 방식: CH-RK-BG-BK-ROW-COL)**  

   - AXI 물리 주소를 구조화된 DRAM 필드로 변환합니다.
     - Channel  
     - Rank  
     - Bank Group  
     - Bank  
     - Row  
     - Column  

3. **Write Assembly**  
   - AW와 W 트랜잭션을 결합합니다.  
   - 백엔드로 전달하기 전에 Write Burst가 완전히 수집되었는지 확인합니다.

4. **요청 큐 관리 (Request Queue Management)**  
   - Read 요청 큐와 Write 요청 큐를 분리하여 관리합니다.  
   - 구조적 충돌(Structural Hazards)을 방지합니다.

5. **메모리 컨트롤러 요청 중재 (MC Request Arbitration)**  
   - 백엔드로 전달할 다음 요청을 선택합니다.  
   - Read와 Write 요청 스트림 간 공정성을 보장합니다.

6. **캐시 응답 경로 제어 (Cache Response Path Control)**  
   - 백엔드에서 전달되는 Read 데이터와 Write ACK를 수집합니다.  
   - AXI-R 및 AXI-B 응답을 중재합니다.

---

## 스케줄링 정책 (Scheduling Policy)

프론트엔드는 **메모리 컨트롤러 요청(Memory Controller Request)**에 대해  
큐 기반 스케줄링 메커니즘을 적용합니다.

### Read/Write 요청 스케줄링

- Read 요청과 Write 요청은 **독립적인 큐**에 저장됩니다.  
- 요청 선택은 다음 요소들을 기준으로 이루어집니다.

  - 큐의 가용성 (Queue availability)  
  - 백엔드 준비 상태 (Backend readiness)  
  - Write Assembly 완료 여부 (Write Assembly availability)

**우선순위 동작 (Priority Behavior)**

- 조립이 완료된 Write 요청이 **가장 높은 우선순위**를 가집니다.  
- 조립된 Write 요청이 없는 경우에는 **Read 요청을 백엔드로 전달**합니다.

---

### Write 응답 처리 (Write Response Handling)

- Write ACK 응답은 Write Buffer Controller가 **쓰기 데이터 완료를 확인하는 즉시** 캐시로 전달됩니다.  
- Write ACK에 대해서는 추가적인 재정렬(reordering)이나 지연(delay)이 발생하지 않습니다.

---

### Read 응답 스케줄링 (Read Response Scheduling)

Read 응답은 다음 기준에 따라 선택됩니다.

- **채널별 Read Buffer Depth**
  - Read 버퍼가 더 깊은 채널을 우선 처리하여 버퍼 혼잡을 방지합니다.

- **채널 서비스 횟수 (Aging Mechanism)**
  - 현재 채널에서 연속적으로 처리된 Read 응답 횟수를 추적합니다.  
  - 이 서비스 횟수가 미리 정의된 임계값에 도달하면,  
    기아(starvation)를 방지하기 위해 스케줄러는 다른 채널로 전환합니다.

**우선순위 동작 (Priority Behavior)**

- Write ACK과 Read 응답 사이에는 **고정된 우선순위가 없습니다**  
  (AXI-B 버스와 AXI-R 버스가 서로 분리되어 있기 때문입니다).

- 채널 간 공정성은 **서비스 횟수 기반 Aging 메커니즘**을 통해 보장됩니다.

- 이를 통해 전체 처리량(throughput)을 균형 있게 유지하면서  
  장기적인 기아(starvation)를 방지합니다.
