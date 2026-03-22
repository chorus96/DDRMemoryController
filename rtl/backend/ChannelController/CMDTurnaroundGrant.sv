`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////
//      CMDTurnaroundCalculator
//
//      Role:
//          Enforces rank-to-rank CMD bus turnaround timing (tRTR).
//
//      Functionality:
//          - Detects rank transitions on the CMD bus.
//          - Blocks CMD issuance for tRTRS cycles after a rank transition.
//          - Exposes CMDTurnaroundFree to indicate when CMD bus can be used.
//
//      Usage:
//          - Triggered by rankTransition from CMDGrantScheduler if the target arbitrated rank is changed.
//          - Used by RankControllers to gate CMD bus grants.
//
//      Notes:
//          - This module does not perform arbitration.
//          - It only tracks channel-level CMD bus timing constraints.
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////  
//      CMDTurnaroundCalculator  
//      (명령 버스 턴어라운드 타이밍을 계산하는 모듈)
//
//      역할:
//          Rank 간 전환 시 CMD 버스 턴어라운드 타이밍(tRTR)을 강제(준수하도록 보장)한다.
// 
//      기능:
//          - CMD 버스에서 rank 전환이 발생했는지를 감지한다.
//          - rank 전환이 발생한 이후 tRTRS 사이클 동안 CMD 발행을 차단한다.
//          - CMD 버스를 사용할 수 있는 시점을 나타내는 CMDTurnaroundFree 신호를 외부에 제공한다.
//
//      사용 방식: 
//          - CMDGrantScheduler에서 arbitration 결과 선택된 rank가 변경될 경우,
//            rankTransition 신호에 의해 트리거된다.
//          - RankController들이 CMD 버스 grant를 제어(gating)하는 데 사용된다.
//  
//      참고 사항:
//          - 이 모듈은 arbitration(중재)을 수행하지 않는다.
//          - 이 모듈은 채널 수준의 CMD 버스 타이밍 제약만 추적한다.
//
//      작성자 : Seongwon Jo
//      작성일 : 2026년 2월
//////////////////////////////////////////////////////////////////////////////////////////

module CMDTurnaroundGrant #(
    parameter int tRTRS = 2
) (
    input  logic clk, rst,
    input  logic rankTransition,
    output logic CMDTurnaroundFree
);

    logic flag;
    logic [$clog2(tRTRS) - 1 : 0] cnt;

    //------------------------------------------------------------------------------
    // Rank-to-Rank Turnaround Counter
    //
    //   - Loaded with (tRTRS - 1) on rank transition.
    //   - Decrements while flag is asserted.
    //------------------------------------------------------------------------------   
    always_ff @(posedge clk or negedge rst) begin :tRTRsCounterSetup
        if (!rst) begin
            cnt <= 0;
        end else begin
            if (flag) begin
                cnt <= cnt - 1;
            end else if (rankTransition) begin
                cnt <= tRTRS - 1;
`ifdef DISPLAY
                $display("[%0t] CMDTurnaroundCalculator | tRTR TIMING CONSTRAINTS FREE", $time);
`endif
            end else begin
                cnt <= 0;
            end
        end
    end : tRTRsCounterSetup

    assign flag = ((cnt == 0) && rankTransition) ? 1 : (cnt != 0 ) ? 1: 0;
    // CMD bus is free only when no turnaround timing is in progress
    assign CMDTurnaroundFree = !flag;

endmodule
