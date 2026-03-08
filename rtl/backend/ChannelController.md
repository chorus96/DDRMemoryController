# ChannelController SystemVerilog 코드 분석

## 1. 모듈 개요

`ChannelController`는 **Memory Controller Backend 내부에서 Channel 수준의 스케줄링을 담당하는 핵심 모듈**이다.  
이 모듈은 여러 개의 **RankController**를 관리하면서 다음 기능을 수행한다.

주요 역할

1. **Frontend 요청 분배**
   - FrontEnd에서 들어온 Memory Request를 해당 RankController로 전달

2. **Channel-level 스케줄링**
   - CMD Bus Arbitration
   - DQ Bus Timing Control

3. **DRAM Timing Constraint Enforcement**
   - tRTR
   - tCCD_S / tCCD_L
   - tRTW
   - tWTR_S / tWTR_L

4. **Buffer 인터페이스 관리**
   - ReadBuffer
   - WriteBuffer

5. **PHY Controller와의 명령/ACK 동기화**

---

# 2. 파라미터 분석

모듈은 다양한 DRAM 구조 및 타이밍 파라미터를 파라미터화하여 설계되었다.

## DRAM 구조 관련

| 파라미터 | 의미 |
|---|---|
| NUMRANK | 채널 내 Rank 수 |
| NUMBANK | Rank 당 Bank 수 |
| NUMBANKGROUP | Bank Group 수 |
| BGWIDTH | Bank Group Address width |
| BKWIDTH | Bank Address width |

## 주소 관련

| 파라미터 | 의미 |
|---|---|
| RWIDTH | Row address width |
| CWIDTH | Column address width |
| COMMAND_WIDTH | DDR Command Address Width |

## 큐 관련

| 파라미터 | 의미 |
|---|---|
| READCMDQUEUEDEPTH | Read Command Queue Depth |
| WRITECMDQUEUEDEPTH | Write Command Queue Depth |
| OPENPAGELISTDEPTH | Open Page List Depth |

## DRAM Timing 파라미터

| 파라미터 | 의미 |
|---|---|
| tRP | Row Precharge time |
| tWR | Write Recovery time |
| tRFC | Refresh cycle time |
| tRTRS | Rank-to-Rank switching time |
| tCCDL | Long CAS-to-CAS delay |
| tCCDS | Short CAS-to-CAS delay |
| tRTW | Read to Write delay |
| tWTRS | Write to Read Short delay |
| tWTRL | Write to Read Long delay |
| tREFI | Refresh interval |
| tRCD | Activate to Read/Write delay |

---

# 3. 주요 데이터 구조

## 3.1 rankReq 구조체

Frontend 요청을 RankController로 전달하기 위한 구조체이다.

