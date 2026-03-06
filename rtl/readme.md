# RTL Architecture Overview

The RTL directory contains the synthesizable implementation of a multi-channel DDR4 Memory Controller.

The architecture is hierarchically partitioned into:

- **Frontend** – Request/Response arbitration and scheduling
- **Backend** – Rank/Bank-level parallelism and timing-aware command execution


## Architecture Diagram
<img width="1217" height="668" alt="image" src="https://github.com/user-attachments/assets/7a7d33bc-419a-4fe0-a23f-541d6ba05639" />



## Directory Structure

```
rtl/
 ├── frontend/   → AXI handling, request arbitration, response scheduling
 ├── backend/    → Rank/Bank scheduling, timing enforcement, FSM, data burst control
 ├── common/     → Shared definitions and interfaces
 ├── MemoryController.sv → Top-level multi-channel controller
```

 ## Management policy & DRAM Timing Constraints

**Cache Request Interface & Write Assembly**
  - Read Requests: Captured via the AXI-AR (Address Read) channel.
  - Write Requests: Received through the AXI-AW (Address Write) and AXI-W (Write Data) channels.
  - Write Data Assembly: Since AXI address and data packets can arrive out of phase, a dedicated assembly process is required.
    - The system synchronizes the AXI-AW and AXI-W channels by matching their respective ID and User signals.

**Cache Response**
 - Read Response (AXI-R Bus): Depth-based priority selection with an Aging scheme.
 - Write Response (AXI-B Bus): Transparent pass-through with no additional scheduling

**Memory controller Request**
  - Read Request: Transparent pass-through when no assembled write requests are pending.
  - Write Request: Preemptive serving once AXI-AW and AXI-W channels are successfully assembled (matched via ID/User).

**CMD/ADDR, DQ Bus Channel**
 - Read-priority scheduling with a threshold-based transition for pending write requests.

**Rank Grant Scheduling**
  - Depth-based priority selection with LFSR-based tie-breaking and LSB-priority fallback.

**Bank Grant Scheduling** 
  - FR-FCFS with Bank Group-level parallelism, prioritizing Page-Hits based on timing constraints (Short/Long).

**Open page List**
  - Forced page precharge triggered by a starvation threshold to ensure request fairness.

**Auto-precharge CMD Window**
  - Upon triggering a starvation signal in the OpenPageList, the Rank Scheduler is blocked from accessing the bank during the recovery period ($tRP+tWR$ for writes or $tRP$ for reads) to ensure a safe transition.

**Read/Write Data Bust Request Window**
  - PHY-managed Data Burst Windows for deterministic metadata (i.e., address of Read/Write data) synchronization, mapping anonymous DRAM bursts to specific Read/Write Buffer requests

***

# RTL 아키텍처 개요

RTL 디렉토리는 다중 채널 DDR4 메모리 컨트롤러의 합성 가능한 구현을 포함합니다.

아키텍처는 계층적으로 다음과 같이 분할되어 있습니다:

- **Frontend** – 요청/응답 중재 및 스케줄링  
- **Backend** – Rank/Bank 수준 병렬성 및 타이밍 인식 명령 실행  


## 아키텍처 다이어그램
<img width="1217" height="668" alt="image" src="https://github.com/user-attachments/assets/7a7d33bc-419a-4fe0-a23f-541d6ba05639" />


## 디렉토리 구조

```text
rtl/
 ├── frontend/   → AXI 처리, 요청 중재, 응답 스케줄링
 ├── backend/    → Rank/Bank 스케줄링, 타이밍 제약 관리, FSM, 데이터 버스트 제어
 ├── common/     → 공통 정의 및 인터페이스
 ├── MemoryController.sv → 최상위 다중 채널 컨트롤러
```

## 관리 정책 및 DRAM 타이밍 제약

**캐시 요청 인터페이스 및 쓰기 조립(Write Assembly)**  
  - 읽기 요청(Read Requests): AXI-AR (Address Read) 채널을 통해 캡처됩니다.  
  - 쓰기 요청(Write Requests): AXI-AW (Address Write) 및 AXI-W (Write Data) 채널을 통해 수신됩니다.  
  - 쓰기 데이터 조립(Write Data Assembly): AXI 주소 및 데이터 패킷은 비동기적으로 도착할 수 있으므로, 전용 조립 과정이 필요합니다.  
    - 시스템은 각 채널의 ID 및 User 신호를 매칭하여 AXI-AW와 AXI-W 채널을 동기화합니다.

