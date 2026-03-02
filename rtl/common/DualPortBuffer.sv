`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////
//      DualPortBuffer
//
//      Role:
//          Simple dual-port buffer providing independent read and write access.
//          Designed to decouple producer and consumer operating on the same clock.
//
//      Functionality:
//          - One write port and one read port.
//          - Write and read addresses are supplied explicitly.
//          - Read and write can occur in the same cycle to different addresses.
//
//      Typical Usage:
//          - Write side  : PHY / Memory / Backend logic
//          - Read side   : Cache / Frontend / Consumer logic
//
//      Interface Semantics:
//          - we        : Write enable (writes wdata into mem[writePtr])
//          - re        : Read enable (captures mem[readPtr] into rdata)
//          - readPtr   : Address for read operation
//          - writePtr  : Address for write operation
//
//      Design Notes:
//          - This is NOT a FIFO:
//              * No internal pointer management
//              * No full/empty detection
//          - Pointer generation and hazard avoidance must be handled externally.
//          - Read data is registered (1-cycle latency).
//
//      Reset Behavior:
//          - Memory array is cleared on reset (simulation-friendly).
//          - rdata is reset to zero.
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////            
//      DualPortBuffer            
//            
//      역할(Role):            
//          독립적인 읽기/쓰기 접근을 제공하는 간단한 듀얼 포트 버퍼.            
//          동일한 클록에서 동작하는 생산자(producer)와 소비자(consumer)를            
//          서로 분리(decouple)하기 위해 설계됨.            
//            
//      기능(Functionality):            
//          - 하나의 쓰기 포트와 하나의 읽기 포트를 가짐.            
//          - 읽기 및 쓰기 주소는 외부에서 명시적으로 제공됨.            
//          - 서로 다른 주소에 대해서는 동일 사이클에 읽기와 쓰기가 동시에 가능함.            
//            
//      일반적인 사용(Typical Usage):            
//          - 쓰기 측  : PHY / 메모리 / 백엔드 로직            
//          - 읽기 측  : 캐시 / 프론트엔드 / 소비자 로직            
//            
//      인터페이스 의미(Interface Semantics):            
//          - we        : 쓰기 인에이블 (mem[writePtr]에 wdata를 기록)            
//          - re        : 읽기 인에이블 (mem[readPtr]의 값을 rdata로 캡처)            
//          - readPtr   : 읽기 동작을 위한 주소            
//          - writePtr  : 쓰기 동작을 위한 주소            
//            
//      설계 참고사항(Design Notes):            
//          - 이것은 FIFO가 아님:            
//              * 내부 포인터 관리 없음            
//              * full / empty 검출 없음            
//          - 포인터 생성과 해저드(hazard) 회피는 외부에서 처리해야 함.            
//          - 읽기 데이터는 레지스터링됨 (1-사이클 지연).            
//            
//      리셋 동작(Reset Behavior):            
//          - 리셋 시 메모리 배열을 초기화함 (시뮬레이션 친화적).            
//          - rdata는 0으로 리셋됨.            
//            
//      작성자  : Seongwon Jo            
//      생성일  : 2026.02            
//////////////////////////////////////////////////////////////////////////////////////////

module DualPortBuffer #(
    parameter int BufferDepth = 8,
    parameter type DataEntry = logic

    )(
    input logic clk, rst,
    input logic re, we,
    input logic [$clog2(BufferDepth)-1:0] readPtr,
    input logic [$clog2(BufferDepth)-1:0] writePtr,
    input DataEntry wdata,
    output DataEntry rdata
);

    DataEntry mem [BufferDepth-1:0];

    
    // write port (PHY-side)
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (int i = 0; i < BufferDepth; i++) begin
            /* verilator lint_off BLKSEQ */
                mem[i] = '0;
            end
        end else if (we) begin
            mem[writePtr] <= wdata;
        end
    end

    // read port (Cache-side)
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            rdata <= '0;
        end else if (re) begin
            rdata <= mem[readPtr];
        end
    end

`ifdef ASSERTION
    DualPortBufferRAW : assert property ( @(posedge clk) disable iff(!rst)
        !(re && we && (readPtr == writePtr))
    ) else $fatal(2,"DualPortBuffer: RAW Hazard occured.");
`endif
endmodule
