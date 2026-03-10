`timescale 1ns / 1ps

//------------------------------------------------------------------------------
//  MemoryBFM (Top-Level DDR4 Memory Bus Functional Model)
//
//  ROLE:
//      Top-level DDR4 memory BFM that instantiates multiple independent
//      memory channels.
//
//  RESPONSIBILITIES:
//      - Act as the top abstraction of DRAM in the simulation environment.
//      - Contain per-channel DDR4 memory models (MemoryChannel).
//      - Provide a clean integration point for multi-channel ddr memory systems.
//      - Bridge external DDR4 interfaces to internal channel-level BFMs.
//
//  MODELING SCOPE:
//      - Channel-level structural composition only.
//      - No timing, scheduling, or protocol logic is implemented here (Timing, Scheduling are considered in Memory Controller-side).
//      - All DRAM protocol behavior is encapsulated inside MemoryChannel
//        and lower-level Bank/Rank BFMs.
//
//          Ch0 DDR4 IF CMD / DQ BUS   Ch1 DDR4 IF CMD / DQ BUS
//                    |   ∧                    |    ∧   
//                    V   |                    V    |
//           +-------------------------------------------+
//           |          MemoryBFM   (This module)        |
//           +-------------------------------------------+
//                  |                           |
//                  |                           |
//                  |                           |       
//              MemoryChannel_0          MemoryChannel_1
//
//  ASSUMPTIONS:
//      - Each channel operates independently (no cross-channel timing).
//      - DDR4Interface encapsulates CA/DQ signal groups per channel.
//      - The number of channels instantiated here reflects the system
//        configuration under test.
//
//  NOTES:
//      - This module is intended purely for verification and architectural
//        evaluation.
//      - Not synthesizable. (but it passes lint)
//      - Scaling to more channels only requires adding MemoryChannel instances.
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------  
//  MemoryBFM (최상위 DDR4 메모리 Bus Functional Model)  
//  
//  역할(ROLE):  
//      여러 개의 독립적인 메모리 채널을 인스턴스화하는  
//      최상위 DDR4 메모리 BFM이다.  
//  
//  책임(RESPONSIBILITIES):  
//      - 시뮬레이션 환경에서 DRAM의 최상위 추상 모델로 동작한다.  
//      - 채널별 DDR4 메모리 모델(MemoryChannel)을 포함한다.  
//      - 멀티 채널 DDR 메모리 시스템을 위한 깔끔한 통합 지점을 제공한다.  
//      - 외부 DDR4 인터페이스를 내부 채널 레벨 BFM에 연결하는 브리지 역할을 한다.  
//  
//  모델링 범위(MODELING SCOPE):  
//      - 채널 레벨의 구조적 구성만 담당한다.  
//      - 타이밍, 스케줄링, 프로토콜 로직은 여기서 구현하지 않는다  
//        (타이밍 및 스케줄링은 Memory Controller 측에서 고려된다).  
//      - 모든 DRAM 프로토콜 동작은 MemoryChannel과  
//        하위 Bank/Rank BFM 내부에 캡슐화되어 있다.  
//  
//          Ch0 DDR4 IF CMD / DQ BUS   Ch1 DDR4 IF CMD / DQ BUS  
//                    |   ∧                    |    ∧     
//                    V   |                    V    |  
//           +-------------------------------------------+  
//           |          MemoryBFM   (이 모듈)             |  
//           +-------------------------------------------+  
//                  |                           |  
//                  |                           |  
//                  |                           |         
//              MemoryChannel_0          MemoryChannel_1  
//  
//  가정(ASSUMPTIONS):  
//      - 각 채널은 서로 독립적으로 동작한다 (채널 간 타이밍 의존성 없음).  
//      - DDR4Interface는 채널별 CA/DQ 신호 그룹을 캡슐화한다.  
//      - 여기에서 인스턴스화되는 채널 수는 테스트 대상 시스템의  
//        구성(configuration)을 반영한다.  
//  
//  참고 사항(NOTES):  
//      - 이 모듈은 순수하게 검증 및 아키텍처 평가 목적을 위해 사용된다.  
//      - 합성(synthesis) 대상이 아니다. (하지만 lint 검사는 통과한다)  
//      - 더 많은 채널로 확장하려면 MemoryChannel 인스턴스를  
//        추가하면 된다.  
//  
//      Author  : Seongwon Jo  
//      Created : 2026.02  
//------------------------------------------------------------------------------

module MemoryBFM#(
    parameter int NUMCHANNEL    = 2,
    parameter int NUMRANK       = 4,
    parameter int IOWIDTH       = 8,
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
    parameter int tRP           = 16,
    parameter int tRFC          = 256
)(
    input logic clk, rst_n, clk2x,
    DDR4Interface DDR4_CH0_IF,
    DDR4Interface DDR4_CH1_IF
);

    //-------------------------------------------------------------------------
    //  Channel 0 Memory BFM
    //
    //  - Models one independent DDR4 memory channel.
    //  - Internally instantiates rank- and bank-level BFMs.
    //  - Handles command decoding, timing enforcement, and data bursts.
    //-------------------------------------------------------------------------
    MemoryChannel #(
        .CHANNELID(0),
        .NUMRANK(NUMRANK),
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
    ) MemoryChannel_Ch0(
        .clk(clk), .rst_n(rst_n), .clk2x(clk2x),
        .ddr4_cmdaddr_if(DDR4_CH0_IF.Memory_CA),
        .ddr4_dq_if(DDR4_CH0_IF.Memory_DQ)
    );

    //-------------------------------------------------------------------------
    //  Channel 1 Memory BFM
    //
    //  - Identical to Channel 0, but fully independent.
    //  - Enables multi-channel memory behavior in simulation.
    //-------------------------------------------------------------------------
    MemoryChannel #(
        .CHANNELID(1),
        .NUMRANK(NUMRANK),
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
    ) MemoryChannel_Ch1(
        .clk(clk), .rst_n(rst_n), .clk2x(clk2x),
        .ddr4_cmdaddr_if(DDR4_CH1_IF.Memory_CA),
        .ddr4_dq_if(DDR4_CH1_IF.Memory_DQ)
    );

endmodule
