# MemoryControllerBackend SystemVerilog 코드 분석

## 1. 모듈 개요

`MemoryControllerBackend`는 **DDR4 메모리 컨트롤러의 채널 단위 Backend**를 구현한 모듈이다.  

이 모듈은 다음과 같은 주요 기능을 수행한다.

- DRAM 명령 스케줄링
- Read/Write 데이터 버퍼 관리
- DDR PHY 인터페이스 연결
- Read/Write 모드 스케줄링
- AXI 기반 Frontend와 DDR PHY 사이 데이터 경로 관리

즉 전체 구조에서
```
CPU / Cache
│ ▼ MemoryController Frontend
│ ▼ MemoryControllerBackend (이 모듈) │ ▼ DDR PHY
│ ▼ DDR4 DRAM
```
에서 **채널 내부의 모든 실행 로직을 담당하는 핵심 블록**이다.

---

# 2. 주요 Parameter 분석

## 메모리 구조 파라미터

| 파라미터 | 설명 |
|---|---|
| NUMRANK | Rank 개수 |
| NUMBANK | Bank 개수 |
| NUMBANKGROUP | Bank Group 개수 |
| BGWIDTH | Bank Group 주소 비트 |
| BKWIDTH | Bank 주소 비트 |
| RWIDTH | Row 주소 비트 |
| CWIDTH | Column 주소 비트 |

---

## 데이터 버스 파라미터

| 파라미터 | 설명 |
|---|---|
| MEM_DATAWIDTH | 메모리 데이터 폭 |
| MEM_ADDRWIDTH | 주소 폭 |
| MEM_IDWIDTH | 요청 ID 폭 |
| MEM_USERWIDTH | 사용자 메타데이터 폭 |

---

## Buffer 파라미터

| 파라미터 | 설명 |
|---|---|
| READBUFFERDEPTH | Read Buffer 깊이 |
| WRITEBUFFERDEPTH | Write Buffer 깊이 |
| READCMDQUEUEDEPTH | Read Command Queue 깊이 |
| WRITECMDQUEUEDEPTH | Write Command Queue 깊이 |

---

## DRAM Timing Parameter

| 파라미터 | 의미 |
|---|---|
| tRP | Row Precharge |
| tRCD | Row to Column Delay |
| tCL | CAS Latency |
| tCWL | Write Latency |
| tRFC | Refresh Cycle |
| tWTR | Write to Read |
| tRTW | Read to Write |
| tREFI | Refresh Interval |

이 값들은 **DRAM timing constraint enforcement**에 사용된다.

---

# 3. Frontend 입력 인터페이스

Frontend에서 Backend로 전달되는 요청은 다음과 같다.

## Command 정보

| 신호 | 설명 |
|---|---|
| RankReqMemAddr | DRAM 주소 |
| RankReqId | Transaction ID |
| RankReqUser | 사용자 정보 |
| RankReqType | Read / Write 구분 |
| RankReqValid | 요청 유효 |

---

## Write Data

| 신호 | 설명 |
|---|---|
| RankData | Write 데이터 |
| RankDataStrb | Byte mask |
| RankDataLast | Burst 마지막 |
| RankDataValid | 데이터 유효 |

---

# 4. Frontend 출력 인터페이스

## Read Response

| 신호 | 설명 |
|---|---|
| CacheReadData | Read 데이터 |
| CacheReadDataUser | 사용자 정보 |
| CacheReadDataId | Transaction ID |
| CacheReadDataLast | Burst 마지막 |
| CacheReadDataValid | 데이터 유효 |

---

## Write Response

| 신호 | 설명 |
|---|---|
| CacheWriteDataACKValid | Write 완료 |
| CacheWriteDataACKID | ID |
| CacheWriteDataACKUser | User |

---

# 5. 내부 구조

Backend는 크게 **4개의 주요 서브 모듈**로 구성된다.
```
MemoryControllerBackend
 ├─ ChannelController
 ├─ ReadBufferController
 ├─ WriteBufferController
 └─ PHYController
```
각 모듈은 서로 handshake 인터페이스로 연결된다.

---

# 6. Channel Read/Write Mode Controller

