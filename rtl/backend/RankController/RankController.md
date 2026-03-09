1. 모듈 개요

RankController는 Memory Controller Backend에서 특정 Rank 하나를 관리하는 제어 모듈입니다.

이 모듈은 다음을 담당합니다.

Frontend에서 들어온 메모리 요청 처리

Rank 내부 Bank FSM 스케줄링

DRAM timing constraint 관리

Memory Buffer 인터페이스

Channel Scheduler와 명령 발행 협력

실제 DDR 명령 신호 생성


즉 구조적으로 보면

Memory Controller Channel
        │
        ▼
   RankController
        │
        ├── RankSched
        │
        └── RankExecutionUnit


---

2. 파라미터

이 모듈은 DRAM 구조와 Timing 파라미터를 파라미터화한 범용 Rank Controller입니다.

Rank 식별

파라미터	설명

FSM_CHANNEL	Channel ID
FSM_RANK	Rank ID



---

Bank FSM 구조

파라미터	설명

NUM_BANKFSM	Rank 내 Bank FSM 개수
NUM_BANKFSM_BIT	Bank FSM 인덱스 비트 수



---

Request Queue

파라미터	설명

READCMDQUEUEDEPTH	Read command queue depth
WRITECMDQUEUEDEPTH	Write command queue depth
OPENPAGELISTDEPTH	Open row 관리 리스트 깊이



---

주소 구조

파라미터	설명

RWIDTH	Row address width
CWIDTH	Column address width
BKWIDTH	Bank address width
BGWIDTH	Bank Group width



---

DRAM Timing

파라미터	설명

tRP	Row Precharge time
tWR	Write recovery
tRFC	Refresh cycle time
tREFI	Refresh interval
tRCD	Activate → Read/Write delay



---

3. 입력 신호 (Frontend)

Frontend에서 들어오는 메모리 요청입니다.

신호	설명

RankReqMemAddr	메모리 주소
RankReqId	Request ID
RankReqUser	User 정보
RankReqType	요청 타입 (Read / Write)
RankReqValid	요청 유효



---

4. Frontend Ready 신호

신호	설명

RankReadReqReady	Read 요청 수락 가능
RankWriteReqReady	Write 요청 수락 가능


즉

Frontend → RankController

요청 핸드셰이크


---

5. Channel Scheduler 인터페이스

Channel-level scheduler와의 인터페이스입니다.

입력

신호	설명

chSchedCMDGranted	CMD bus grant
chSchedDQGranted	DQ bus grant
chSchedWriteMode	Write 모드 여부



---

출력

신호	설명

chSchedRdReady	Read 요청 존재
chSchedWrReady	Write 요청 존재
chSchedRdWrACK	RD/WR 명령 발행 ACK
chSchedCMDACK	CMD 발행 ACK
chSchedFSMWait	FSM timing wait 상태
chSchedCCDType	CAS-to-CAS timing type
ReadReqCnt	Read request 수
WriteReqCnt	Write request 수



---

6. Memory Buffer 인터페이스

입력

신호	설명

rdBufAvailable	Read buffer 사용 가능
wrBufAvailable	Write buffer 사용 가능
bufReadPreACK	Read data 완료
bufWritePreACK	Write data 완료
bufBankPre	Auto-precharge bank 정보



---

출력

신호	설명

bufReadReqId	Read buffer request ID
bufWriteReqId	Write buffer request ID
bufReadReqUser	Read request user
bufWriteReqUser	Write request user
bufReadReqACK	Read request valid
bufWriteReqACK	Write request valid
bufReqACKAddr	요청 주소



---

7. 내부 구조

RankController는 두 개의 핵심 모듈로 구성됩니다.

RankController
    │
    ├── RankSched
    │
    └── RankExecutionUnit


---

8. RankSched 모듈

역할

Request Queue 관리

Open Page 정책

Refresh 관리

Bank FSM 스케줄링

어떤 명령을 발행할지 결정


입력

Frontend request
Channel scheduler grant
Buffer availability
Bank FSM 상태

출력

FSM command issue
Buffer request
Scheduler 상태


---

RankSched 주요 출력

신호	설명

fsmIssue	FSM 명령 발행
fsmIssuedReq	발행된 요청
fsmWait	FSM timing wait
fsmIdle	FSM idle
issuable	명령 발행 가능



---

9. RankExecutionUnit 모듈

역할

실제 DRAM 명령 생성

Timing enforcement

Bank FSM 실행


즉

RankSched → 명령 결정
RankExecutionUnit → 명령 실행


---

입력

신호	설명

schedReq	Scheduler가 선택한 요청
schedValid	요청 유효
refresh	Refresh 요청
chCMDAvailable	CMD bus 사용 가능
chCMDDQAvailable	DQ bus 사용 가능



---

출력

신호	설명

fsmWait	FSM timing wait
chSchedCMDACK	CMD 발행 ACK
chSchedRdWrACK	RD/WR ACK



---

10. DDR Command 생성

RankExecutionUnit은 실제 DDR 명령을 생성합니다.

출력 신호

신호	설명

cke	Clock enable
cs_n	Chip select
par	Command parity
act_n	Activate
pin_A	Command address
bg	Bank group
b	Bank address



---

11. Bank FSM 상태

Rank 내부에는 여러 Bank FSM이 존재합니다.

RankController
      │
      ▼
 Bank FSM Array
 ├ Bank0
 ├ Bank1
 ├ Bank2
 └ Bank3

상태 신호

신호	설명

fsmIdle	Bank FSM idle
fsmWait	Timing wait



---

12. Rank Idle 판단

코드

assign chSchedRankIdle = &fsmIdle;

의미

모든 Bank FSM이 idle이면

Rank Idle


---

13. 전체 데이터 흐름

전체 흐름

Frontend Request
        │
        ▼
RankController
        │
        ▼
RankSched
(Request Scheduling)
        │
        ▼
RankExecutionUnit
(Command Execution)
        │
        ▼
DDR Command Bus


---

14. Channel Scheduler와 협력

구조

ChannelController
       │
       ▼
CMDGrantScheduler
       │
       ▼
RankController

Scheduler가

CMD bus grant
DQ bus grant

을 제공하면

RankController가

ACT
READ
WRITE
PRE
REF

명령을 실행합니다.


---

15. 핵심 설계 특징

이 설계의 특징입니다.


---

1️⃣ Rank 단위 분리 구조

Channel
 ├ Rank0 Controller
 ├ Rank1 Controller
 ├ Rank2 Controller
 └ Rank3 Controller


---

2️⃣ Scheduler / Execution 분리

RankSched
  ↓
Command Decision

RankExecutionUnit
  ↓
Command Execution


---

3️⃣ Bank FSM 병렬성

Multiple Bank FSM

→ DRAM 병렬성 활용


---

4️⃣ Timing enforcement

다음 timing 관리

tRP
tRCD
tWR
tRFC


---

16. 한 줄 요약

RankController는

특정 DRAM Rank의 요청 큐 관리, Bank FSM 스케줄링, DRAM 타이밍 제어, 그리고 실제 DDR 명령 생성을 담당하는 Memory Controller Backend의 Rank 단위 제어 모듈입니다.
