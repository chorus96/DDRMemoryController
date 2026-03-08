본 SystemVerilog 코드는 AXI 인터페이스의 물리 주소를 DRAM의 구조적 주소(Channel, Rank, Bank 등)로 변환하고, 이를 처리할 적절한 상태 머신(FSM)을 결정하는 Address Translation Unit (ATU) 모듈입니다.
분석 내용을 정리한 Markdown 문서입니다.
[분석 보고서] Address Translation Unit (ATU) 모듈
1. 개요
본 모듈은 AXI 버스로부터 입력된 물리 주소를 DRAM 제어에 필요한 세부 주소 필드로 변환하고, 해당 요청을 처리할 **Rank Execution Unit(FSM)**을 선택하는 중재 로직을 수행합니다.
2. 주요 기능 및 특징
 * 주소 필드 분해: 연속된 물리 주소를 Channel, Rank, Bank Group, Bank, Row, Column으로 분리합니다.
 * FSM 매핑 정책: (Channel, Rank) 쌍마다 하나의 FSM을 할당하는 정책을 사용합니다.
 * 병렬 처리 지원: 각 FSM 내부에서 뱅크 레벨의 병렬성(Bank-level parallelism)을 처리할 수 있도록 설계되었습니다.
 * 우선순위: 읽기 요청(readValid)이 쓰기 요청(writeValid)보다 우선적으로 처리되는 구조입니다.
3. 입출력 포트 정의

| 구분 | 포트명 | 비트 폭 | 설명 |
|---|---|---|---|
| Inputs | readAddr / writeAddr | AXI_ADDRWIDTH | AXI 시스템 물리 주소 |
|  | readReady / writeReady | NUM_RANKEXECUTION_UNIT | 각 FSM(Rank 단위)의 준비 상태 비트맵 |
|  | readValid / writeValid | 1-bit | 읽기/쓰기 요청 유효 신호 |
| Outputs | targetFSMVector | NUM_RANKEXECUTION_UNIT | 선택된 FSM을 가리키는 원-핫(One-hot) 벡터 |
|  | targetFSMIndex | NUM_RANKEXECUTION_UNIT_BIT | 선택된 FSM의 인덱스 번호 |
|  | requestMemAddr | MemoryAddress (struct) | 구조화된 DRAM 주소 데이터 |

4. 내부 로직 분석
A. 주소 변환 (Address Decoding)
입력된 AXI 주소는 MemoryAddress 구조체의 필드 순서에 따라 슬라이싱되어 할당됩니다.
{requestMemAddr.channel, requestMemAddr.rank, requestMemAddr.bankgroup, 
 requestMemAddr.bank, requestMemAddr.row, requestMemAddr.col} = readAddr;

 * 참고: 현재는 고정 매핑 방식이나, 주석에 따르면 향후 XOR 또는 해시 기반의 주소 변환(Bank Interleaving 등)이 추가될 여지가 있습니다.
B. 대상 FSM 선택 로직
 * 인덱싱: targetFSMIndex는 주소의 상위 비트(FSM_WIDTH)를 추출하여 결정됩니다.
 * 준비 상태 확인: 해당 인덱스의 FSM이 준비(readReady 또는 writeReady)되었는지 확인합니다.
 * 벡터 생성: 유효한 요청이고 FSM이 준비되었다면, targetFSMVector의 해당 비트를 1로 셋트하여 하위 모듈에 신호를 보냅니다.
5. 개선 및 주의 사항 (Code Review)
> [!TIP]
> 1. 인덱스 불일치 가능성
> 현재 코드에서 targetFSMIndex를 계산할 때 readAddr의 최상위 비트를 사용(readAddr[MEM_ADDRWIDTH-1 -: FSM_WIDTH])하는 부분과, readReady 비트를 체크할 때 {channel, rank}를 사용하는 부분 사이의 논리적 일관성을 확인해야 합니다. 만약 주소의 상위 비트 구성이 {channel, rank} 순서와 다르다면 잘못된 FSM을 가리킬 수 있습니다.
> 2. 조합 논리(Combinational Logic) 루프
> always_comb 블록을 사용하므로, 입력 신호에 따른 즉각적인 반응이 가능합니다. 다만, requestMemAddr의 할당이 조건문(if(readValid)) 내부와 외부에서 혼재될 경우 의도치 않은 래치(Latch)가 발생하지 않도록 초기값('0) 할당이 적절히 이루어져 있습니다.
> 
추가로 분석이 필요하시거나, 특정 주소 매핑 알고리즘(XOR 등)의 구현 방법이 궁금하시면 말씀해 주세요!

