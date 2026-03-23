`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////
//      AddressTranslationUnit (ATU)                                                                                                                                        
//
//      1) Translates AXI physical address into structured DRAM address fields          
//           (CH / RK / BG / BK / ROW / COL)                                            
//                                                                                      
//      2) Generates arbitration metadata for selecting a target FSM                    
//                                                                                      
//      FSM Mapping Policy:                                                             
//          - One FSM is allocated per (Channel, Rank) pair                             
//          - targetFSMIndex = {channel, rank}                                          
//          - Bank-level parallelism is handled inside each FSM                         
//                                                                                      
//      Current Address Translation Scheme:                                             
//          - Fixed address mapping (CH/RK/BG/BK/ROW/COL)                               
//          - XOR-based or hashed address translation can be added (TODO)               
// 
//      Author  : Seongwon Jo
//      Created : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//      AddressTranslationUnit (ATU)
//
//      1) AXI 물리 주소를 구조화된 DRAM 주소 필드로 변환
//           (채널 / 랭크 / 뱅크그룹 / 뱅크 / 로우 / 컬럼)
//
//      2) 대상 FSM을 선택하기 위한 중재용 메타데이터 생성
//
//      FSM 매핑 정책(FSM Mapping Policy):
//          - (Channel, Rank) 쌍마다 하나의 FSM을 할당
//          - targetFSMIndex = {channel, rank}
//          - 뱅크 단위 병렬성은 각 FSM 내부에서 처리
//
//      현재 주소 변환 방식(Current Address Translation Scheme):
//          - 고정 주소 매핑 사용 (CH / RK / BG / BK / ROW / COL)
//          - XOR 기반 또는 해시 기반 주소 변환은 향후 추가 가능 (TODO)
//
//      작성자  : 조성원
//      작성일  : 2026.02
//////////////////////////////////////////////////////////////////////////////////////////

module AddressTranslationUnit #( 
    parameter int MEM_ADDRWIDTH              = 32,
    parameter int AXI_ADDRWIDTH              = 32,
    parameter int NUM_RANKEXECUTION_UNIT     = 8,
    parameter int NUM_RANKEXECUTION_UNIT_BIT = $clog2(NUM_RANKEXECUTION_UNIT),
    parameter int CHWIDTH                    = 1,
    parameter int RKWIDTH                    = 2,
    parameter type MemoryAddress             = logic
) (
    input logic [AXI_ADDRWIDTH - 1 : 0] readAddr, 
    input logic [AXI_ADDRWIDTH - 1 : 0] writeAddr, 
    input logic [NUM_RANKEXECUTION_UNIT - 1 : 0] readReady,
    input logic readValid,
    input logic [NUM_RANKEXECUTION_UNIT - 1 : 0] writeReady,
    input logic writeValid,

    output logic [NUM_RANKEXECUTION_UNIT - 1 : 0] targetFSMVector, 
    output logic [NUM_RANKEXECUTION_UNIT_BIT - 1 : 0] targetFSMIndex,
    output MemoryAddress requestMemAddr
);

    localparam FSM_WIDTH = CHWIDTH + RKWIDTH;   // Number of Total FSM.
    // FSM resides on Per

    always_comb begin
        targetFSMVector = '0;
        targetFSMIndex  = '0;
        requestMemAddr  = '0;
        if (readValid) begin
            {requestMemAddr.channel, requestMemAddr.rank, requestMemAddr.bankgroup, requestMemAddr.bank,
             requestMemAddr.row, requestMemAddr.col} = readAddr;
             if (readReady[{requestMemAddr.channel ,requestMemAddr.rank}]) begin
                targetFSMIndex = readAddr[MEM_ADDRWIDTH-1 -: FSM_WIDTH];
                targetFSMVector[targetFSMIndex] = 1'b1;
             end 
        end else if (writeValid) begin
            {requestMemAddr.channel, requestMemAddr.rank, requestMemAddr.bankgroup, requestMemAddr.bank,
             requestMemAddr.row, requestMemAddr.col} = writeAddr;
             if (writeReady[{requestMemAddr.channel ,requestMemAddr.rank}]) begin
                targetFSMIndex = writeAddr[MEM_ADDRWIDTH-1 -: FSM_WIDTH];
                targetFSMVector[targetFSMIndex] = 1'b1;
             end
        end
    end

endmodule
