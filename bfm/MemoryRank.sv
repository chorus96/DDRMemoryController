`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////////////
//
//      MemoryRank  (DDR4 Rank BFM)
//
//      Role:
//          Behavioral model of a single DDR4 rank for simulation and verification.
//          Aggregates multiple bank-level BFMs and emulates rank-level command
//          decoding and DQ behavior.
//
//      BFM Scope:
//          - This module is intended for **simulation only**.
//          - NOT synthesizable.
//          - Focused on protocol correctness and timing observability,
//                  not electrical or physical accuracy.
//
//      Architectural Overview:
//
//              DDR4 IF CMD / DQ BUS
//                    |   ∧
//                    V   |
//                +-----------+
//                | MemoryRank|   (This module)
//                +-----------+
//                  |   |   |
//          +--------+   |  +----  ...  ----+
//          |            |                  |
//      BankFSM[0]   BankFSM[1]    ...  BankFSM[N]
//
//      Responsibilities:
//          1) Decode rank-level CMD/ADDR signals (CS_n, BG, BK).
//          2) Select and activate the target MemoryBankFSM.
//          3) Fan-out shared control and DQ signals to all banks.
//          4) Aggregate per-bank read/write burst activity.
//          5) Expose rank-level DQ valid signals to the controller.
//
//      Modeling Assumptions:
//          - One command targets one bank at a time.
//          - At most one bank drives the DQ bus concurrently.
//          - Timing constraints are enforced at bank-level FSMs.
//
//      Design Notes:
//          - Intended for:
//              * Memory controller verification
//              * Timing FSM validation
//              * Read/write ordering and arbitration debugging
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////
//
//      MemoryRank  (DDR4 Rank BFM)
//
//      역할(Role):
//          시뮬레이션 및 검증을 위한 단일 DDR4 Rank의 동작 모델.
//          여러 개의 Bank 수준 BFM을 집합적으로 구성하고 Rank 수준의 명령
//          디코딩 및 DQ 동작을 에뮬레이션한다.
//
//      BFM 범위(BFM Scope):
//          - 이 모듈은 **시뮬레이션 전용**이다.
//          - 합성(synthesis) 대상이 아니다.
//          - 전기적/물리적 정확성보다는 프로토콜의 정확성과
//            타이밍 관찰 가능성에 초점을 둔다.
//
//      아키텍처 개요:
//
//              DDR4 IF CMD / DQ BUS
//                    |   ∧
//                    V   |
//                +-----------+
//                | MemoryRank|   (이 모듈)
//                +-----------+
//                  |   |   |
//          +--------+   |  +----  ...  ----+
//          |            |                  |
//      BankFSM[0]   BankFSM[1]    ...  BankFSM[N]
//
//      책임(Responsibilities):
//          1) Rank 수준 CMD/ADDR 신호(CS_n, BG, BK)를 디코딩한다.
//          2) 대상 MemoryBankFSM을 선택하고 활성화한다.
//          3) 공유된 제어 신호와 DQ 신호를 모든 Bank로 전달한다.
//          4) Bank별 Read/Write burst 동작을 집계한다.
//          5) Rank 수준의 DQ 유효 신호를 컨트롤러에 제공한다.
//
//      모델링 가정(Modeling Assumptions):
//          - 하나의 명령은 한 번에 하나의 Bank만을 대상으로 한다.
//          - 동시에 DQ 버스를 구동하는 Bank는 최대 하나이다.
//          - 타이밍 제약은 Bank 수준 FSM에서 강제된다.
//
//      설계 참고 사항(Design Notes):
//          - 다음 목적을 위해 사용된다:
//              * 메모리 컨트롤러 검증
//              * 타이밍 FSM 검증
//              * Read/Write 순서 및 중재(arbitration) 디버깅
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////////////

module MemoryRank#(
    parameter int RANKID        = 0,
    parameter int IOWIDTH       = 0,
    parameter int DEVICEPERRANK = 4,
    parameter int CWIDTH        = 10,
    parameter int RWIDTH        = 15,
    parameter int BGWIDTH       = 2,
    parameter int BKWIDTH       = 2,
    parameter int COMMAND_WIDTH = 18,
    parameter int BURST_LENGTH  = 8,
    parameter int MEM_DATAWIDTH = 64,
    parameter int tCWL          = 12,
    parameter int tCL           = 16,
    parameter int tRCD          = 16,
    parameter int tRFC          = 256,
    parameter int tRP           = 16
)(
    input logic clk, rst_n, clk2x,

    inout wire rankDQS_t, rankDQS_c,
    output logic [MEM_DATAWIDTH-1:0] rankRdData,
    input logic [MEM_DATAWIDTH-1:0] rankWrData,

    input logic [MEM_DATAWIDTH/BURST_LENGTH-1:0] rankDataStrb,

    DDR4Interface.Memory_CA ddr4_cmdaddr_if,

    output logic rankDQRdValid, rankDQWrValid
);

    localparam int NUMBANKFSM = 1 << (BGWIDTH + BKWIDTH);

    logic [NUMBANKFSM-1:0] bankCMDGranted;
    logic [NUMBANKFSM-1:0] bankDQRdGranted, bankDQWrGranted;
    logic rankSelect;

    logic [MEM_DATAWIDTH-1:0] bankRdData [NUMBANKFSM-1:0];
    logic [MEM_DATAWIDTH-1:0] bankWrData [NUMBANKFSM-1:0];

    //------------------------------------------------------------------------------
    //      Bank Command Decode (BFM)
    //
    //      - Decodes BG/BK fields from CMD/ADDR interface.
    //      - Generates one-hot bank activation vector.
    //      - Used to trigger behavioral execution in a single bank FSM.
    //------------------------------------------------------------------------------
    always_comb begin
        bankCMDGranted = '0;
        if(ddr4_cmdaddr_if.cke) begin
            bankCMDGranted[{ddr4_cmdaddr_if.bg, ddr4_cmdaddr_if.b}] = 1;
        end
    end
    assign rankSelect = (ddr4_cmdaddr_if.cs_n[RANKID] == 0) ? 0 : 1;

    //------------------------------------------------------------------------------
    //      Bank-Level FSM Instantiation (BFM)
    //
    //      - Each MemoryBankFSM models one DRAM bank behaviorally.
    //      - FSMs receive identical rank-level signals,
    //          but only the selected bank reacts.
    //
    //  NOTE:
    //      - Parallel bank FSMs allow verification of bank-level overlap
    //          and command interleaving behavior.
    //------------------------------------------------------------------------------
    //------------------------------------------------------------------------------
    //      Bank-Level FSM 인스턴스화 (BFM)
    //
    //      - 각 MemoryBankFSM은 하나의 DRAM Bank 동작을 행동 수준(Behavioral)으로 모델링한다.
    //      - FSM들은 동일한 Rank 레벨 신호를 입력으로 받지만,
    //          선택된 Bank만 실제로 반응한다.
    //
    //  참고(NOTE):
    //      - 병렬로 존재하는 Bank FSM들은 Bank 수준의 동시성(overlap)과
    //          명령 인터리빙(command interleaving) 동작을 검증할 수 있게 한다.
    //------------------------------------------------------------------------------    genvar i;
    generate
        for(i = 0; i < NUMBANKFSM; i++) begin : genMemoryBankFSM
            MemoryBankFSM #(
                .BANKID(i % 4),
                .BANKGROUPID(i / 4),
                .IOWIDTH(IOWIDTH),
                .DEVICEPERRANK(DEVICEPERRANK),
                .CWIDTH(CWIDTH),
                .RWIDTH(RWIDTH),
                .BGWIDTH(BGWIDTH),
                .BKWIDTH(BKWIDTH),
                .COMMAND_WIDTH(COMMAND_WIDTH),
                .BURST_LENGTH(BURST_LENGTH),
                .MEM_DATAWIDTH(MEM_DATAWIDTH),
                .tCWL(tCWL),
                .tCL(tCL),
                .tRCD(tRCD),
                .tRFC(tRFC),
                .tRP(tRP)
            ) BankFSM (
                .clk(clk), .rst_n(rst_n), .clk2x(clk2x),
                
                .bankCKE(bankCMDGranted[i]),
                .bankCS_N(rankSelect),
                .bankPAR(ddr4_cmdaddr_if.par),
                .bankPIN_A(ddr4_cmdaddr_if.pin_A),
                .bankACT_N(ddr4_cmdaddr_if.act_n),

                .bankDM_N(rankDataStrb),
                .bankUDM_N(),
                .bankLDM_N(),
                .bankODT(),

                .bankRdDQ(bankRdData[i]),
                .bankWrDQ(bankWrData[i]),
                .bankDQS_t(rankDQS_t),
                .bankDQS_c(rankDQS_c),

                .ReadBurstValid(bankDQRdGranted[i]),
                .WriteBurstValid(bankDQWrGranted[i])
            );
        end : genMemoryBankFSM
    endgenerate

    //------------------------------------------------------------------------------
    //      Rank-Level DQ Activity Aggregation (BFM)
    //
    //      - OR-reduces read/write burst valid signals from all banks.
    //      - Indicates active DQ ownership at rank level.
    //
    //  BFM Assumption:
    //      - Multiple banks asserting DQ valid simultaneously is illegal.
    //------------------------------------------------------------------------------
    logic [$clog2(NUMBANKFSM)-1:0] assertionCnt;
    always_comb begin
        for (int p = 0; p < NUMBANKFSM; p++) begin
            bankWrData[p] = 0;
        end
        assertionCnt = 0;
        for (int q = 0; q < NUMBANKFSM; q++) begin
            if(bankDQRdGranted[q]) begin
                rankRdData = bankRdData[q];
                assertionCnt = assertionCnt +1;
            end
            if (bankDQWrGranted[q]) begin
                bankWrData[q] = rankWrData;
                assertionCnt = assertionCnt + 1;
            end
        end
        MultipleBankDriven :assert(
            (assertionCnt == 1) || (assertionCnt == 0)
        ) else $fatal(2, "MemoryBankFSM multiple-driven");
    end
    assign rankDQRdValid = |bankDQRdGranted;
    assign rankDQWrValid = |bankDQWrGranted;

endmodule
