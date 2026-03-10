# DDR4 Memory BFM

This directory contains a cycle-accurate DDR-SDRAM Bus Functional Model (BFM)
used to verify and validate the custom multi-channel DDR-SDRAM memory controller.

**(Timing parameters are based on DDR4-2400, but can be reconfigured to support other DDR4 speeds or future DDR generations.)**

The BFM models channel, rank, and bank-level DRAM behavior with
command-level timing enforcement and burst-level data transfers.

---

## 📐 System Overview
<p align="center">
<img width="640" height="400" alt="image" src="https://github.com/user-attachments/assets/3e0d4e60-2e5d-4277-a01c-cb80f499e431" />
</p>


The Memory Controller connects to multiple DDR4 channels (normally 2 or 3 for DDR4-SDRAM).
Each channel contains multiple independent ranks, and each rank
is composed of multiple bank-level FSMs.

**In this BFM implementation, each DIMM is modeled as one rank for structural simplicity.**

**Hierarchical structure:**

```text
MemoryBFM
 └── MemoryChannel (per channel)
      └── MemoryRank (per rank)
           └── MemoryBankFSM (per bank)
```
---

## 🧱 Module Structure

### 1️⃣ MemoryBFM
**Top-level structural wrapper.**

- Instantiates multiple memory channels
- No timing logic
- Pure structural composition

---

### 2️⃣ MemoryChannel
**Channel-level DDR4 model.**

Responsibilities:
- Broadcast CA/ADDR signals to all ranks
- Generate channel-level DQS during read bursts
- Perform rank-level DQ arbitration based on cs_n and tCL
- Model tri-state bidirectional DQ bus behavior

---

### 3️⃣ MemoryRank
**Rank-level behavioral model.**

Responsibilities:
- Decode BG/BK fields
- Select target bank
- Aggregate per-bank read/write activity
- Expose rank-level DQ valid signals

Assumption:
At most one bank drives DQ at a time.

---

### 4️⃣ MemoryBankFSM
**Bank-level DDR behavioral FSM.**

Responsibilities:
- Decode ACT / READ / WRITE / PRE / REF commands
- Enforce timing constraints
- Model row state transitions
- Generate burst-level data (clk2x domain)
- Support auto-precharge behavior

**State transitions:**

rowClosed → Activate → rowOpened  
rowOpened → Read / Write / Precharge  
Read/Write → (AutoPrecharge) → Precharge  

---

## ⏱ Timing Constraints Implemented

| Parameter | Modeled |
|-----------|---------|
| tRCD | ✅ |
| tCL  | ✅ |
| tCWL | ✅ |
| tRP  | ✅ |
| tRFC | ✅ |

---

## 🔄 Multi-Clock Behavior

- `clk` : Command decoding and state transitions
- `clk2x` : Operates at double frequency to model DDR burst data timing. This allows realistic DDR burst modeling.

---

## 🔌 Bidirectional Bus Modeling

DQ/DQS are modeled as:

Tri-state bidirectional buses.

- Read → Rank drives DQ
- Write → Controller drives DQ
- Idle → High-Z state

---

## 🧪 Verification Notes

- Integrated with custom DDR4 Memory Controller RTL
- Multi-channel simulation validated
- Tested with Verilator (Check the "script" folder)

---

This BFM is intended for architectural validation, DRAM Timing verification
memory controller verification, and multi-channel DDR experimentation.

---

DDR4 Memory BFM 해석

이 디렉터리는 **커스텀 멀티채널 DDR-SDRAM 메모리 컨트롤러를 검증하고 검증 정확도를 확보하기 위한, 사이클 정확도(cycle-accurate)를 갖는 DDR-SDRAM Bus Functional Model(BFM)**을 포함하고 있습니다.

기본 타이밍 파라미터는 DDR4-2400 기준

파라미터 재설정을 통해:

다른 DDR4 속도

또는 차세대 DDR 계열 을 지원할 수 있도록 설계됨



이 BFM은 Channel / Rank / Bank 수준의 DRAM 동작을 모델링하며,

명령(Command) 단위의 타이밍 제약

Burst 단위의 데이터 전송 을 모두 포함합니다.



---

📐 시스템 개요 (System Overview)

