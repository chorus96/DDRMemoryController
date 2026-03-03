# Verification Architecture

This directory contains a UVM-like verification environment
for the DDR4 Memory Controller.

The testbench validates functional correctness, protocol compliance,
and DRAM timing behavior.

---

## Verification Overview

<img width="1169" height="666" alt="image" src="https://github.com/user-attachments/assets/8defb08a-27c1-41ee-afb2-d4366f0fbc88" />

---

## Architecture Components

### 1️⃣ AXI Driver (Stimulus Generator)

- Generates AXI-compliant traffic:
  - AXI-AR (Read Address)
  - AXI-AW (Write Address)
  - AXI-W  (Write Data)
- Supports out-of-order and burst-based transactions
- Configurable traffic generation patterns

---

### 2️⃣ Monitor

The monitor observes both:

- Cache ↔ Memory Controller events
- DDR CMD/ADDR and DQ bus activity

It extracts:

- Read/Write request issue events
- Read/Write response events
- DRAM command issuance timing
- Data burst timing

All extracted events are forwarded to the Scoreboard.

---

### 3️⃣ Scoreboard

The scoreboard performs:

- AXI ID/User matching (Req ↔ Resp)
- DRAM timing validation:
  - tCL
  - tCWL
  - tCCD
  - tRCD
- Deadlock detection
- Data burst timing validation

Verification results are summarized at simulation end.

---

### 4️⃣ DDR BFM

The BFM models:

- Multi-channel DDR interface
- Rank/Bank behavior
- Timing-accurate command handling
- Burst-based data transfer

The BFM interacts with the DUT via:
- CMD/ADDR bus
- DQ bus
- DQS signaling

---

## Verification Strategy

The testbench follows a layered architecture:

Driver → DUT → Monitor → Scoreboard

The DUT is validated against:

- AXI protocol correctness
- DRAM timing constraints
- Scheduling fairness
- Data validation 
- Starvation handling

---

## Simulation Flow

Run using:

```bash
./scripts/xsim_uvm.sh
```
---
# 검증 아키텍처 (Verification Architecture)

이 디렉터리는 DDR4 메모리 컨트롤러를 위한  
**UVM-like 검증 환경**을 포함합니다.

본 테스트벤치는 기능적 정확성, 프로토콜 준수 여부,
그리고 DRAM 타이밍 동작을 검증합니다.

---

## 검증 개요 (Verification Overview)

<img width="1169" height="666" alt="image" src="https://github.com/user-attachments/assets/8defb08a-27c1-41ee-afb2-d4366f0fbc88" />

---

## 아키텍처 구성 요소 (Architecture Components)

### 1️⃣ AXI Driver (자극 생성기)

- AXI 규격을 준수하는 트래픽 생성:
  - AXI-AR (Read Address)
  - AXI-AW (Write Address)
  - AXI-W  (Write Data)
- Out-of-order 및 burst 기반 트랜잭션 지원
- 트래픽 생성 패턴을 설정 가능

---

### 2️⃣ Monitor

Monitor는 다음 두 가지를 모두 관찰합니다:

- Cache ↔ Memory Controller 간 이벤트
- DDR CMD/ADDR 및 DQ 버스 활동

Monitor가 추출하는 정보는 다음과 같습니다:

- Read / Write 요청 발생 이벤트
- Read / Write 응답 이벤트
- DRAM 명령 발행 타이밍
- 데이터 버스트 타이밍

추출된 모든 이벤트는 Scoreboard로 전달됩니다.

---

### 3️⃣ Scoreboard

Scoreboard는 다음 기능을 수행합니다:

- AXI ID/User 매칭 (요청 ↔ 응답)
- DRAM 타이밍 검증:
  - tCL
  - tCWL
  - tCCD
  - tRCD
- 데드락(Deadlock) 검출
- 데이터 버스트 타이밍 검증

시뮬레이션 종료 시 검증 결과를 요약하여 출력합니다.

---

### 4️⃣ DDR BFM

BFM은 다음을 모델링합니다:

- 멀티 채널 DDR 인터페이스
- Rank / Bank 동작
- 타이밍 정확한 명령 처리
- 버스트 기반 데이터 전송

BFM은 다음 인터페이스를 통해 DUT와 상호작용합니다:
- CMD/ADDR 버스
- DQ 버스
- DQS 신호

---

## 검증 전략 (Verification Strategy)

테스트벤치는 계층적 구조를 따릅니다:

Driver → DUT → Monitor → Scoreboard

DUT는 다음 항목에 대해 검증됩니다:

- AXI 프로토콜 정확성
- DRAM 타이밍 제약 조건
- 스케줄링 공정성
- 데이터 정확성
- 기아(starvation) 처리 여부

---

## 시뮬레이션 흐름 (Simulation Flow)

다음 스크립트를 사용하여 실행합니다:

```bash
./scripts/xsim_uvm.sh
```
