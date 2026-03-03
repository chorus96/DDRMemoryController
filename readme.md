![RTL-LINT](https://github.com/sjo99-kr/DDR_based_Memory_Controller/actions/workflows/ci.yml/badge.svg)
# DDR Multi-Channel Memory Controller (SystemVerilog)
A timing-aware, **multi-channel DDR Memory Controller** designed and verified in SystemVerilog.

This project implements a hierarchical DDR controller architecture with per-channel, per-rank, and per-bank scheduling, along with a custom DDR4 Bus Functional Model (BFM) and a verification infrastructure including driver, monitor, and scoreboard.

---


## 🏗 Architecture Overview
<img width="1213" height="672" alt="image" src="https://github.com/user-attachments/assets/f93a4d25-b2bc-4200-8718-d41b12eb4995" />


### Key Architectural Features

- Dual-channel DDR backend
- Per-rank FR-FCFS request scheduler and execution unit
- Bank-level FSM with timing enforcement
- AXI-based frontend interface
- Separate CMD/ADDR and DQ bus arbitration
- Open-page policy with timing-aware command scheduling
- Timing-aware rank and bank tracking

---

## 🧠 Design Philosophy

The controller is structured hierarchically:

- **Frontend**
  - Cache Request Arbiter
  - Cache Response Arbiter
  - Cache Response Scheduler
  - Address Translation Unit
  - MC Request Arbiter

- **Backend**
  - Channel Controller
  - Rank Scheduler
  - Rank Execution Unit
  - Bank FSMs
  - DDR CMD/ADDR Bus Arbiter
  - DDR DQ Bus Arbiter
  - PHY Read/Write mode separation
  - Read/Write Buffer Controller

The design enforces DRAM timing constraints at coommand-level and models channel/rank/bank-level parallelism explicitly.

---

### Verification Overview (UVM-like + RTL + BFM)
<img width="1191" height="667" alt="image" src="https://github.com/user-attachments/assets/9b5a96e1-11db-4499-86ee-abc5416957fb" />

The verification environment follows a UVM-like layered architecture:

- AXI-based Driver (random traffic via LFSR)
- Monitor (AXI + DDR command-level event tracking)
- Scoreboard with timing validation
- Custom DDR4 Bus Functional Model (BFM)

The scoreboard validates:

- Read Request/Response ID & User matching
- Write Request/ACK ID & User matching
- Deadlock detection
- DRAM timing constraint enforcement:
  - tCL
  - tCWL
  - tCCD (bank-group aware)
  - tRCD (per-rank, per-bank tracking)
- Data burst timing validation
- Command-to-data consistency

---  

## 🛠 Tool Flow

This project supports automated linting, synthesis, and simulation.

| Stage       | Tool                    | Description                                   |
|------------|--------------------------|-----------------------------------------------|
| Lint       | Verilator 5.045          | SystemVerilog lint & static analysis          |
| Synthesis  | Yosys 0.62+0             | RTL synthesis (Nangate45 technology mapping)  |
| Simulation | Vivado 2024.2 (XSIM)     | Functional simulation & waveform analysis     |

### Run Examples

```bash
# Lint (RTL & BFM)
./scripts/lint_rtl.sh
./scripts/lint_bfm.sh

# Synthesis
./scripts/syn_nangate45.sh

# Simulation (UVM-like testbench, XSIM)
./scripts/xsim_uvm.sh
```

## 📚 References

1. L. Gopalakrishnan, V. Thyagarajan, P. Kole, and G. R. Gangula,  
   *“Memory Controller with Reconfigurable Hardware,”* 2015.  
   – Architectural inspiration for hierarchical controller design.

2. ananthbhat94,  
   *“DDR4MemoryController”* (GitHub repository).  
   – Reference for DDR interface signal definitions.

3. H. Luo et al.,  
   *“Ramulator 2.0: A Modern, Modular, and Extensible DRAM Simulator,”*  
   IEEE Computer Architecture Letters, 2023.  
   – Reference for cycle-level DDR timing parameters.
   

# DDR 멀티채널 메모리 컨트롤러 (SystemVerilog)

![RTL-LINT](https://github.com/sjo99-kr/DDR_based_Memory_Controller/actions/workflows/ci.yml/badge.svg)

타이밍 인식 **멀티채널 DDR 메모리 컨트롤러**로, SystemVerilog로 설계 및 검증되었습니다.

본 프로젝트는 채널별, 랭크별, 뱅크별 스케줄링을 포함한 계층적 DDR 컨트롤러 아키텍처, 커스텀 DDR4 버스 기능 모델(BFM) 및 검증 인프라를 구현합니다.

---

## 🏗 아키텍처 개요
<img width="1213" height="672" alt="image" src="https://github.com/user-attachments/assets/f93a4d25-b2bc-4200-8718-d41b12eb4995" />

### 주요 아키텍처 특징

- 듀얼채널 DDR 백엔드
- 랭크별 FR-FCFS 요청 스케줄러 및 실행 유닛
- 뱅크 레벨 FSM과 타이밍 강제
- AXI 기반 프론트엔드 인터페이스
- CMD/ADDR 및 DQ 버스 별도 중재
- 타이밍 인식 커맨드 스케줄링을 통한 오픈 페이지 정책
- 타이밍 인식 랭크 및 뱅크 추적

---

## 🧠 설계 철학

컨트롤러는 계층적으로 구조화되어 있습니다:

- **프론트엔드**
  - 캐시 요청 중재자
  - 캐시 응답 중재자
  - 캐시 응답 스케줄러
  - 주소 변환 유닛
  - MC 요청 중재자

- **백엔드**
  - 채널 컨트롤러
  - 랭크 스케줄러
  - 랭크 실행 유닛
  - 뱅크 FSM
  - DDR CMD/ADDR 버스 중재자
  - DDR DQ 버스 중재자
  - PHY 읽기/쓰기 모드 분리
  - 읽기/쓰기 버퍼 컨트롤러

설계는 커맨드 레벨에서 DRAM 타이밍 제약을 강제하고 채널/랭크/뱅크 레벨 병렬성을 명시적으로 모델링합니다.

---

### 검증 개요 (UVM 유사 + RTL + BFM)
<img width="1191" height="667" alt="image" src="https://github.com/user-attachments/assets/9b5a96e1-11db-4499-86ee-abc5416957fb" />

검증 환경은 UVM 유사 계층화 아키텍처를 따릅니다:

- AXI 기반 드라이버 (LFSR을 통한 랜덤 트래픽)
- 모니터 (AXI + DDR 커맨드 레벨 이벤트 추적)
- 타이밍 검증이 포함된 스코어보드
- 커스텀 DDR4 버스 기능 모델 (BFM)

스코어보드는 다음을 검증합니다:

- 읽기 요청/응답 ID 및 사용자 일치
- 쓰기 요청/ACK ID 및 사용자 일치
- 데드락 감지
- DRAM 타이밍 제약 강제:
  - tCL
  - tCWL
  - tCCD (뱅크 그룹 인식)
  - tRCD (랭크별, 뱅크별 추적)
- 데이터 버스트 타이밍 검증
- 커맨드-데이터 일관성

---  

## 🛠 도구 흐름

본 프로젝트는 자동화된 린팅, 합성 및 시뮬레이션을 지원합니다.

| 단계       | 도구                    | 설명                                   |
|------------|--------------------------|-----------------------------------------------|
| 린트       | Verilator 5.045          | SystemVerilog 린트 및 정적 분석          |
| 합성  | Yosys 0.62+0             | RTL 합성 (Nangate45 기술 매핑)  |
| 시뮬레이션 | Vivado 2024.2 (XSIM)     | 기능 시뮬레이션 및 파형 분석     |

### 실행 예제

```bash
# 린트 (RTL & BFM)
./scripts/lint_rtl.sh
./scripts/lint_bfm.sh

# 합성
./scripts/syn_nangate45.sh

# 시뮬레이션 (UVM 유사 테스트벤치, XSIM)
./scripts/xsim_uvm.sh
```

## 📚 참고 자료

1. L. Gopalakrishnan, V. Thyagarajan, P. Kole, and G. R. Gangula,  
   *"Memory Controller with Reconfigurable Hardware,"* 2015.  
   – 계층적 컨트롤러 설계의 아키텍처 영감.

2. ananthbhat94,  
   *"DDR4MemoryController"* (GitHub 저장소).  
   – DDR 인터페이스 신호 정의 참고.

3. H. Luo et al.,  
   *"Ramulator 2.0: A Modern, Modular, and Extensible DRAM Simulator,"*  
   IEEE Computer Architecture Letters, 2023.  
   – 사이클 레벨 DDR 타이밍 파라미터 참고.