<p align="center">
<img width="640" height="400" alt="image" src="https://github.com/user-attachments/assets/3e0d4e60-2e5d-4277-a01c-cb80f499e431" />
</p>

메모리 컨트롤러는 여러 개의 DDR4 채널에 연결됩니다
(DDR4-SDRAM에서는 보통 2채널 또는 3채널).

각 Channel

여러 개의 Rank를 포함


각 Rank

여러 개의 Bank FSM으로 구성



📌 이 BFM 구현에서는 구조 단순화를 위해 DIMM 1개 = Rank 1개로 모델링


---

계층 구조 (Hierarchical Structure)

MemoryBFM
 └── MemoryChannel (채널 단위)
      └── MemoryRank (랭크 단위)
           └── MemoryBankFSM (뱅크 단위)

➡ 실제 DRAM 계층 구조를 그대로 반영한 모델


---

🧱 모듈별 역할 설명


---

1️⃣ MemoryBFM

최상위 구조 래퍼 (Top-level structural wrapper)

역할:

여러 개의 MemoryChannel 인스턴스 생성

타이밍 로직 없음

순수 구조적 연결만 담당


➡ “DRAM 시스템의 껍데기”


---

2️⃣ MemoryChannel

채널 단위 DDR4 모델

책임:

CA / ADDR 신호를 모든 Rank에 브로드캐스트

Read Burst 시 채널 단위 DQS 생성

cs_n 및 tCL을 기준으로 Rank 간 DQ 사용권 중재

양방향 DQ 버스의 tri-state 동작 모델링


➡ 실제 DDR 채널에서 발생하는 버스 공유·충돌·타이밍 문제를 재현


---

3️⃣ MemoryRank

랭크 단위 동작 모델

책임:

BG / BK 필드 디코딩

타겟 Bank 선택

Bank별 Read / Write 활동 집계

Rank 단위 DQ valid 신호 제공


가정:

한 시점에 하나의 Bank만 DQ를 구동


➡ 실제 DRAM Rank의 전기적 제약을 반영한 가정


---

4️⃣ MemoryBankFSM

뱅크 단위 DDR 동작 FSM

책임:

ACT / READ / WRITE / PRE / REF 명령 디코딩

DRAM 타이밍 제약 강제

Row 상태 전이 모델링

Burst 단위 데이터 생성 (clk2x 도메인)

Auto-Precharge 지원


상태 전이 흐름

rowClosed → Activate → rowOpened
rowOpened → Read / Write / Precharge
Read/Write → (AutoPrecharge) → Precharge

➡ 실제 DDR Bank 내부 동작을 충실히 재현


---

⏱ 구현된 타이밍 제약

파라미터	구현 여부

tRCD	✅
tCL	✅
tCWL	✅
tRP	✅
tRFC	✅


➡ 명령 간 간격뿐 아니라 데이터 타이밍까지 정확히 검증 가능


---

🔄 멀티 클록 구조 (Multi-Clock Behavior)

clk

Command 디코딩

상태 전이(FSM)


clk2x

DDR Burst 데이터 타이밍 모델링

클록 2배 속도로 동작



➡ DDR의 Double Data Rate 특성을 현실적으로 반영


---

🔌 양방향 버스 모델링 (Bidirectional Bus)

DQ / DQS는 tri-state 양방향 버스로 모델링됨

Read

Rank가 DQ 구동


Write

Memory Controller가 DQ 구동


Idle

High-Z 상태 (또는 Verilator 안전 모델링)



➡ 실제 PHY 수준의 버스 충돌 가능성까지 검증 가능


---

🧪 검증 관련 사항 (Verification Notes)

커스텀 DDR4 Memory Controller RTL과 통합

멀티채널 시뮬레이션 검증 완료

Verilator 테스트 완료



---

🎯 이 BFM의 목적 요약

이 BFM은 다음 용도로 설계됨:

메모리 컨트롤러 아키텍처 검증

DRAM 타이밍 제약 검증

멀티채널 DDR 시스템 실험

실제 DRAM에 매우 근접한 동작 재현



---

한 줄 요약

> 이 DDR4 Memory BFM은
“실제 DRAM처럼 까다롭게 행동하는 가짜 메모리”를 만들어
컨트롤러 설계를 철저히 검증하기 위한 모델이다.
