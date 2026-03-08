아래는 CMDGrantScheduler SystemVerilog 코드의 구조와 동작을 한국어로 체계적으로 해석한 분석입니다.


---

1. 모듈 개요

CMDGrantScheduler는 Memory Controller의 Channel 수준에서 CMD Bus 중재(Arbitration)를 수행하는 스케줄러 모듈입니다.

이 모듈의 목적은 다음과 같습니다.

여러 RankController 중에서

한 사이클에 단 하나의 RankController만 DDR 명령을 발행하도록 선택하는 것


즉 구조적으로 보면

RankController0
RankController1
RankController2
RankController3
        │
        ▼
CMDGrantScheduler
        │
        ▼
CMDGrantVector (One-hot)


---

2. 파라미터

파라미터	의미

NUMRANK	채널 내 RankController 수
READCMDQUEUEDEPTH	Read Command Queue 깊이
WRITECMDQUEUEDEPTH	Write Command Queue 깊이


예

NUMRANK = 4

이면

Rank0
Rank1
Rank2
Rank3

총 4개의 RankController를 관리합니다.


---

3. 입력 신호

(1) Ready Vector

신호	설명

readyRdVector	각 RankController의 READ CMD 발행 가능 상태
readyWrVector	각 RankController의 WRITE CMD 발행 가능 상태


예

readyRdVector = 4'b0101

→ Rank0, Rank2는 READ 가능


---

(2) FSM 상태

신호	설명

fsmWaitVector	RankController 내부 FSM이 Timing 때문에 대기 중인지


예

tRCD
tRP
tRFC

같은 DRAM 타이밍 때문에 CMD를 못 내리는 상태


---

(3) Request Queue Depth

신호	설명

readReqCnt	Rank별 Read request 수
writeReqCnt	Rank별 Write request 수


예

Rank0 = 5
Rank1 = 2
Rank2 = 7
Rank3 = 1


---

(4) Control Signals

신호	설명

grantACK	RankController가 CMD grant 사용 완료
writeMode	Channel이 Write Mode인지
CMDRankTurnaround	Rank Turnaround timing (tRTR) 충족 여부



---

4. 출력 신호

신호	설명

CMDGrantVector	선택된 RankController (one-hot)
rankTransition	Rank 변경 발생 여부


예

CMDGrantVector = 4'b0100

→ Rank2에게 CMD 발행 권한 부여


---

5. 내부 변수

LFSR

logic [NUMRANK-1:0] lfsr

Pseudo Random Generator

용도

Queue depth가 같을 때 tie-breaking


---

masked

masked = avail & lfsr

Random selection 후보


---

avail

avail = ready & ~fsmWait

즉

CMD 발행 가능한 RankController


---

6. Pseudo Random Generator (LFSR)

always_ff @(posedge clk)

LFSR 동작

lfsr <= {lfsr[NUMRANK-2:0],
         lfsr[NUMRANK-1] ^ lfsr[NUMRANK-2]};

예

0001
0010
0100
1001
...

특징

pseudo-random sequence 생성

tie-breaking용



---

7. Arbitration Logic

핵심 스케줄링 로직

always_comb

Step 1 : Available Rank 계산

if(writeMode)
    avail = readyWrVector & ~fsmWaitVector
else
    avail = readyRdVector & ~fsmWaitVector

즉

Ready AND Not Waiting


---

Step 2 : Queue Depth 기반 우선순위

Write mode일 때

WRmaxCnt = 최대 요청
WRminCnt = 최소 요청

가장 큰 요청을 가진 Rank 선택

예

Rank0 = 2
Rank1 = 7
Rank2 = 1
Rank3 = 4

→ Rank1 선택


---

Step 3 : Tie 상황

만약

WRmaxCnt == WRminCnt

즉

모든 Rank의 요청 깊이가 동일

이면

tie_break = 1


---

8. Random Tie Breaking

tie_break가 필요하면

masked = avail & lfsr

사용

Case 1

masked == 0

→ fallback

LSB priority arbiter

next_cmd = avail & (~avail + 1)


---

Case 2

masked != 0

→ masked에서 LSB 선택

next_cmd = masked & (~masked + 1)


---

9. LSB Priority Arbiter

공식

x & (-x)

SystemVerilog

x & (~x + 1)

예

x = 10110000

~x + 1 = 01010000

결과

00010000

→ 가장 낮은 bit 선택


---

10. Grant Register Update

always_ff @(posedge clk)

Grant update 조건

1. 첫 grant

CMDGrantVector == 0

→ next_cmd grant


---

2. 이전 grant 완료

grantACK == 1

→ 새로운 rank 선택


---

3. 후보 없음

avail == 0

→ grant 제거


---

4. 기존 rank 유지

조건

CMDGrantVector & next_cmd

→ 동일 rank 유지


---

11. Rank Transition Detection

prev_cmd <= CMDGrantVector

이전 grant 저장


---

Transition detection

rankTransition = (prev_cmd != CMDGrantVector)

즉

Rank0 → Rank2

처럼 변경되면

rankTransition = 1


---

12. 전체 스케줄링 흐름

전체 구조

RankController
      │
      ▼
Ready / ReqCnt
      │
      ▼
CMDGrantScheduler
      │
      ▼
next_cmd
      │
      ▼
CMDGrantVector
      │
      ▼
DDR CMD Bus


---

13. 스케줄링 정책 요약

이 스케줄러의 정책

1️⃣ Availability Filtering

Ready
AND
FSMWait 없음


---

2️⃣ Queue Depth Priority

가장 깊은 Queue


---

3️⃣ Random Tie Breaking

LFSR 기반


---

4️⃣ LSB Priority Fallback

Random 실패 시


---

14. 설계 특징

이 스케줄러의 특징

Channel-Level Scheduler

Channel
 ├ Rank0
 ├ Rank1
 ├ Rank2
 └ Rank3


---

Timing Decoupling

이 모듈은

tRCD
tRP
tRTR

같은 타이밍을 직접 처리하지 않음

외부 모듈

CMDTurnaroundGrant

에서 처리


---

Fairness + Throughput

정책

Queue Depth Priority
+
Random Tie Break

목표

Throughput 증가
Starvation 방지


---

15. 한 줄 요약

CMDGrantScheduler는

여러 RankController 중에서 요청 큐 깊이를 기준으로 DDR CMD를 발행할 Rank를 선택하고, 동점일 경우 LFSR 기반 랜덤 방식으로 공정하게 중재하는 Channel-level CMD Bus Arbitration 모듈입니다.
