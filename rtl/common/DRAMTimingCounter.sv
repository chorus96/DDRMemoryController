`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////
//      DRAMTimingCounter
//
//      Role:
//          Generic timing counter used for enforcing DRAM timing constraints (Especially in Rank FSM Load Timer)
//          (e.g., tRCD, tRP, tWR, tRFC, etc.).
//
//      Functionality:
//          - Loads a timing value when 'setup' is asserted.
//          - Decrements the counter every cycle.
//          - Asserts 'timeUp' for one cycle when the counter expires.
//
//      Usage Model:
//          - setup : asserted to (re)initialize the counter with 'load'.
//          - load  : timing value in cycles.
//          - timeUp: asserted when timing constraint has been satisfied.
//
//      Design Assumptions:
//          - Counter expiration and re-initialization must not occur
//            in the same cycle.
//          - Counter is inactive when countLoad == 0.
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//      DRAMTimingCounter
//
//      역할(Role):
//          DRAM 타이밍 제약을 강제(enforce)하기 위해 사용하는
//          범용 타이밍 카운터.
//          (특히 Rank FSM의 Load Timer에서 사용됨)
//          예: tRCD, tRP, tWR, tRFC 등.
//
//      기능(Functionality):
//          - 'setup' 신호가 asserted 되면
//            카운터를 'load' 값으로 초기화함.
//          - 매 사이클마다 카운터 값을 감소시킴.
//          - 카운터가 만료되면(expire)
//            한 사이클 동안 'timeUp' 신호를 asserted 함.
//
//      사용 모델(Usage Model):
//          - setup : 'load' 값으로 카운터를 (재)설정할 때 asserted.
//          - load  : 사이클 단위의 타이밍 값.
//          - timeUp: 해당 타이밍 제약이 만족되었음을 알리는 신호.
//
//      설계 가정(Design Assumptions):
//          - 카운터 만료와 재초기화는
//            동일한 사이클에 발생하지 않아야 함.
//          - countLoad == 0 인 경우
//            카운터는 비활성 상태로 간주됨.
//
//      작성자  : Seongwon Jo
//      작성일  : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////

module DRAMTimingCounter(
    input  logic clk, 
    input  logic rst,
    input  logic setup,
    input  logic [5:0] load,
    output logic timeUp
);

    logic [5:0] countLoad;
    logic       countEnd;
    
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            countLoad <= 0;
            countEnd  <= 0;
        end else begin
            if (setup) begin
                countLoad <= load;
            end else begin
                if (countLoad != 0) begin
                    countLoad <= countLoad - 1;
                    if (countLoad == 1) begin
                        countEnd <= 1;
                    end
                end else begin
                    countLoad <= 0;
                    countEnd  <= 0;
                end
            end
        end
    end

    assign timeUp = countEnd;

`ifdef ASSERTION
    DRAMTimingCounterSetup : assert property (
        @(posedge clk) disable iff (!rst)
        !(setup && countEnd)
    ) else
        $error("DRAMTimingCounter: setup and countEnd asserted together");
`endif

endmodule
