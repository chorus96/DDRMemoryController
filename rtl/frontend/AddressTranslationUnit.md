
# AddressTranslationUnit SystemVerilog 코드 분석

## 1. 모듈 개요

`AddressTranslationUnit` 모듈은 AXI 인터페이스에서 전달되는 물리 주소를 DRAM 내부 주소 구조로 변환하고,  
해당 요청을 처리할 FSM(Finite State Machine)을 선택하는 역할을 한다.

이 모듈의 주요 기능은 다음과 같다.

1. AXI 물리 주소를 DRAM 주소 필드로 분해
2. Channel / Rank 정보를 기반으로 FSM 선택
3. 선택된 FSM을 One-hot 벡터로 출력
4. 변환된 DRAM 주소 구조 생성

즉, 이 모듈은 **AXI 주소 → DRAM 실행 유닛 매핑(Address Mapping)** 역할을 수행한다.

---

# 2. 파라미터 설명

| 파라미터 | 설명 |
|---|---|
| MEM_ADDRWIDTH | 내부 메모리 주소 폭 |
| AXI_ADDRWIDTH | AXI 인터페이스 주소 폭 |
| NUM_RANKEXECUTION_UNIT | 전체 FSM 개수 |
| NUM_RANKEXECUTION_UNIT_BIT | FSM 인덱스 비트 수 |
| CHWIDTH | Channel 필드 비트 수 |
| RKWIDTH | Rank 필드 비트 수 |
| MemoryAddress | DRAM 주소 구조체 타입 |

---

# 3. 입력 신호

| 신호 | 설명 |
|---|---|
| readAddr | AXI Read 주소 |
| writeAddr | AXI Write 주소 |
| readReady | 각 FSM의 Read 준비 상태 |
| readValid | Read 요청 유효 신호 |
| writeReady | 각 FSM의 Write 준비 상태 |
| writeValid | Write 요청 유효 신호 |

---

# 4. 출력 신호

| 신호 | 설명 |
|---|---|
| targetFSMVector | 선택된 FSM을 나타내는 One-hot 벡터 |
| targetFSMIndex | 선택된 FSM의 인덱스 |
| requestMemAddr | 변환된 DRAM 주소 구조 |

---

# 5. FSM 구조

FSM 개수는 Channel과 Rank 조합으로 결정된다.

```
FSM_WIDTH = CHWIDTH + RKWIDTH
```

예시:

```
CHWIDTH = 1
RKWIDTH = 2
FSM_WIDTH = 3
```

따라서 FSM 개수는

```
2^3 = 8
```

즉

```
FSM = Channel × Rank
```

---

# 6. DRAM 주소 구조

AXI 주소는 다음 DRAM 주소 필드로 분해된다.

```
Channel | Rank | BankGroup | Bank | Row | Column
```

코드에서는 다음과 같이 분해한다.

```
{requestMemAddr.channel,
 requestMemAddr.rank,
 requestMemAddr.bankgroup,
 requestMemAddr.bank,
 requestMemAddr.row,
 requestMemAddr.col}
```

이 방식은 **Fixed Address Mapping** 방식이다.

---

# 7. FSM 선택 로직

FSM 선택 과정은 다음과 같다.

### 1단계: 주소 디코딩

AXI 주소를 DRAM 주소 필드로 분해

```
readAddr → requestMemAddr
writeAddr → requestMemAddr
```

---

### 2단계: FSM 인덱스 생성

FSM 인덱스는 주소의 상위 비트를 사용한다.

```
targetFSMIndex = address[MEM_ADDRWIDTH-1 -: FSM_WIDTH]
```

즉

```
targetFSMIndex = {channel, rank}
```

---

### 3단계: FSM Ready 확인

Read 요청

```
readReady[{channel, rank}]
```

Write 요청

```
writeReady[{channel, rank}]
```

---

### 4단계: FSM 선택

FSM이 준비 상태라면

```
targetFSMVector[targetFSMIndex] = 1
```

이 벡터는 One-hot 형식이다.

예:

```
00010000
```

이는

```
FSM index = 4
```

를 의미한다.

---

# 8. Read 요청 처리 흐름

```
readValid = 1
    ↓
readAddr 디코딩
    ↓
channel, rank 추출
    ↓
FSM ready 확인
    ↓
targetFSMIndex 생성
    ↓
targetFSMVector 출력
```

---

# 9. Write 요청 처리 흐름

```
writeValid = 1
    ↓
writeAddr 디코딩
    ↓
channel, rank 추출
    ↓
FSM ready 확인
    ↓
targetFSMIndex 생성
    ↓
targetFSMVector 출력
```

---

# 10. Always_comb 블록 동작

모든 출력은 combinational logic으로 계산된다.

초기화

```
targetFSMVector = 0
targetFSMIndex  = 0
requestMemAddr  = 0
```

그 후

- Read 요청이 있으면 Read 경로 처리
- Write 요청이 있으면 Write 경로 처리

---

# 11. 설계 특징

## 1. Address Decoder 기능

AXI 주소를 DRAM 주소 구조로 분해한다.

---

## 2. FSM Selection 기능

Channel과 Rank 기반으로

```
어떤 Rank FSM이 요청을 처리할지 결정
```

---

## 3. One-hot FSM Selection

FSM 선택 결과를 One-hot 벡터로 출력한다.

---

## 4. Fixed Address Mapping

현재는 단순한 주소 매핑을 사용한다.

확장 가능:

- XOR Address Hashing
- Bank Interleaving
- Channel Load Balancing

---

# 12. 전체 동작 흐름

```
AXI Request
      │
      ▼
AddressTranslationUnit
      │
      ├── Address Decode
      │
      ├── Channel / Rank 추출
      │
      ├── FSM Index 계산
      │
      └── FSM 선택 (One-hot Vector)
      │
      ▼
Memory Controller Frontend
```

---

# 13. 결론

`AddressTranslationUnit` 모듈은 메모리 컨트롤러에서

AXI 주소를 DRAM 실행 유닛으로 매핑하는 핵심 모듈이다.

핵심 기능

- AXI 주소 → DRAM 주소 변환
- Channel / Rank 기반 FSM 선택
- 요청 처리 대상 FSM 결정

즉, 이 모듈은

```
AXI Address → DRAM Execution Unit Mapping
```

을 수행하는 **Address Decoder / Address Mapper 모듈**이다.
