# MemoryControllerFrontend SystemVerilog 코드 분석

## 1. 모듈 개요

`MemoryControllerFrontend`는 **캐시/NoC 인터페이스와 메모리 컨트롤러
백엔드 사이를 연결하는 프론트엔드 브리지 모듈**이다.

주요 역할:

-   캐시에서 오는 **AXI-like 요청 수신**
-   읽기/쓰기 요청 **중재(Arbitration)**
-   **Write burst 조립 (AW + W 채널 매칭)**
-   물리 주소 → 내부 DRAM 주소 변환
-   Memory Controller Backend로 요청 전달
-   Backend 응답을 Cache/NoC 인터페이스로 전달

아키텍처 구조:

    L2 Cache / NoC
          │
          ▼
    MemoryControllerFrontend
          │
          ▼
    MemoryController Backend
    (Channel / Rank FSM)

------------------------------------------------------------------------

# 2. 파라미터 설명

  파라미터           의미
  ------------------ -------------------------
  AXI_ADDRWIDTH      AXI 주소 폭
  AXI_DATAWIDTH      AXI 데이터 폭
  AXI_IDWIDTH        AXI Transaction ID
  AXI_USERWIDTH      AXI USER 필드
  BURST_LENGTH       Write burst 길이
  ASSEMBLER_DEPTH    Write assembler 큐 깊이
  NUMRANK            DRAM Rank 개수
  READBUFFERDEPTH    Read buffer depth
  WRITEBUFFERDEPTH   Write buffer depth

------------------------------------------------------------------------

# 3. 전체 동작 구조

Frontend는 크게 다음 **5개의 블록**으로 구성된다.

1️⃣ Address Translation Unit\
2️⃣ Write Request Assembler\
3️⃣ Write Address/Data Queue\
4️⃣ Memory Controller Request Generator\
5️⃣ Response Arbitration

------------------------------------------------------------------------

# 4. Address Translation Unit

AXI 주소를 내부 메모리 주소 구조로 변환한다.

    AXI Address
       │
       ▼
    Channel | Rank | BankGroup | Bank | Row | Column

출력:

-   `translatedAddr`
-   `FSM_vector`
-   `FSM_index`

즉,

어떤 **Rank FSM이 요청을 처리해야 하는지 결정**한다.

------------------------------------------------------------------------

# 5. Read / Write 요청 감지

    ReadRequestReceived =
        noc_req.ar_valid &&
        noc_resp.ar_ready &&
        FSM_vector[FSM_index];

Read 요청 조건

1.  AR valid
2.  Frontend ready
3.  해당 FSM 가능

Write 요청은 두 단계로 분리됨

-   Write Address (AW)
-   Write Data (W)

```{=html}
<!-- -->
```
    WriteAddrReceived
    WriteDataReceived

------------------------------------------------------------------------

# 6. Write Assembler 구조

AXI 프로토콜 특징:

Write Address와 Write Data가 **다른 채널**로 전달됨

따라서 Frontend에서 이를 **조립(Assembly)** 해야 한다.

구조

    WrAddrQueue   (주소 큐)
    WrDataQueue   (데이터 큐)

그리고

    assemblyVector

가 생성되면

**완전한 Write Burst 생성 완료**.

------------------------------------------------------------------------

# 7. Write Assembler Matching 로직

코드 핵심:

    for i in dataQueue
        for j in addrQueue
            if ID/User match
                assemble

즉

    WrDataQueue.ID == WrAddrQueue.ID
    WrDataQueue.USER == WrAddrQueue.USER

이면

    assemblyVector[i] = 1

Write 요청이 생성된다.

------------------------------------------------------------------------

# 8. Write Queue 관리

Write Address Push

    WrAddrQueue[WrAddrPushPtr] <= new address
    WrAddrFree[WrAddrPushPtr] = 0

Write Data Push

    WrDataQueue[WrDataPushPtr] <= data beat

Burst가 완료되면

    WrDataFree = 0
    WrPushPtrFree = 0

------------------------------------------------------------------------

# 9. Write Burst Counter

    WrPopCnt

역할:

Write burst beat tracking

예:

    burst length = 8

카운터

    0 → 1 → 2 → 3 → 4 → 5 → 6 → 7

마지막 beat

    WrPopCnt == BURSTTIMING

이면

    mc_req.last = 1

------------------------------------------------------------------------

# 10. Arbitration Policy

Frontend는 **Read-first 정책** 사용

    arbitrationMode = |assemblyVector

의미

-   Write burst 준비되면 → Write mode
-   아니면 → Read mode

즉

    Write has priority only when burst ready
    Otherwise Read first

------------------------------------------------------------------------

# 11. Memory Controller Request 생성

Write Request

    mc_req.write = 1
    mc_req.req_data_valid = 1
    mc_req.req_valid = first beat only

Read Request

    mc_req.req_valid = ar_valid

요청에 포함되는 정보

-   DRAM address
-   transaction ID
-   USER field
-   write data

------------------------------------------------------------------------

# 12. Response Arbitration

두 채널 존재

    Channel 0
    Channel 1

동시에 응답이 올 수 있음.

따라서 **Response Arbitration FSM** 존재.

상태

    SERVE_CH0
    SERVE_CH1

역할

    어느 채널의 응답을 Cache로 전달할지 결정

------------------------------------------------------------------------

# 13. Starvation 방지

변수

    ServingCnt

특정 채널이 계속 응답하면

    RESPSCHEDULINGCNT

횟수 이후

**강제로 채널 전환**

즉

    Fairness scheduling

------------------------------------------------------------------------

# 14. Ready 신호 생성

Frontend는 Backend 상태를 기반으로 ready 생성

    aggregate_ar_ready
    aggregate_aw_ready
    aggregate_w_ready

예

    noc_resp.ar_ready =
        any RankFSM ready &&
        not write arbitration

------------------------------------------------------------------------

# 15. Assertion

디버깅용 Assertion 포함

예

    AR request와 WR request 동시 발생 금지

    assert property (
        noc_req.ar_valid |-> !(noc_req.aw_valid || noc_req.w_valid)
    )

------------------------------------------------------------------------

# 16. 설계 특징 정리

이 설계의 특징:

### 1️⃣ AXI-like Interface 지원

-   Ready/Valid 기반

------------------------------------------------------------------------

### 2️⃣ Write Burst Assembler 포함

AW + W 채널 결합

------------------------------------------------------------------------

### 3️⃣ Read-first Arbitration

하지만

    Complete Write Burst 존재시 Write 우선

------------------------------------------------------------------------

### 4️⃣ DRAM Timing 미포함

이 모듈은

    Protocol Logic Only

Timing은

    Backend Rank FSM

에서 처리

------------------------------------------------------------------------

### 5️⃣ Response Arbitration 포함

멀티 채널 응답 처리

------------------------------------------------------------------------

# 17. 전체 데이터 흐름

    Cache Request
         │
         ▼
    MemoryControllerFrontend
         │
         ├── Address Translation
         ├── Write Burst Assembly
         ├── Request Arbitration
         │
         ▼
    MemoryController Backend
         │
         ▼
    Channel / Rank FSM
         │
         ▼
    DRAM

------------------------------------------------------------------------

# 18. 결론

`MemoryControllerFrontend`는 메모리 컨트롤러에서 **프로토콜 처리 계층**
역할을 수행한다.

주요 기능:

-   AXI-like 인터페이스 처리
-   Write burst 조립
-   Read/Write arbitration
-   Address translation
-   Response scheduling

즉,

    Cache ↔ DRAM Controller 사이의 Protocol Bridge

역할을 담당하는 핵심 모듈이다.
