본 SystemVerilog 코드를 한 단어로 요약하면 다음과 같습니다.
Decoder (또는 Router)
이 모듈은 입력된 주소(Address) 정보를 해석(Decoding)하여, 해당 요청이 어느 FSM(Finite State Machine) 유닛으로 가야 할지를 결정하고 경로를 할당하는 전형적인 디코더/라우터의 역할을 수행하고 있습니다.
분석 결과 보고서
| 항목 | 내용 |
|---|---|
| 핵심 기능 | AXI 주소를 기반으로 한 메모리 계층 구조(Channel, Rank 등) 분리 및 타겟 유닛 선택 |
| 주요 동작 | 입력 주소를 구조체(MemoryAddress) 필드에 매핑하고, 상위 비트를 추출하여 유닛 인덱스 생성 |
| 입력 신호 | readAddr, writeAddr, readValid, writeValid, 각 유닛의 Ready 상태 |
| 출력 신호 | 선택된 유닛의 원-핫 벡터(targetFSMVector), 인덱스(targetFSMIndex), 변환된 메모리 주소 |
상세 분석 개요
 * 주소 매핑 (Address Mapping): 입력받은 readAddr 또는 writeAddr를 requestMemAddr 구조체의 각 필드(Channel, Rank, Bank 등)로 분해합니다. 이는 하드웨어 메모리 컨트롤러에서 물리적 주소를 논리적 계층으로 나누는 과정입니다.
 * 타겟 결정 (Target Identification):
   FSM_WIDTH만큼의 상위 비트를 사용하여 어떤 실행 유닛(RankExecution Unit)이 이 요청을 처리할지 결정합니다.
   * targetFSMIndex: 주소의 특정 비트를 슬라이싱하여 정수 인덱스 생성
   * targetFSMVector: 해당 인덱스만 1로 만드는 One-hot 인코딩 방식 적용
 * 핸드셰이크 확인 (Ready Check):
   단순히 주소만 바꾸는 것이 아니라, 대상 유닛의 Ready 신호를 확인하여 유효한 요청일 때만 타겟 신호를 활성화하는 제어 로직이 포함되어 있습니다.
