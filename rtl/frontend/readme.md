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

아래는 요청하신 Memory Controller – Frontend Architecture 문서의 한국어 해석입니다.
원문의 구조(제목, 목록, 강조)를 유지하면서 기술적 의미를 정확히 옮겼습니다.


---

메모리 컨트롤러 – 프론트엔드 아키텍처

개요 (Overview)

프론트엔드는 AXI 기반 캐시 요청과 AXI 기반 캐시 응답을 처리하고,
주소 변환, 요청 분류, 중재(arbitration)를 수행한 뒤
메모리 트랜잭션을 백엔드 실행 유닛으로 전달하는 역할을 담당한다.

프론트엔드는 Read와 Write 트래픽을 분리하여 관리하며,
요청 큐를 관리하고 채널 간 공정하고 결정론적인 중재를 보장한다.


---

아키텍처 다이어그램

<img width="942" height="654" alt="image" src="https://github.com/user-attachments/assets/ef0a6276-4374-4758-9dec-298d1308d882" />


---

주요 책임 (Responsibilities)

프론트엔드는 다음 기능들을 수행한다.

1. AXI 요청 처리

AXI-AR(Read) 및 AXI-AW/W(Write) 요청을 수신

다중 ID, 다중 User 요청 스트림을 지원


2. 주소 변환 (고정 주소 매핑 방식: CH–RK–BG–BK–ROW–COL)

AXI 물리 주소를 구조화된 DRAM 주소 필드로 변환

Channel

Rank

Bank Group

Bank

Row

Column



3. Write Assembly

AXI-AW(Address Write)와 AXI-W(Write Data) 트랜잭션을 결합

백엔드로 전달하기 전에 Write 버스트가 완전히 조립되었는지 보장


4. 요청 큐 관리

Read 요청과 Write 요청을 분리된 큐로 관리

구조적 해저드(structural hazard) 방지


5. 메모리 컨트롤러 요청 중재 (MC Request Arbitration)

백엔드로 전달할 다음 요청을 선택

Read/Write 스트림 간 공정성 보장


6. 캐시 응답 경로 제어

백엔드로부터 Read 데이터와 Write ACK를 수집

AXI-R(Read Response) 및 AXI-B(Write Response) 응답을 중재



---

스케줄링 정책 (Scheduling Policy)

프론트엔드는 메모리 컨트롤러 요청(MC Request) 에 대해
큐 기반 스케줄링 메커니즘을 적용한다.


---

Read / Write 요청 스케줄링

Read 요청과 Write 요청은 각각 독립된 큐에 저장됨

요청 선택 기준:

큐에 요청이 존재하는지 여부

백엔드의 준비 상태

Write Assembly 완료 여부



우선순위 동작

조립이 완료된 Write 요청이 가장 높은 우선순위를 가짐

조립된 Write 요청이 없을 경우, Read 요청을 백엔드로 전달



---

Write 응답 처리 (Write Response Handling)

Write Buffer Controller가 Write 데이터 완료를 확인하면, Write ACK 응답은 즉시 캐시로 전달됨

Write ACK에 대해서는 추가적인 재정렬(reordering)이나 지연이 없음



---

Read 응답 스케줄링 (Read Response Scheduling)

Read 응답은 다음 기준에 따라 선택된다.

• 채널별 Read Buffer 깊이

Read 버퍼가 더 깊은 채널을 우선 처리하여 버퍼 혼잡(buffer congestion)을 방지


• 채널 서비스 횟수 (Aging 메커니즘)

현재 채널에서 연속적으로 서비스한 Read 응답 횟수를 추적

해당 횟수가 사전 정의된 임계치에 도달하면, 다른 채널로 전환하여 starvation을 방지



---

우선순위 동작 요약

Write ACK와 Read 응답 간에 고정 우선순위는 없음
(AXI-B 버스와 AXI-R 버스가 분리되어 있음)

채널 간 공정성은 서비스 횟수 기반 Aging 메커니즘으로 보장됨

이를 통해 처리량 균형을 유지하면서 장기적인 starvation을 방지함



---

원하시면 다음 주제도 이어서 설명해 드릴 수 있습니다:

왜 Write는 “조립 완료 후 선점(preemptive)” 구조인지

Read 응답에서 buffer-depth 기반 우선순위가 필요한 이유

Frontend ↔ Backend 인터페이스 신호 정의

AXI ID/User 기반 Write Assembly의 정확성 보장 방식
