## 1. 핵심 요약 (Core Concept)
> **Dispatcher (디스패처)**

## 2. 상세 분석
본 모듈은 입수된 AXI 주소 데이터를 메모리 컨트롤러 내부의 물리적 구조에 매핑하고, 다중화된 실행 유닛(Rank Execution Unit) 중 적절한 타겟을 찾아 신호를 배분하는 **중재 및 할당자** 역할을 수행합니다.

### 주요 기능
* **주소 디코딩 (Address Decoding):** 입력된 `readAddr` 또는 `writeAddr`를 `MemoryAddress` 구조체(Channel, Rank, Bank 등)에 맞춰 분해합니다.
* **대상 식별 (Target Identification):** 주소의 상위 비트를 기반으로 어떤 FSM이 해당 요청을 처리해야 하는지 (`targetFSMIndex`) 결정합니다.
* **조건부 신호 생성 (Conditional Steering):** 해당 유닛이 준비 상태(`readReady`, `writeReady`)인 경우에만 `targetFSMVector`를 활성화하여 요청을 전달합니다.

### 기술적 특징
* **우선순위 제어:** `readValid`가 `writeValid`보다 우선순위를 갖도록 설계되었습니다.
* **파라미터화:** 메모리 및 AXI 주소 폭, 실행 유닛의 수 등을 유연하게 설정할 수 있는 구조입니다.

---
*분석 일시: 2026-03-08*