이 로직은 **채널이 현재 READ 모드인지 WRITE 모드인지 결정한다.**
```
ChannelRDWRMode
0 → READ
1 → WRITE
```
---

## 동작 정책

Threshold 기반 스케줄링을 사용한다.

### READ 우선 정책

조건
```
NumRdReq > 0

→ READ 유지
```
---

### WRITE 전환 조건
```
NumWrReq > CHMODETHRESHOLD

→ WRITE 모드 전환
```
---

### READ 전환 조건
```
NumWrReq < CHMODETHRESHOLD

→ READ 모드 복귀
```
---

## Mode 전환 조건

Mode 전환은 아래 조건이 모두 만족해야 한다.
```
channelIdle ModeTransitionValid ChannelRDWRTransReady
```
즉
```
- Bank FSM idle
- PHY 준비
- Scheduler 준비
```
---

# 7. ChannelController

역할

DRAM Command Scheduler

기능
```
- Rank / Bank FSM 관리
- DRAM timing enforcement
- Command arbitration
- ACT / PRE / RD / WR 발행
```
중요 특징

데이터 처리 안함 오직 CMD scheduling만 수행

---

# 8. ReadBufferController

역할

Read Response 저장

기능

- PHY에서 반환된 데이터 저장
- Outstanding transaction tracking
- AXI Read response 생성

데이터 흐름

DDR PHY ↓ ReadBuffer ↓ Frontend

---

# 9. WriteBufferController

역할

Write Data Buffer

기능

- Write burst 조립
- Write ordering 유지
- PHY에 데이터 공급
- Write completion ACK 생성

데이터 흐름

Frontend ↓ WriteBuffer ↓ PHY

---

# 10. PHYController

역할

Logical DRAM ↔ Physical DDR Interface

기능

- DQ 데이터 경로 처리
- Burst timing 정렬
- FIFO 관리
- Mode transition synchronization

---

## PHY Controller 처리 데이터

### WRITE

WriteBuffer → PHY → DDR DQ

---

### READ

DDR DQ → PHY → ReadBuffer

---

# 11. Backend 내부 데이터 흐름

## READ Path

Frontend ↓ ChannelController ↓ PHY Controller ↓ ReadBuffer ↓ Frontend

---

## WRITE Path

Frontend ↓ WriteBuffer ↓ ChannelController ↓ PHY Controller ↓ DDR

---

# 12. 인터페이스 구조

모듈 간 인터페이스

ChannelController ↔ ReadBuffer ChannelController ↔ WriteBuffer ChannelController ↔ PHYController ReadBuffer ↔ PHYController WriteBuffer ↔ PHYController

각 인터페이스는

- Command handshake
- Buffer allocation
- Data transfer

를 수행한다.

---

# 13. 주요 설계 특징

이 Backend 설계의 특징은 다음과 같다.

### 1. Channel 단위 설계

Channel 별 독립 Controller

확장성 좋음.

---

### 2. Command / Data 분리

Command path Data path

완전히 분리된 구조

---

### 3. Static Scheduling Policy

현재 정책

Threshold 기반 RD/WR switching

향후 확장 가능

Aging scheduling QoS scheduling Bank-level scheduling

---

### 4. PHY 추상화

PHY 관련 timing / electrical logic을

PHYController

에서만 처리한다.

---

# 14. 전체 구조 요약

MemoryControllerBackend는 다음을 담당한다.

1. DRAM Command Scheduling


2. Read / Write Buffer 관리


3. DDR PHY 인터페이스 연결


4. Channel RD/WR Mode Scheduling


5. Data Flow Control



즉

DDR Memory Controller의 실행 엔진

역할을 하는 모듈이다.

---

# 15. 한 문장 요약

MemoryControllerBackend는

DDR 메모리 채널에서 DRAM 명령 스케줄링과 데이터 버퍼 관리 및 PHY 인터페이스를 수행하는 채널 단위 메모리 컨트롤러 실행 엔진이다.




---

원하시면 제가 추가로 매우 중요한 것들도 설명해 드릴 수 있습니다.

이 코드의 실제 DDR Controller 아키텍처 (전문가 관점)

ChannelController 내부 FSM 구조

Bank FSM 구조 (DRAM Controller 핵심)

Address → Rank/Bank/Row/Column 매핑