**캐시 응답(Cache Response)**  
 - 읽기 응답(AXI-R 버스): 깊이 기반 우선순위 선택 및 Aging(노화) 스킴 적용.  
 - 쓰기 응답(AXI-B 버스): 추가 스케줄링 없이 투명한 패스스루(Pass-through).

**메모리 컨트롤러 요청(Memory Controller Request)**  
  - 읽기 요청(Read Request): 조립된 쓰기 요청이 없을 때 투명 패스스루로 처리됩니다.  
  - 쓰기 요청(Write Request): AXI-AW 및 AXI-W 채널이 성공적으로 조립(즉, ID/User 매칭)되면 선점적으로 처리됩니다.

**CMD/ADDR, DQ 버스 채널**  
 - 읽기 우선 스케줄링(Read-priority scheduling) 기반으로, 대기 중인 쓰기 요청이 임계치를 초과할 경우 쓰기 요청으로 전환됩니다.

**랭크 그랜트 스케줄링(Rank Grant Scheduling)**  
  - 깊이 기반 우선순위를 적용하며, LFSR 기반 타이브레이킹(tie-breaking)과 LSB 우선순위(LSB-priority) 폴백을 사용합니다.
```
> 깊이(depth) 기반 우선순위를 적용하며, 동일한 조건일 경우 LFSR 기반 타이브레이킹(tie-breaking)을 사용하고, 그마저 결정되지 않을 경우 LSB 우선순위 방식으로 최종 선택합니다.

용어 설명
깊이 기반 우선순위 (Depth-based priority)
→ 큐(queue)에 쌓인 요청의 개수(깊이)가 많은 대상을 우선 선택하는 방식

타이브레이킹 (Tie-breaking)
→ 우선순위가 동일할 때 누구를 먼저 선택할지 결정하는 추가 규칙

Tie의 기본 의미
→ 묶다, 동점이 되다
스포츠나 경쟁에서 점수가 같은 상태를 의미합니다.
의미: 묶다(bind), 연결하다(fasten)
“묶여 있다 → 서로 떨어지지 않는다 → 승부가 나지 않는다”
라는 의미 확장이 일어났습니다.
그래서 tie = 동점 / 무승부가 됩니다.

LFSR 기반 타이브레이킹
→ Linear Feedback Shift Register 기반의 의사난수(pseudo-random) 값을 사용하여 공정하게 선택

LSB 우선순위 폴백 (LSB-priority fallback)
→ 마지막 단계의 결정 규칙
→ 가장 낮은 비트(Least Significant Bit)가 1인 항목을 선택

즉 구조적으로 보면
1️⃣ Depth 비교
   ↓
2️⃣ 동일 depth → LFSR 랜덤 선택
   ↓
3️⃣ 그래도 결정 안되면 → LSB priority

이 구조는 메모리 컨트롤러 스케줄러에서
starvation 방지, 공정성(fairness),deterministic fallback
을 동시에 만족시키기 위해 자주 사용하는 방식입니다.
```

**뱅크 그랜트 스케줄링(Bank Grant Scheduling)**  
  - FR-FCFS 기반으로 Bank Group 수준의 병렬성을 활용하며, 타이밍 제약 조건(Short/Long)에 따라 페이지 히트를 우선 처리합니다.

**오픈 페이지 리스트(Open Page List)**  
  - 요청 공정성을 보장하기 위해 기아(Starvation) 임계치 초과 시 강제 페이지 프리차지(page precharge)가 트리거됩니다.

**자동 프리차지 CMD 윈도우(Auto-precharge CMD Window)**  
  - OpenPageList에서 기아 신호가 트리거되면, 랭크 스케줄러는 복구 기간 동안 뱅크 접근이 차단됩니다  
    (쓰기의 경우 $$tRP+tWR$$, 읽기의 경우 $$tRP$$) — 안전한 전환을 보장하기 위함입니다.

