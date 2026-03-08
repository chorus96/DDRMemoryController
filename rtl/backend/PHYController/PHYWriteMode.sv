`timescale 1ns / 1ps

//------------------------------------------------------------------------------
//      PHYWriteMode
//
//      Role:
//          Physical WRITE-mode data handler inside the PHYController.
//          This module models the DDR4 WRITE data path at burst granularity.
//
//      Position in Architecture:
//
//          ChannelController
//                 |
//                 V
//            PHYController
//                 |
//                 V
//           +--------------+
//           | PHYWriteMode |
//           +--------------+
//                 |
//                 V
//              DDR4 DQ/DQS
//
//      Responsibilities:
//          - Accept WRITE data from Write Buffer via PHYController.
//          - Buffer burst-length data inside PHY-local FIFO.
//          - Generate DQS toggling synchronized with clk2x.
//          - Drive DQ/DQS/DM signals toward DRAM.
//          - Generate burst-level ACK to PHYController.
//
//      Data Flow:
//           Write Buffer
//               |
//               V
//         [ clk domain ]
//               |
//         PHY Write FIFO
//               |
//               V
//         [ clk2x domain (Abstract PHY) ]
//               |
//               V
//          DDR4 DQ / DQS
//
//      What this module DOES:
//          - Burst-aware WRITE data buffering.
//          - DQS generation and alignment using clk2x.
//          - Controlled DQ/DM driving toward DRAM.
//          - Precise WRITE burst completion detection.
//
//      What this module DOES NOT do:
//          - No command scheduling or arbitration.
//          - No timing decision logic (tCWL handled in PHYController).
//          - No DDR electrical accuracy modeling.
//
//      Design Assumptions:
//          - inflag is asserted only when WRITE data is valid from buffer.
//          - outflag is asserted only when PHYController allows DRAM driving.
//          - BURST_LENGTH is fixed and power-of-two.
//          - Only one WRITE burst is active at a time per channel.
//
//      Notes:
//          - DQS toggles on every clk2x edge during WRITE burst.
//          - outACK is asserted exactly once per WRITE burst.
//          - DM is inverted to match DDR4 active-low convention.
//          - FIFO is reset when inflag is deasserted.
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//      PHYWriteMode
//
//      역할(Role):
//          PHYController 내부의 물리적 WRITE 모드 데이터 처리 블록.
//          DDR4 WRITE 데이터 경로를 버스트 단위로 모델링하는 모듈.
//
//      아키텍처 내 위치(Position in Architecture):
//
//          ChannelController
//                 |
//                 V
//            PHYController
//                 |
//                 V
//           +--------------+
//           | PHYWriteMode |
//           +--------------+
//                 |
//                 V
//              DDR4 DQ/DQS
//
//      주요 책임(Responsibilities):
//          - PHYController를 통해 Write Buffer로부터 WRITE 데이터 수신.
//          - 버스트 길이 단위의 데이터를 PHY 로컬 FIFO에 버퍼링.
//          - clk2x에 동기화된 DQS 토글 신호 생성.
//          - DRAM을 향해 DQ / DQS / DM 신호 구동.
//          - 버스트 단위 WRITE 완료 ACK를 PHYController로 생성.
//
//      데이터 흐름(Data Flow):
//           Write Buffer
//               |
//               V
//         [ clk 도메인 ]
//               |
//         PHY Write FIFO
//               |
//               V
//         [ clk2x 도메인 (추상화된 PHY) ]
//               |
//               V
//          DDR4 DQ / DQS
//
//      이 모듈이 하는 일(What this module DOES):
//          - WRITE 버스트를 인식한 데이터 버퍼링.
//          - clk2x를 이용한 DQS 생성 및 정렬(alignment).
//          - DRAM 방향으로의 DQ / DM 신호 제어된 구동.
//          - WRITE 버스트 완료 시점을 정확히 검출.
//
//      이 모듈이 하지 않는 일(What this module DOES NOT do):
//          - 명령 스케줄링 또는 중재(arbitration).
//          - 타이밍 결정 로직 (tCWL은 PHYController에서 처리).
//          - DDR 전기적(electrical) 정확도 모델링.
//
//      설계 가정(Design Assumptions):
//          - inflag는 Write Buffer로부터 WRITE 데이터가 유효할 때만 asserted 됨.
//          - outflag는 PHYController가 DRAM 구동을 허용할 때만 asserted 됨.
//          - BURST_LENGTH는 고정값이며 2의 거듭제곱.
//          - 채널당 한 번에 하나의 WRITE 버스트만 활성 상태로 존재.
//
//      참고 사항(Notes):
//          - WRITE 버스트 동안 DQS는 clk2x의 모든 에지에서 토글됨.
//          - outACK는 WRITE 버스트당 정확히 한 번만 asserted 됨.
//          - DM은 DDR4의 active-low 규약에 맞게 반전(invert)됨.
//          - inflag가 deassert되면 FIFO는 리셋됨.
//
//      작성자  : Seongwon Jo
//      작성일  : 2026.02
//------------------------------------------------------------------------------

module PHYWriteMode #(
    parameter int PHY_CHANNEL   = 0,
    parameter int MEM_DATAWIDTH = 64,
    parameter int PHYFIFODEPTH  = 32,
    parameter int BURST_LENGTH  = 8
)(
                                                            //                  Write Mode (PHY)              //
    input logic clk, rst,                          
                                                            //          OUTPUT TO  DRAM-SIDE                  //
    output logic dqs_t, dqs_c,                              //  1. Diff. signals for DQ BUS                   //
    output logic [MEM_DATAWIDTH - 1 : 0] outdata,           //  2. Data to DQ BUS WHEN Write Processing       //
    output logic [MEM_DATAWIDTH/BURST_LENGTH-1:0] outDM,    //  3. Data Masking Bit for 64-bit data           //


                                                            //          INPUT FROM PHYCONTROLLER              //
    input logic clk2x,                                      //  1. clock 2x for generating diff. signals      //
    input logic inflag,                                     //  2. Valid for Receiving Data from WRITE BUFFER //
    input logic [MEM_DATAWIDTH-1:0] inData,                 //  3. Data Receiving from WRITE BUFFER           //
    input logic [MEM_DATAWIDTH/BURST_LENGTH-1:0] inStrb,    //  4. Data Masking bit from WRITE BUFFER         //
    input logic outflag,                                    //  5. Valid for Sending Data to DRAM-SIDE        //

                                                            //          OUTPUT TO PHYCONTROLLER               //
    output logic outACK                                     //  1. ACK to PHY Controller for Sending Data     //
);



    logic [MEM_DATAWIDTH-1:0] writeModeFIFO [PHYFIFODEPTH-1:0];     //  BURST DATA FIFO IN PHY 
    logic writeModeDMFIFO [PHYFIFODEPTH-1:0];                       //  Data Masking of BURST DATA FIFO IN PHY         
    logic [$clog2(PHYFIFODEPTH)-1:0] burst_cnt_dram;                //  Burst Count for PHY -> DRAM 
    logic [$clog2(PHYFIFODEPTH)-1:0] burst_cnt_host;                //  Burst Count for PHY <- WRITE BUFFER
    

    //---  Burst Counter & Diff. Sig Setup for DQ-BUS  (COUNTER) --//
    always @(posedge clk2x or negedge rst) begin : FIFOPOPCntAndDiff
        if(!rst) begin
            dqs_t             <= 1'b0;
            dqs_c             <= 1'b1;
            burst_cnt_dram    <= 0;
        end else begin
            if(outflag) begin
                `ifdef DISPLAY
                    $display("[%0t] PHYWriteMode | SERVING WRITE DATA : %h | Read: %d", $time, outdata, burst_cnt_dram[$clog2(BURST_LENGTH)-1:0]);
                `endif
                dqs_t <= ~dqs_t;
                dqs_c <= dqs_t;
                if(burst_cnt_dram == PHYFIFODEPTH-1)begin
                    burst_cnt_dram <= 0;
                end else begin
                    burst_cnt_dram <= burst_cnt_dram + 1;
                end
            end else begin
                dqs_t           <= '0;
                dqs_c           <= '1;
                burst_cnt_dram  <= '0;
            end
        end
    end : FIFOPOPCntAndDiff

    /////////////////////////////////////////////////////////////


    assign outACK = (burst_cnt_dram[2:0] == BURST_LENGTH-1) ? 1: 0;
    /////////////////////////////////////////////////////////////

    //-----------  Burst Data FIFO POP Process  (POP) ---------//
    assign outdata = (outflag) ? writeModeFIFO[burst_cnt_dram] : 'z; 
    `ifdef VERILATOR
        assign outDM = outflag ? ~writeModeDMFIFO[burst_cnt_dram] : '0;
    `else
        assign outDM = outflag ? ~writeModeDMFIFO[burst_cnt_dram] : 'z;
    `endif
    /////////////////////////////////////////////////////////////

    //-----------  Burst Data FIFO PUSH Process  (PUSH) ---------//
    always_ff@(posedge clk or negedge rst) begin : FIFOPUSH
        if(!rst) begin
            burst_cnt_host           <= 0;
            for(int i =0; i< PHYFIFODEPTH; i++) begin
                writeModeFIFO[i]     <= 0;
                writeModeDMFIFO[i]   <= 0;
            end
        end else begin
            if(inflag) begin
                writeModeFIFO[burst_cnt_host]     <= inData;
                writeModeDMFIFO[burst_cnt_host]   <= inStrb;
                if(burst_cnt_host == PHYFIFODEPTH-1) begin
                    burst_cnt_host                <= 0;
                end else begin
                    burst_cnt_host                <= burst_cnt_host + 1;
                end
            end else begin
                burst_cnt_host                    <= 0;
            end
        end
    end : FIFOPUSH
    /////////////////////////////////////////////////////////////


endmodule