```systemverilog
typedef struct packed {
    MemoryAddress addr;
    logic [MEM_IDWIDTH-1:0] id;
    logic [MEM_USERWIDTH-1:0] user;
    logic reqType;
    logic reqValid;
    logic reqReadReqReady;
    logic reqWriteReqReady;
} rankReq;

포함 정보

주소

Request ID

User 정보

Read/Write 타입

요청 유효 신호

RankController Ready 상태



---

3.2 chSched 구조체

Channel Scheduler와 RankController 사이의 상태 정보이다.

typedef struct packed {
    logic chSchedCMDGranted;
    logic chSchedRdReady;
    logic chSchedWrReady;
    logic chSchedACK;
    logic chSchedGrantACK;
    logic chSchedFSMWait;
    logic ccdType;
} chSched;

역할

CMD bus grant 상태

RankController 준비 상태

FSM 대기 상태

CAS-to-CAS timing 타입



---

3.3 memBuffer 구조체

Memory Buffer와의 인터페이스 신호를 저장한다.

typedef struct packed {
    logic bufReadPreACK;
    logic bufWritePreACK;
    logic [BKWIDTH+BGWIDTH-1:0] bufBankPre;

    logic [MEM_IDWIDTH-1:0] bufReadReqId;
    logic [MEM_IDWIDTH-1:0] bufWriteReqId;
    logic [MEM_USERWIDTH-1:0] bufReadReqUser;
    logic [MEM_USERWIDTH-1:0] bufWriteReqUser;

    logic bufReadReqACK;
    logic bufWriteReqACK;

    MemoryAddress bufReqACKAddr;
} memBuffer;

기능

Auto-precharge ACK 전달

Buffer allocation 요청 전달

Buffer allocation ACK 전달



---

4. Request 카운팅 로직

always_comb begin : RdWrRequestCounting

모든 RankController의 request queue를 합산한다.

NumRdReq = Sum(RDReqCnt[i])
NumWrReq = Sum(WRReqCnt[i])

목적

Channel-level scheduling 판단

Read / Write 모드 전환 판단



---

5. Auto Precharge ACK Routing

always_comb begin : AutoPreChargeACKFromPHYController

PHY Controller에서 전달된 Auto-Precharge 완료 신호를
해당 RankController로 전달한다.

동작 과정

1. PHY에서 Auto-precharge ACK 발생


2. Address의 rank 확인


3. 해당 RankController에 전달


4. bankgroup + bank 정보 전달




---

6. Memory Buffer Allocation ACK

always_comb begin : MEMBufferAllocationACK

RankController에서 발생한 요청을

다음 두 곳으로 전달한다.

1. Memory Buffer

ReadBuffer

WriteBuffer


2. PHY Controller

CMD issued ACK 전달


동작 흐름

RankController
      │
      ▼
ChannelController
      │
      ├── ReadBuffer
      ├── WriteBuffer
      └── PHYController


---

7. Frontend Request Demultiplexing

always_comb begin : RequestDemultiplexing

Frontend에서 들어온 요청을 해당 RankController로 분배한다.

동작

if(RankReqMemAddr.rank == i)
    request -> rankReqVector[i]

즉

Frontend Request
        │
        ▼
   ChannelController
        │
 ┌──────┴──────┐
Rank0 Rank1 Rank2 Rank3


---

8. Channel-Level Scheduling

ChannelController는 두 가지 Bus를 스케줄링한다.

8.1 CMD Bus Scheduling

제약

tRTR
rank-to-rank command turnaround

스케줄러

CMDGrantScheduler

정책

Queue Depth Priority
+ Random Tie Breaking


---

8.2 DQ Bus Scheduling

제약

1️⃣ CAS-to-CAS delay

tCCD_S
tCCD_L

2️⃣ Read/Write Turnaround

tRTW
tWTR_S
tWTR_L

모듈

DQRdWrCCDGrant
DQTurnaroundGrant

최종 DQ 사용 가능 조건

DQFree = chRdWrAvailable && DQTurnaroundFree


---

9. RankController 구조

현재 구현은

NUMRANK = 4

각 Rank마다 별도의 RankController 존재

RankController 0
RankController 1
RankController 2
RankController 3

각 RankController의 역할

Bank FSM 관리

Open Page 관리

Timing enforcement

Command generation



---

10. Issuable Signal

issuable = OR(issuableRank[])

의미

어떤 Rank라도 명령을 issue할 수 있는 상태인지 표시


용도

Channel mode transition 제어

Scheduler 판단



---

11. Channel Idle Signal

channelIdle = AND(rankIdle[])

의미

모든 RankController가 idle 상태일 때

channelIdle = 1


---

12. DDR4 Command Bus Mux

마지막 단계에서 ChannelController는

여러 RankController의 CMD를 하나의 DDR CMD bus로 multiplex한다.

always_comb begin : COMMANDADDRSetup

동작

if(chSchedVector[i].chSchedCMDGranted)
    DDR_CMD = Rank_i_CMD

출력 신호

cke
cs_n
par
act_n
pin_A
bg
b


---

13. 전체 아키텍처 구조

FrontEnd
                    │
                    ▼
            ChannelController
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   RankController RankController RankController
        │           │           │
        └───────────┼───────────┘
                    ▼
               CMD Scheduler
                    │
                    ▼
                DDR4 CMD BUS


---

14. ChannelController 핵심 역할 정리

기능	설명

Request Routing	FrontEnd 요청을 RankController로 분배
Command Arbitration	CMD bus arbitration
DQ Timing Control	CAS-to-CAS 및 RW turnaround 제어
Buffer Coordination	ReadBuffer / WriteBuffer와 연결
PHY Coordination	PHY Controller와 Command ACK 동기화
Rank Scheduling	여러 RankController의 명령 충돌 해결



---

15. 설계 특징

이 ChannelController는 다음 설계 철학을 따른다.

1️⃣ Hierarchical Memory Scheduling

ChannelController
     ↓
RankController
     ↓
BankFSM


---

2️⃣ Command/Data Path 분리

CMD Scheduling -> ChannelController
DATA Movement -> PHYController


---

3️⃣ Timing Isolation

각 Timing 제약을 독립 모듈로 분리

CMDTurnaroundGrant
DQTurnaroundGrant
DQRdWrCCDGrant


---

16. 결론

ChannelController는 Memory Controller Backend의 핵심 스케줄링 엔진이다.

주요 역할

1. FrontEnd 요청 분배


2. RankController 관리


3. Channel-level timing enforcement


4. CMD Bus arbitration


5. DQ Bus timing control


6. PHY Controller 인터페이스



이를 통해

High DRAM Parallelism
+
Timing Safe Operation
+
Scalable Architecture

를 달성하도록 설계되어 있다.


---