**읽기/쓰기 데이터 버스트 요청 윈도우(Read/Write Data Burst Request Window)**  
  - PHY가 관리하는 데이터 버스트 윈도우로서, 결정적 메타데이터(예: 읽기/쓰기 데이터의 주소) 동기화를 수행하며, 익명 DRAM 버스트를 특정 읽기/쓰기 버퍼 요청에 매핑합니다.

아래 내용은 chatgpt해석으로 오류가 있을 수 있습니다. ^^
이 문장은 DDR 메모리 컨트롤러에서 Read/Write 데이터가 실제 DRAM 버스트와 어떻게 매칭되는지 설명하는 부분입니다. 핵심은 **“DRAM 버스트는 익명(anonymous)으로 나오기 때문에, 이를 어떤 요청에 해당하는 데이터인지 식별해야 한다”**는 것입니다.

아래 순서로 이해하면 쉽습니다.


---

1️⃣ 문제: DRAM 데이터 버스트는 “익명”으로 나온다

DDR에서는 명령과 데이터가 시간적으로 분리됩니다.

예시

t0 : READ command issued
t1~tCL : DRAM 내부 동작
tCL 이후 : 데이터 burst 출력

하지만 실제 PHY 관점에서는

DQ bus → 데이터만 나옴

여기에는

이 데이터가 어떤 READ 요청의 것인지

정보가 없습니다.

즉

DRAM data burst = anonymous

입니다.


---

2️⃣ 해결 방법: Data Burst Request Window

그래서 PHY가 “데이터가 나올 시간 창(window)”을 관리합니다.

이것이 바로

Read/Write Data Burst Request Window

입니다.

개념

READ command issued
      ↓
PHY가 예상 데이터 도착 시간 계산
      ↓
"read data window" 생성
      ↓
해당 시간에 들어오는 데이터
→ 특정 request에 매핑


---

3️⃣ Read 경로 동작

예시

Cycle 0  : READ bank1 rowA
Cycle 1  : READ bank2 rowB
Cycle 12 : burst data #1
Cycle 13 : burst data #2

PHY 내부

Read Buffer Request Queue

Req0 → bank1,rowA
Req1 → bank2,rowB

그리고 PHY는 timing을 알고 있습니다.

예

tCL = 12 cycles

그래서

Cycle 12 → Req0 데이터
Cycle 13 → Req1 데이터

로 자동 매핑합니다.

이때 사용하는 것이

Read Data Burst Window

입니다.


---

4️⃣ Write 경로 동작

Write도 비슷합니다.

WRITE 명령 이후

tCWL 이후
DQ bus에 data burst 전송

PHY는

Write Buffer Request

를 가지고 있습니다.

Write Req0
Write Req1
Write Req2

그리고

Write Data Burst Window

동안

Write Buffer → DQ bus

를 수행합니다.

즉

버스트 데이터
→ 특정 write request

로 연결됩니다.


---

5️⃣ "결정적 메타데이터 동기화" 의미

문장에 나온

> 결정적 메타데이터(예: 주소)



의 의미는

어떤 요청인지 식별하는 정보

입니다.

예

Request metadata
- AXI ID
- Address
- Burst length
- Buffer pointer

이 정보는 컨트롤러 내부에 있고

DQ bus에는 존재하지 않습니다

그래서 PHY는

Command timing
+
Data window

를 이용해

metadata ↔ data burst

를 동기화합니다.


---

6️⃣ 그래서 문장의 의미

원문

> 익명 DRAM 버스트를 특정 읽기/쓰기 버퍼 요청에 매핑합니다.



의 의미는

DQ bus에 나타난 burst 데이터가
어떤 Read/Write 요청의 것인지
PHY가 timing window를 이용해 연결한다

입니다.


---

7️⃣ 한 문장 정리

Read/Write Data Burst Request Window

→ PHY가 DRAM burst가 발생하는 시간 구간을 관리하여,
DQ 버스의 익명 데이터 버스트를 특정 Read/Write 요청과 매칭시키는 메커니즘


---

원하시면 다음도 설명해 드리겠습니다 (DDR 컨트롤러 설계에서 매우 중요합니다)

1️⃣ 왜 DRAM 데이터는 주소 없이 나오는가
2️⃣ PHY Read FIFO / Write FIFO 구조
3️⃣ tCL / tCWL 기반 data return scheduling
4️⃣ 왜 DDR 컨트롤러에서 Data Window tracking logic이 반드시 필요한가
