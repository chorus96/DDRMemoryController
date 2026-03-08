이 코드는 DDR 기반 Memory Controller 전체에서 사용하는 공통 정의 패키지입니다.
즉 모든 RTL 모듈(Frontend, Backend, Rank FSM, Buffer, PHY 등)이 공유하는 파라미터, 타입, 구조체, 타이밍 정의를 모아놓은 SystemVerilog package입니다.

패키지 이름:
```
package MemoryController_Definitions;
```
이 패키지를 각 모듈에서
```
import MemoryController_Definitions::*;
```
로 불러 사용합니다.

아래에서 설계 관점으로 구조를 단계별로 분석하겠습니다.


---

1️⃣ Verilator lint 제어
```
/* verilator lint_off TIMESCALEMOD */
`timescale  1ns / 1ps
```
의미

TIMESCALEMOD 경고를 끔

package에 timescale이 있어도 Verilator가 경고하지 않도록 함


마지막에 다시 켭니다.
```
/* verilator lint_on TIMESCALEMOD */
```

---

2️⃣ Memory Controller 기본 파라미터
```
parameter int MEM_ADDRWIDTH = 32;
parameter int MEM_DATAWIDTH = 64;
parameter int MEM_IDWIDTH   = 4;
parameter int MEM_USERWIDTH = 1;
parameter int COMMAND_WIDTH = 18;
parameter int BURST_LENGTH  = 8;
```
설계 의미

|파라미터	|의미|
|---|---|
|MEM_ADDRWIDTH	|AXI/MC 주소 width|
|MEM_DATAWIDTH	|데이터 bus width|
|MEM_IDWIDTH	|AXI ID width|
|MEM_USERWIDTH	|AXI user field|
|COMMAND_WIDTH	|DDR command encoding|
|BURST_LENGTH	|DDR burst length|


예

DDR4 BL8

이 컨트롤러도 BL8 burst 구조입니다.


---

3️⃣ DRAM 주소 구조 정의

CH-RK-BG-BK-ROW-COL

각 필드

parameter int RWIDTH  = 15;
parameter int CWIDTH  = 10;
parameter int BGWIDTH = 2;
parameter int BKWIDTH = 2;
parameter int RKWIDTH = 2;
parameter int CHWIDTH = 1;

주소 구조

| Channel | Rank | BankGroup | Bank | Row | Column |

비트 수

필드	비트

Channel	1
Rank	2
BankGroup	2
Bank	2
Row	15
Column	10


합계

1 + 2 + 2 + 2 + 15 + 10 = 32bit

→ AXI 주소와 정확히 매핑


---

4️⃣ DRAM 하드웨어 구조

parameter int DEVICEPERRANK = 8;

의미

x8 DRAM chip 8개

즉

64bit data bus

구조

8 chips × 8bit = 64bit


---

5️⃣ Buffer 및 Queue 구조

READCMDQUEUEDEPTH  = 8
WRITECMDQUEUEDEPTH = 8
READBUFFERDEPTH    = 128
WRITEBUFFERDEPTH   = 128

의미

구조	깊이

Read command queue	8
Write command queue	8
Read data buffer	128
Write data buffer	128


Read/Write buffer entry

64 Byte per entry

즉

128 × 64B = 8KB

버퍼 크기.


---

6️⃣ Open Page List

OPENPAGELISTDEPTH = 1 << (BKWIDTH+BGWIDTH);

계산

BKWIDTH = 2
BGWIDTH = 2

2^(2+2) = 16

즉

16 banks

→ 각 bank의 open row tracking.


---

7️⃣ Memory 구조 규모

NUMCHANNEL   = 2
NUMRANK      = 4
NUMBANKGROUP = 4
NUMBANK      = 4

전체 bank 수

2 channels
4 ranks
4 bankgroups
4 banks

총 bank

2 × 4 × 4 × 4 = 128 banks


---

8️⃣ Rank Execution Unit

NUM_RANKEXECUTION_UNIT = 1 << (RKWIDTH + CHWIDTH)

계산

RKWIDTH = 2
CHWIDTH = 1

2^(3) = 8

즉

8 Rank Execution Units

구조

Channel0 Rank0
Channel0 Rank1
Channel0 Rank2
Channel0 Rank3

Channel1 Rank0
Channel1 Rank1
Channel1 Rank2
Channel1 Rank3


---

9️⃣ PHY FIFO 구조

PHYFIFOMAXENTRY = 4
PHYFIFODEPTH = PHYFIFOMAXENTRY * BURST_LENGTH

계산

4 × 8 = 32

즉

32 data entries

PHY에서 burst data buffering.


---

🔟 Scheduling 정책 파라미터

THRESHOLD = 512
AGINGWIDTH = 10
CHMODETHRESHOLD = 16
RESPSCHEDULINGCNT = 4

설계 의미

파라미터	의미

THRESHOLD	starvation 방지
AGINGWIDTH	aging counter width
CHMODETHRESHOLD	read/write mode switching
RESPSCHEDULINGCNT	response scheduler fairness



---

11️⃣ DRAM 주소 구조체

typedef struct packed {
    logic channel;
    logic rank;
    logic bankgroup;
    logic bank;
    logic row;
    logic col;
} mem_addr_t;

이 구조는

AXI address
→ DRAM address

변환 후 저장됩니다.


---

12️⃣ Buffer Directory Entry

Read buffer entry

typedef struct packed {
    mem_addr_t addr;
    id;
    user;
} ReadBufferDirEntry;

Write buffer entry

typedef struct packed {
    addr
    id
    user
    ptr
    strb
    issued
    valid
}

추가 필드

필드	의미

ptr	write buffer pointer
strb	byte mask
issued	command issued
valid	entry valid



---

13️⃣ FSM Request 구조

typedef struct packed {
    mem_addr_t mem_addr;
    logic [2:0] PageHit;
    logic PageMiss;
    logic PageEmpty;
    logic AutoPreCharge;
    logic req_type;
    logic req_user;
    logic req_id;
}

Rank Scheduler가 FSM에 전달하는 요청.

Page 상태

필드	의미

PageHit	row hit
PageMiss	row conflict
PageEmpty	row closed



---

14️⃣ DRAM Timing 파라미터

여기서 중요한 부분.

예

tRCD  = 16
tRP   = 16
tCL   = 16
tCWL  = 12
tWR   = 18
tRFC  = 256

이 값들은

논문

Ramulator 2.0

기반.

FSM에서

ACT → READ timing
READ → PRE timing
WRITE → PRE timing

제어합니다.


---

15️⃣ AXI 인터페이스 정의

AXI channel 구조

AW
W
AR
R
B

각각 struct로 정의

예

axi_aw_chan_t
axi_w_chan_t
axi_ar_chan_t
axi_r_chan_t
axi_b_chan_t

이 구조는 AXI bus modeling에 사용됩니다.


---

16️⃣ Cache side interface

typedef struct packed{
    aw
    w
    ar
    r_ready
    b_ready
}

즉

CPU cache → memory controller

요청.


---

17️⃣ Memory controller side interface

mc_side_request
mc_side_response

Frontend → Backend 인터페이스.


---

18️⃣ 이 패키지의 역할 (아키텍처 관점)

이 패키지는 다음 5가지 역할을 합니다.

1️⃣ Controller configuration

채널 / 랭크 / 뱅크 수


---

2️⃣ DRAM timing 정의

tRCD, tRP 등


---

3️⃣ Address mapping

AXI → DRAM


---

4️⃣ Buffer 구조 정의

Read / Write buffer


---

5️⃣ 인터페이스 정의

Cache side
MC side


---

📌 전체 아키텍처에서 위치

CPU
                 │
             AXI Bus
                 │
        ┌─────────────────┐
        │  Frontend       │
        │                 │
        │ Address Decode  │
        │ Write Assembly  │
        └─────────┬───────┘
                  │
          mc_side_request
                  │
        ┌─────────────────┐
        │ Backend         │
        │ Rank Scheduler  │
        │ Bank FSM        │
        └─────────────────┘

이 모든 모듈이

MemoryController_Definitions

을 import합니다.


---

✔ 핵심 정리

이 코드는

> DDR Memory Controller 전체 설계에서 사용되는 공통 파라미터, DRAM 타이밍, 주소 구조, 버퍼 구조, AXI 인터페이스, 내부 요청 구조를 정의한 SystemVerilog 패키지입니다.



즉

컨트롤러의 전체 아키텍처 사양(specification)을 코드로 표현한 파일입니다.

