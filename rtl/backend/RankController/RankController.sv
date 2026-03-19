`timescale 1ns / 1ps

//------------------------------------------------------------------------------
//      RankController
//
//      Role:
//          Rank-level control block inside the Memory Controller Backend.
//          Coordinates request scheduling, DRAM command generation, and
//          buffer-level handshaking for a single DRAM rank.
//
//      Position in Architecture:
//
//          MemoryController Backend
//                      |
//                      V
//        +---------------------------+
//        |     RankController        |
//        |  (per Channel, per Rank) |
//        +---------------------------+
//                      |
//                      V
//        +-------------------------------------+
//        |   RankSched  |  RankExecutionUnit   |
//        |              | (BankFSMs)           |
//        +-------------------------------------+
//                      |
//                      V
//               DDR IF CMD BUS
//
//      High-level Responsibilities:
//          1) Accept read/write requests from MC Frontend.
//          2) Queue, age, and arbitrate rank-level memory requests.
//          3) Coordinate with Channel Scheduler for CMD / DQ grants.
//          4) Manage rank-level DRAM timing constraints.
//          5) Issue DRAM commands (ACT / RD / WR / PRE / REF).
//          6) Coordinate Auto-Precharge with data-buffer completion.
//          7) Interface with Read/Write Data Buffers.
//
//      Internal Structure:
//          - RankSched:
//              * Request queueing and arbitration.
//              * Open-page awareness and aging-based prioritization.
//              * Decides which request should be issued next.
//          - RankExecutionUnit:
//              * Enforces DRAM timing constraints (tRCD, tRP, tWR, tRFC).
//              * Generates DDR command/address signals.
//              * Tracks row/bank state and refresh state.
//
//      Request Flow:
//          Frontend -> RankController -> RankSched -> RankExecutionUnit -> DRAM
//
//      Buffer Interaction:
//          - Read/Write buffers are decoupled via explicit ACK signals.
//          - RankExecutionUnit issues buffer-level ACKs when command is accepted.
//          - Auto-Precharge completion is synchronized with buffer ACKs.
//
//      Scheduling Assumptions:
//          - Channel Scheduler grants CMD / CMDDQ opportunities.
//          - RankController does not perform channel-level arbitration.
//          - Only one request is issued per cycle per rank.
//
//      Timing Model:
//          - Cycle-accurate DRAM timing abstraction.
//          - Electrical and PHY timing are handled outside (PHYController).
//
//      What this module DOES:
//          - Rank-level request coordination.
//          - Timing-aware command issuance.
//          - Buffer and scheduler synchronization.
//
//      What this module DOES NOT do:
//          - PHY-level DQ/DQS generation.
//          - Channel-level arbitration across ranks.
//          - Global memory reordering.
//
//      Design Notes:
//          - This module is performance-critical and timing-sensitive.
//          - Split between RankSched and RankExecutionUnit improves clarity and reuse.
//          - Intended to scale with NUMBANK / NUMBANKGROUP parameters.
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////
//      RankController
//
//      역할(Role):
//          메모리 컨트롤러 백엔드 내부의
//          랭크(rank) 레벨 제어 블록.
//          단일 DRAM 랭크에 대해 요청 스케줄링,
//          DRAM 명령 생성,
//          버퍼 레벨 핸드셰이킹을 조율함.
//
//      아키텍처 내 위치(Position in Architecture):
//
//          MemoryController Backend
//                      |
//                      V
//        +---------------------------+
//        |     RankController        |
//        |  (채널별, 랭크별 1개)     |
//        +---------------------------+
//                      |
//                      V
//        +-------------------------------------+
//        |   RankSched  |  RankExecutionUnit   |
//        |              | (Bank FSM들)         |
//        +-------------------------------------+
//                      |
//                      V
//               DDR IF CMD BUS
//
//      상위 수준 책임(High-level Responsibilities):
//          1) MC Frontend로부터
//             읽기/쓰기 요청을 수신.
//          2) 랭크 레벨 메모리 요청을
//             큐잉하고, aging을 적용하여 중재.
//          3) CMD / DQ grant를 위해
//             Channel Scheduler와 협조.
//          4) 랭크 레벨 DRAM 타이밍 제약을 관리.
//          5) DRAM 명령 발행
//             (ACT / RD / WR / PRE / REF).
//          6) Auto-Precharge와
//             데이터 버퍼 완료 시점을 조율.
//          7) Read/Write 데이터 버퍼와 인터페이스.
//
//      내부 구조(Internal Structure):
//          - RankSched:
//              * 요청 큐 관리 및 중재.
//              * Open-page 상태 인지 및
//                aging 기반 우선순위 결정.
//              * 다음에 발행할 요청을 결정.
//          - RankExecutionUnit:
//              * DRAM 타이밍 제약 강제
//                (tRCD, tRP, tWR, tRFC).
//              * DDR 명령/주소 신호 생성.
//              * Row/Bank 상태와 Refresh 상태 추적.
//
//      요청 흐름(Request Flow):
//          Frontend → RankController → RankSched
//                   → RankExecutionUnit → DRAM
//
//      버퍼 연동(Buffer Interaction):
//          - Read/Write 버퍼는
//            명시적인 ACK 신호로 분리됨.
//          - RankExecutionUnit은
//            명령이 수락되었을 때
//            버퍼 레벨 ACK를 발행.
//          - Auto-Precharge 완료는
//            버퍼 ACK와 동기화됨.
//
//      스케줄링 가정(Scheduling Assumptions):
//          - Channel Scheduler가
//            CMD / CMDDQ 기회를 부여.
//          - RankController는
//            채널 레벨 중재를 수행하지 않음.
//          - 랭크당 사이클당 하나의 요청만 발행.
//
//      타이밍 모델(Timing Model):
//          - 사이클 정확(cycle-accurate) DRAM 타이밍 추상화.
//          - 전기적/PHY 타이밍은
//            외부(PHYController)에서 처리.
//
//      이 모듈이 하는 것(What this module DOES):
//          - 랭크 레벨 요청 조율.
//          - 타이밍 인지 명령 발행.
//          - 버퍼와 스케줄러 동기화.
//
//      이 모듈이 하지 않는 것(What this module DOES NOT do):
//          - PHY 레벨 DQ/DQS 생성.
//          - 랭크 간 채널 레벨 중재.
//          - 전역 메모리 재정렬.
//
//      설계 참고 사항(Design Notes):
//          - 성능에 매우 중요한,
//            타이밍 민감한 모듈.
//          - RankSched와 RankExecutionUnit 분리는
//            가독성과 재사용성을 향상.
//          - NUMBANK / NUMBANKGROUP 파라미터에 따라
//            확장 가능하도록 설계됨.
//
//      작성자  : 조성원
//      작성일  : 2026.02
//------------------------------------------------------------------------------

module RankController #(
    parameter int FSM_CHANNEL        = 0,
    parameter int FSM_RANK           = 0,
    parameter int NUM_BANKFSM        = 0,
    parameter int NUM_BANKFSM_BIT    = 0,
    
    parameter int MEM_IDWIDTH        = 4,
    parameter int MEM_USERWIDTH      = 1,
    parameter int READCMDQUEUEDEPTH  = 8,
    parameter int WRITECMDQUEUEDEPTH = 8,
    parameter int OPENPAGELISTDEPTH  = 16,
    parameter int AGINGWIDTH         = 10,
    parameter int COMMAND_WIDTH      = 18,
    parameter int BKWIDTH            = 2,
    parameter int BGWIDTH            = 2,
    parameter int RWIDTH             = 15,
    parameter int CWIDTH             = 10,
    parameter int THRESHOLD          = 512,
    parameter int NUMBANK            = 4,
    parameter int NUMBANKGROUP       = 4,
    parameter int tRP                = 16,
    parameter int tWR                = 18,
    parameter int tRFC               = 256,
    parameter int tREFI              = 8192,
    parameter int tRCD               = 16,

    parameter type MemoryAddress = logic,
    parameter type FSMRequest = logic
)(
    input logic clk, rst,
    
    /* Input from MC FrontEnd */
    input MemoryAddress RankReqMemAddr,                                            
    input logic [MEM_IDWIDTH   - 1 : 0] RankReqId,                                 
    input logic [MEM_USERWIDTH - 1 : 0] RankReqUser,                             
    input logic RankReqType,
    input logic RankReqValid,
    
    /* Output to MC FrontEnd */                                       
    output logic RankReadReqReady, 
    output logic RankWriteReqReady,

    /* Input from Channel Scheduler */
    input logic chSchedCMDGranted,
    input logic chSchedDQGranted,
    input logic chSchedWriteMode, // Channel Mode signal for Read / Write request

    /* Output to Channel Scheduler */
    output logic chSchedRdReady, // Read Ready signal, Valid when there is any Read request in Request Que.
    output logic chSchedWrReady, // Write Ready signal, Valid when there is any Write request in Request Que.
    output logic chSchedRdWrACK, // RD/WR ACK signal for Read/Write request, ACK when FSM issues Read/Write CMD.
    output logic chSchedCMDACK,  // CMD ACK signal for any CMD, ACK when FSM issues any kind of CMD.
    output logic chSchedFSMWait, // FSMWait signal, Valid when FSM waits for row timing constraints. (e.g., tRP, tRCD, tRFC)
    output logic chSchedCCDType, // CAS-to-CAS timing type, 1 for tCCD_Short , 0 for tCCD_Long
    output logic [$clog2(READCMDQUEUEDEPTH)  - 1 : 0] ReadReqCnt,  // Num. of read Requests in Request Que.
    output logic [$clog2(WRITECMDQUEUEDEPTH) - 1 : 0] WriteReqCnt, // Num. of write Requests in Request Que.
    output wire  chSchedRankIdle,
    input  wire  chSchedTransReady,

    /* Input from MEM Buffer */
    input rdBufAvailable,                           // Valid when there is any empty entry in read buffer
    input logic rdBufRankAvailable,
    input wrBufAvailable,                                       // Valid when there is any empty entry in write buffer
    input logic bufReadPreACK,                                  // Valid when Read data (last) is received.
    input logic bufWritePreACK,                                 // Valid when Write data (last) is sent.
    input logic [BKWIDTH + BGWIDTH - 1 : 0] bufBankPre,         // AutoPrecharge-related BankGroup, Bank Information to FSM.

                                                                //        Output to MEM Buffer        //
    output logic [MEM_IDWIDTH-1:0] bufReadReqId,                // When RankExecutionUnit sends RD Req., it sends Req. ID to RD MEM Buffer for ready to receive.
    output logic [MEM_IDWIDTH-1:0] bufWriteReqId,               // When RankExecutionUnit sends WR Req., it sends Req. ID to WR MEM Buffer for ready to send.
    output logic [MEM_USERWIDTH-1:0] bufReadReqUser,            // When RankExecutionUnit sends RD Req., it sends Req. User to RD MEM Buffer for ready to receive.
    output logic [MEM_USERWIDTH-1:0] bufWriteReqUser,           // When RankExecutionUnit sends WR Req., it sends Req. User to WR MEM Buffer for ready to send.
    output logic bufReadReqACK,                                 // When RankExecutionUnit sends RD Req., it sends Req. valid to RD MEM Buffer for ready to receive.
    output logic bufWriteReqACK,                                // When RankExecutionUnit sends WR Req., it sends Req. valid to WR MEM Buffer for ready to send.    
    output MemoryAddress bufReqACKAddr,                         // When RankExecutionUnit sends RD/WR Req., it sends Req. Addr. to RD/WR Mem Buffer.


    output logic issuable,

    // Memory channel, PHY - side 
    output logic cke, cs_n, par, act_n,
    output logic [COMMAND_WIDTH-1:0] pin_A,
    output logic [BGWIDTH-1:0] bg,
    output logic [BKWIDTH-1:0] b
    );
    
    //----------- Internal Wires for RankSched <-> RankExecutionUnit --------------//
    logic [NUM_BANKFSM-1:0] fsmWait;
    wire  [NUM_BANKFSM-1:0] fsmIdle;
    logic [NUM_BANKFSM-1:0] fsmIssue;

    logic fsmRefreshACK, fsmChSchedAck;
    logic [MEM_IDWIDTH-1 :0] fsmBufWrReqId, fsmBufRdReqId;
    logic [MEM_USERWIDTH-1:0] fsmBufWrReqUser, fsmBufRdReqUser;
    logic fsmBufWrReqIssued, fsmBufRdReqIssued;

    logic fsmWrBufValid, fsmRdBufValid;
    logic refresh, chSchedAvailableCMD, chSchedAvailableCMDDQ;
    FSMRequest fsmIssuedReq;

    RankSched #(
        .FSM_CHANNEL(FSM_CHANNEL),
        .FSM_RANK(FSM_RANK),
        .MEM_IDWIDTH(MEM_IDWIDTH),
        .MEM_USERWIDTH(MEM_USERWIDTH),
        .READCMDQUEUEDEPTH(READCMDQUEUEDEPTH),
        .WRITECMDQUEUEDEPTH(WRITECMDQUEUEDEPTH),
        .OPENPAGELISTDEPTH(OPENPAGELISTDEPTH),
        .AGINGWIDTH(AGINGWIDTH),
        .THRESHOLD(THRESHOLD),
        .NUM_BANKFSM(NUM_BANKFSM),
        .NUM_BANKFSM_BIT(NUM_BANKFSM_BIT),
        .tREFI(tREFI),
        .RWIDTH(RWIDTH),
        .CWIDTH(CWIDTH),
        .FSMRequest(FSMRequest),
        .MemoryAddress(MemoryAddress)
    ) RankScheduler(
        .clk(clk), .rst(rst),

        .RankReqMemAddr(RankReqMemAddr), .RankReqId(RankReqId), .RankReqUser(RankReqUser),
        .RankReqType(RankReqType), .RankReqValid(RankReqValid), .RankReadReqReady(RankReadReqReady),
        .RankWriteReqReady(RankWriteReqReady),

        .chSchedCMDOnlyValid(chSchedCMDGranted), .chSchedCMDDQValid(chSchedDQGranted),
        .WriteMode(chSchedWriteMode),
        .chSchedRdReady(chSchedRdReady), .chSchedWrReady(chSchedWrReady), .chSchedACK(chSchedRdWrACK), .chSchedIdle(chSchedFSMWait),
        .chSchedReadReqCnt(ReadReqCnt), .chSchedWriteReqCnt(WriteReqCnt),

        .rdBufAvailable(rdBufAvailable), .wrBufAvailable(wrBufAvailable),

        .readBufReqId(bufReadReqId), .readBufReqUser(bufReadReqUser), .readBufReqACK(bufReadReqACK),
        .writeBufReqId(bufWriteReqId), .writeBufReqUser(bufWriteReqUser), .writeBufReqACK(bufWriteReqACK),

        .fsmIdle(fsmIdle), .fsmWait(fsmWait),  .chSchedTransReady(chSchedTransReady),
        .fsmRefreshAck(fsmRefreshACK), .fsmChSchedAck(fsmChSchedAck),

        .fsmBufWrReqId(fsmBufWrReqId), .fsmBufWrReqUser(fsmBufWrReqUser), .fsmBufRdReqId(fsmBufRdReqId), .fsmBufRdReqUser(fsmBufRdReqUser), 
        .fsmBufWrReqIssued(fsmBufWrReqIssued), .fsmBufRdReqIssued(fsmBufRdReqIssued),

        .fsmWrBufValid(fsmWrBufValid), .fsmRdBufValid(fsmRdBufValid),
        .fsmIssue(fsmIssue), .fsmIssuedReq(fsmIssuedReq), .issuable(issuable),
        
        .refresh(refresh), .chSchedAvailableCMD(chSchedAvailableCMD), .chSchedAvailableCMDDQ(chSchedAvailableCMDDQ)
    );

    RankExecutionUnit #(
        .FSM_CHANNEL(FSM_CHANNEL),
        .FSM_RANK(FSM_RANK),
        .MEM_IDWIDTH(MEM_IDWIDTH),
        .MEM_USERWIDTH(MEM_USERWIDTH),
        .BKWIDTH(BKWIDTH),
        .BGWIDTH(BGWIDTH),
        .RWIDTH(RWIDTH),
        .CWIDTH(CWIDTH),
        .NUMBANK(NUMBANK),
        .NUM_BANKFSM(NUM_BANKFSM),
        .NUM_BANKFSM_BIT(NUM_BANKFSM_BIT),        
        .NUMBANKGROUP(NUMBANKGROUP),
        .COMMAND_WIDTH(COMMAND_WIDTH),
        .tRP(tRP),
        .tWR(tWR),
        .tRFC(tRFC),
        .tRCD(tRCD),
        .FSMRequest(FSMRequest),
        .MemoryAddress(MemoryAddress)
    ) RankExecutionUnit_Instance(
        .clk(clk), .rst(rst), .chMode(chSchedWriteMode),
        
        .ReadPreAck(bufReadPreACK), .WritePreAck(bufWritePreACK),
        .rbuf_available(fsmRdBufValid), .rbufWindowAvailable(rdBufRankAvailable),
        .bufBankPre(bufBankPre), .wbuf_available(fsmWrBufValid), 

        .bufWriteReqIssued(fsmBufWrReqIssued), .bufWriteReqId(fsmBufWrReqId), .bufWriteReqUser(fsmBufWrReqUser),
        .bufReadReqIssued(fsmBufRdReqIssued), .bufReadReqId(fsmBufRdReqId) , .bufReadReqUser(fsmBufRdReqUser),

        .schedReq(fsmIssuedReq), .schedValid(fsmIssue), .refresh(refresh), 
        .schedIdle(fsmIdle), .schedRefACK(fsmRefreshACK),

        .chCMDAvailable(chSchedAvailableCMD), .chCMDDQAvailable(chSchedAvailableCMDDQ),
        .fsmWait(fsmWait), .chSchedRdWrACK(fsmChSchedAck), .chSchedCMDACK(chSchedCMDACK),
        .CCDShort(chSchedCCDType),

        .bufReqACKAddr(bufReqACKAddr),
        .cke(cke), .cs_n(cs_n), .par(par), .act_n(act_n),
        .pin_A(pin_A), .bg(bg), .b(b)
    );

    assign chSchedRankIdle = &fsmIdle;

endmodule
