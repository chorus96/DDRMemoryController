`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////////////////////
//
//      MemoryControllerFrontend
//
//      Role:
//          Frontend of the Memory Controller.
//          Bridges a simplified AXI-like cache interface and the internal
//               Memory Controller request/response protocol.
//
//      Architectural Overview:
//
//            L2 Cache / NoC (AXI-like)
//                |          ∧    
//                V          |
//          +----------------------------+
//          |  MemoryControllerFrontend  |
//          |        (This module)       |
//          +----------------------------+
//                |          ∧
//                V          |
//          MemoryController (Channel-level Backend)
//
//      Responsibilities:
//          1) Accept cache-side read/write requests using ready/valid semantics.
//          2) Perform write burst assembly by matching AW and W channels
//                  using (ID, USER) pairs.
//          3) Translate physical addresses into internal memory addresses
//             (CH/RK/BG/BK/ROW/COL).
//          4) Perform deterministic request arbitration:
//              - Read-first policy
//              - Write-preemption when a full write burst is assembled.
//          5) Generate internal MC requests toward rank/channel FSMs.
//          6) Forward read/write responses back to cache-side interface.
//
//      Arbitration Policy:
//          - Read-first scheduling by default.
//          - Write requests are issued only when a complete write burst
//            (ADDR + DATA) is assembled.
//          - No simultaneous read/write request issuance.
//
//      Address Translation:
//          - Fixed-index address mapping:
//                Channel | Rank | BankGroup | Bank | Row | Column
//                  (Address mapping can be extend for Hash(XOR)-based (TODO))
//          - Translation is applied only on request path.
//
//      Design Notes:
//          - This module is protocol-focused and timing-agnostic.
//          - No DRAM timing constraints are enforced here.
//          - All DDR timing and scheduling are delegated to Backend logic.
//          - Simplified AXI semantics are assumed (no reordering, no interleaving).
//
//      Author  : Seongwon Jo
//      Created : 2026.02
//
//////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////
//
//      MemoryControllerFrontend
//
//      역할(Role):
//          메모리 컨트롤러의 프론트엔드.
//          단순화된 AXI 유사 캐시 인터페이스와
//          내부 메모리 컨트롤러 요청/응답 프로토콜을 연결하는 브리지 역할을 수행함.
//
//      아키텍처 개요(Architectural Overview):
//
//            L2 Cache / NoC (AXI-like)
//                |          ∧    
//                V          |
//          +----------------------------+
//          |  MemoryControllerFrontend  |
//          |        (본 모듈)            |
//          +----------------------------+
//                |          ∧
//                V          |
//          MemoryController (채널 레벨 백엔드)
//
//      주요 책임(Responsibilities):
//          1) ready/valid 시맨틱을 사용하여 캐시 측의
//             읽기/쓰기 요청을 수신.
//          2) (ID, USER) 쌍을 기준으로
//             AW 채널과 W 채널을 매칭하여 쓰기 버스트를 조립.
//          3) 물리 주소를 내부 메모리 주소 형식
//             (채널/랭크/뱅크그룹/뱅크/로우/컬럼)으로 변환.
//          4) 결정적 요청 중재(Arbitration) 수행:
//              - 기본 정책은 Read 우선
//              - 전체 쓰기 버스트가 조립되면 Write가 선점 가능
//          5) 내부 MC 요청을 생성하여
//             랭크/채널 FSM으로 전달.
//          6) 읽기/쓰기 응답을 캐시 인터페이스로 다시 전달.
//
//      중재 정책(Arbitration Policy):
//          - 기본적으로 Read 우선 스케줄링.
//          - Write 요청은 주소와 데이터가 모두 준비된
//            완전한 쓰기 버스트일 때만 발행.
//          - Read와 Write 요청은 동시에 발행되지 않음.
//
//      주소 변환(Address Translation):
//          - 고정 인덱스 기반 주소 매핑 사용:
//                Channel | Rank | BankGroup | Bank | Row | Column
//          - (향후 Hash(XOR) 기반 매핑으로 확장 가능 – TODO)
//          - 주소 변환은 요청 경로에서만 적용됨.
//
//      설계 참고 사항(Design Notes):
//          - 이 모듈은 프로토콜 중심이며 타이밍 비의존적임.
//          - DRAM 타이밍 제약은 이 모듈에서 처리하지 않음.
//          - 모든 DDR 타이밍 및 스케줄링은 백엔드 로직에 위임됨.
//          - 단순화된 AXI 시맨틱을 가정함
//            (재정렬 없음, 인터리빙 없음).
//
//      작성자  : 조성원
//      작성일  : 2026.02
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import MemoryController_Definitions::mc_side_response;

module MemoryControllerFrontend#(
        parameter int AXI_ADDRWIDTH              = 32,
        parameter int AXI_USERWIDTH              = 1,
        parameter int AXI_IDWIDTH                = 4,
        parameter int AXI_DATAWIDTH              = 64,

        parameter int MEM_ADDRWIDTH              = 32,
        parameter int CHWIDTH                    = 1,
        parameter int RKWIDTH                    = 2,
        parameter int NUM_RANKEXECUTION_UNIT     = 8,
        parameter int NUM_RANKEXECUTION_UNIT_BIT = $clog2(NUM_RANKEXECUTION_UNIT),
        parameter int BURST_LENGTH               = 8,
        parameter int ASSEMBLER_DEPTH            = 8,
        parameter int NUMRANK                    = 4,
        parameter int READBUFFERDEPTH            = 128,
        parameter int WRITEBUFFERDEPTH           = 128,
        parameter int RESPSCHEDULINGCNT          = 4,

        parameter type WrAddrEntry               = logic,
        parameter type CacheResp                 = logic,
        parameter type CacheReq                  = logic,
        parameter type MCResp                    = logic,
        parameter type MCReq                     = logic,
        parameter type axi_aw_chan_t             = logic,
        parameter type MemoryAddress             = logic
    )

   (
        input logic clk, 
        input logic rst_n,
                                                            //////////////////////////////////////////////
                                                            //         INPUT  FROM  Cache/MC-side       //
        input CacheReq noc_req,                             //  1. Cache-side Request (Cache-side)      //
        input mc_side_response ch0_MCResp, ch1_MCResp,

        input logic [$clog2(READBUFFERDEPTH)-1:0] Ch0_NumOfReadBufferEntry, Ch1_NumOfReadBufferEntry,
        output logic MCRespStateBackend,
        input logic Ch1_ReadBufferFull, Ch1_WriteBufferFull,
        input logic Ch0_ReadBufferFull, Ch0_WriteBufferFull,
        input logic [NUMRANK-1:0] Ch0_RankFSMRdReady, Ch1_RankFSMRdReady,
        input logic [NUMRANK-1:0] Ch0_RankFSMWrReady, Ch1_RankFSMWrReady,
                                                            //////////////////////////////////////////////
                                                            //         OUTPUT  TO Cache/MC-side         //
        output CacheResp noc_resp,                          //  1. Cache-side Response (Cache-side)     //
        output  MCReq mc_req                                //  2. MC-side  Request (MC-side)           //
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  I assume that the cache request/response interface is based on a simplified AXI protocol, including       //
    //  ready/valid handshaking and only the necessary signals: data, last, strobe (strb), address, user, and ID. //
    //  1) AXI - Address Read Channel                                                                             //
    //      - Ready     (Signal from MC-side)     ->  MC Resp, Cache Resp                                         //
    //      - Valid     (Singal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - Address   (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - User & ID (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //  2) AXI - Read Channel                                                                                     //
    //      - Ready     (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - Valid     (Signal from MC-side)     ->  MC Resp, Cache Resp                                         //
    //      - Data      (Signal from MC-side)     ->  MC Resp, Cache Resp                                         //
    //      - LAST      (Signal from MC-side)     ->  MC Resp, Cache Resp                                         //
    //      - User & ID (Signal from MC-side)     ->  MC Resp, Cache Resp                                         //
    //  3) AXI - Address Write Channel                                                                            //
    //      - Ready     (Signal from MC-side)     ->  MC Resp, Cache Resp                                         //
    //      - Valid     (Singal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - Address   (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - User & ID (Singal from Cache-sdie)  ->  MC Req,  Cache Req                                          //
    //  4) AXI - Write Channel                                                                                    //
    //      - Ready     (Signal from MC-side)     ->  MC Resp, Caache Resp                                        //
    //      - Valid     (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - Data      (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - LAST      (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - Strb      (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - User & ID (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //  5) AXI- Write Response Channel                                                                            //
    //      - Ready     (Signal from Cache-side)  ->  MC Req,  Cache Req                                          //
    //      - Valid     (Siganl from MC-side)     ->  MC Resp, Cache Resp                                         //
    //      - User & ID (Signal from MC-side)     ->  MC Resp, Cache Resp                                         //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    localparam WR_BEAT_WIDTH = AXI_DATAWIDTH + AXI_DATAWIDTH/BURST_LENGTH;      // WR_BEAT_WIDTH = 64-bit (DATA) + 8-bit (Byte Strobe)
    localparam BURSTTIMING = BURST_LENGTH - 1;                              

    //              Write Assembler-Address Queue Entry Definition             //


    WrAddrEntry WrAddrQueue [0: ASSEMBLER_DEPTH - 1];

    //              Write Assembler-Data Queue Entry Definition             //
    logic [AXI_IDWIDTH + AXI_USERWIDTH + WR_BEAT_WIDTH * BURST_LENGTH - 1 : 0] WrDataQueue [0: ASSEMBLER_DEPTH-1]; 
    logic [ASSEMBLER_DEPTH - 1 : 0]  WrDataFree, WrAddrFree, WrPushPtrFree; 
    logic [ASSEMBLER_DEPTH - 1 : 0]  assemblyVector;  

    logic [$clog2(ASSEMBLER_DEPTH) - 1 :0] WrDataPushPtr, WrAddrPushPtr;

    logic WrDataQueueFull, WrAddrQueueFull;
    logic [$clog2(BURST_LENGTH) - 1:0]  WrPushCnt; 

    logic [$clog2(ASSEMBLER_DEPTH)-1:0] assembleWriteAddrIndex; 
    logic [$clog2(ASSEMBLER_DEPTH)-1:0] assembleWriteDataIndex;
    logic [$clog2(BURST_LENGTH) - 1:0] WrPopCnt; 

    //      Memory Controller Frontend reflects read-first priority          //
    logic arbitrationMode;

    // Internal signal  (MC_read Ready & MC_write Ready)
    logic  ReadRequestReceived;  // read ready signal from read buffer & queue
    logic  WriteAddrReceived, WriteDataReceived; // write ready signal from write buffer

    logic [NUM_RANKEXECUTION_UNIT-1:0] aggregate_ar_ready;
    logic [NUM_RANKEXECUTION_UNIT-1:0] aggregate_w_ready;
    logic [NUM_RANKEXECUTION_UNIT-1:0] aggregate_aw_ready;



   

    //------------------------------------------------------------------------------
    //      AddressTranslationUnit
    //
    //      - Translates AXI physical addresses into internal MemoryAddress format.
    //      - Decodes Channel / Rank / BankGroup / Bank / Row / Column fields.
    //      - Selects target Rank FSM(s) for incoming requests.
    //
    //  NOTE:
    //      - Translation is applied only on request path.
    //      - Current mapping uses fixed bit slicing.
    //------------------------------------------------------------------------------
    MemoryAddress translatedAddr;
    logic [NUM_RANKEXECUTION_UNIT-1:0] FSM_vector;
    logic [NUM_RANKEXECUTION_UNIT_BIT-1:0] FSM_index;

    AddressTranslationUnit #(   // Only for Request side
        .MEM_ADDRWIDTH(MEM_ADDRWIDTH),
        .AXI_ADDRWIDTH(AXI_ADDRWIDTH),
        .NUM_RANKEXECUTION_UNIT(NUM_RANKEXECUTION_UNIT),
        .CHWIDTH(CHWIDTH),
        .RKWIDTH(RKWIDTH),
        .MemoryAddress(MemoryAddress)
    ) AddressTranslationUnit_Instance(
        .readAddr(noc_req.ar.addr),
        .writeAddr(noc_req.aw.addr),
        .readReady(aggregate_ar_ready),
        .readValid(noc_req.ar_valid),
        .writeReady(aggregate_aw_ready),
        .writeValid(noc_req.aw_valid),
        .targetFSMVector(FSM_vector),
        .targetFSMIndex(FSM_index),
        .requestMemAddr(translatedAddr)
    );
    //-------------------------------------------------------------------//
    assign ReadRequestReceived  = noc_req.ar_valid    && noc_resp.ar_ready  && (FSM_vector[FSM_index]);   
    assign WriteDataReceived    = noc_req.w_valid     && noc_resp.w_ready;
    assign WriteAddrReceived    = noc_req.aw_valid    && noc_resp.aw_ready  && (FSM_vector[FSM_index]);
    assign arbitrationMode      = |assemblyVector;

    //----------------------- WR, WR_ADDR PTR - SETUP -----------------------//
    PriorityEncoder_LSB #(
        .vector_length(ASSEMBLER_DEPTH)
    ) WrDataQueuePushPtr(
        .vector(WrPushPtrFree),
        .index(WrDataPushPtr)
    );

    PriorityEncoder_LSB #(
        .vector_length(ASSEMBLER_DEPTH)
    ) WrAddrQueuePushPtr(
        .vector(WrAddrFree),
        .index(WrAddrPushPtr)
    );
    //-------------------------------------------------------------------//

    assign WrDataQueueFull = !(|WrDataFree);
    assign WrAddrQueueFull = !(|WrAddrFree);



    //     Assembly Vecotr Mangeemnt  && Write Data/Addr Qeueu Ptr Setup        //
    //  Assembly Vector Valid Condition :                                       //
    //    - Is there any same ID and User in Write Data and ADDR Queue??        //
    //   (TODO) : Solve Nested "for loop"                                       //
    //      Option 1. Utilize Fixed User and ID Bits. (Hash)                    //
    //          - WrAddrEntry[{User-bits, ID-bits}] = New_writeAddr, VALID bit  //


    //------------------------------------------------------------------------------
    //      Write Request Assembler (ADDR-DATA Matching)
    //
    //      - Matches AXI Write Address (AW) and Write Data (W) streams.
    //      - Uses (ID, USER) pair to associate address and burst data.
    //      - Generates assemblyVector when a full write burst is assembled.
    //
    //  NOTE:
    //      - Write requests are issued only when both ADDR and full DATA are ready.
    //      - Nested search is acceptable due to limited ASSEMBLER_DEPTH.
    //------------------------------------------------------------------------------
    always_comb begin
        assembleWriteAddrIndex  = '0;
        assembleWriteDataIndex  = '0;
        assemblyVector          = '0;
        for (int i = ASSEMBLER_DEPTH-1; i >= 0; i--) begin
            for(int j = ASSEMBLER_DEPTH-1; j >=0; j--) begin
                if (!WrDataFree[i] && !WrAddrFree[j] && 
                        (WrDataQueue[i][AXI_IDWIDTH + AXI_USERWIDTH + WR_BEAT_WIDTH * BURST_LENGTH - 1 : WR_BEAT_WIDTH * BURST_LENGTH]
                        == {WrAddrQueue[j].aw.id, WrAddrQueue[j].aw.user})) begin
                    assembleWriteDataIndex = i;
                    assembleWriteAddrIndex = j;
                    assemblyVector[i] = 1;    
                end
            end
        end
    end
    //-------------------------------------------------------------------//


    //------------------------------------------------------------------------------
    //      Write Address & Data Queue Management
    //
    //      - Buffers incoming AXI AW and W transactions independently.
    //      - Collects write data beats into burst-aligned entries.
    //      - Tracks free/occupied queue entries.
    //      - Releases entries once a write burst is issued to backend.
    //
    //  NOTE:
    //      - Partial write bursts are never forwarded.
    //      - Address and data queues are strictly decoupled.
    //------------------------------------------------------------------------------
    always_ff@(posedge clk or negedge rst_n) begin : WriteDataAddrQueueManagement
        if(!rst_n) begin  
            for(int i = 0; i< ASSEMBLER_DEPTH; i++)begin
                WrDataQueue[i] <= 0;
                WrAddrQueue[i] <= 0;
            end
            WrDataFree      <= '1;
            WrPushPtrFree   <= '1;
            WrAddrFree      <= '1;
            WrPushCnt <= 0;
        end else begin  
            //              Write address QUEUE Push                     //
            if(WriteAddrReceived) begin : WriteAddressQueuePUSH
                WrAddrQueue[WrAddrPushPtr].mem_addr <= translatedAddr;
                WrAddrQueue[WrAddrPushPtr].aw <= noc_req.aw;
                WrAddrQueue[WrAddrPushPtr].fsm <= FSM_vector;

                WrAddrFree[WrAddrPushPtr] <= 0;
                `ifdef DISPLAY
                    $display("[%0t] MemoryControllerFrontend | AXI-Write Addr Bus | Addr: %h | ID: %d | User: %d", $time,
                        noc_req.aw.addr, noc_req.aw.id, noc_req.aw.user);
                `endif
            end : WriteAddressQueuePUSH
            // write-data setup
            if(WriteDataReceived) begin :WriteDataQueuePUSH
                WrDataQueue[WrDataPushPtr][WrPushCnt * WR_BEAT_WIDTH +: WR_BEAT_WIDTH] <= {noc_req.w.strb, noc_req.w.data};
                `ifdef DISPLAY
                    $display("[%0t] MemoryControllerFrontend | AXI-Write Bus | Addr: %h | ID: %d | User: %d", $time,
                        noc_req.aw.addr, noc_req.aw.id, noc_req.aw.user);
                `endif
                if(WrPushCnt == 0 )begin
                    WrDataQueue[WrDataPushPtr][AXI_IDWIDTH+AXI_USERWIDTH+WR_BEAT_WIDTH * BURST_LENGTH - 1 : WR_BEAT_WIDTH* BURST_LENGTH] <= {noc_req.w.id, noc_req.w.user};
                end 
                if (WrPushCnt == BURSTTIMING)begin
                    WrDataFree[WrDataPushPtr] <= 0;
                    WrPushPtrFree[WrDataPushPtr] <= 0;
                end
                else if(arbitrationMode && WrPopCnt == BURSTTIMING) begin
                    WrPushPtrFree <= WrPushPtrFree;
                end

                if(WrPushCnt == BURSTTIMING) begin
                    WrPushCnt <= 0;
                end else begin
                    WrPushCnt <= WrPushCnt + 1;
                end
            end : WriteDataQueuePUSH
            // free setup 
            if(arbitrationMode && WrPopCnt == BURSTTIMING) begin :WriteAddressDataQueuePOP
                WrAddrFree[assembleWriteAddrIndex] <= 1;
                WrDataFree[assembleWriteDataIndex] <= 1;
                if(!WriteDataReceived) begin
                    WrPushPtrFree[assembleWriteDataIndex] <= 1;
                end 
                `ifdef DISPLAY
                    $display("[%0t] MemoryControllerFrontend | WRITE REQUEST SERVING | MEM_Addr: %d-%d-%d-%d-%d-%d (CH-RK-BG-BK-ROW-COL) | ID: %d | User: %d", 
                        $time, mc_req.mem_addr.channel, mc_req.mem_addr.rank, mc_req.mem_addr.bankgroup, mc_req.mem_addr.bank,
                        mc_req.mem_addr.row, mc_req.mem_addr.col, mc_req.mem_id,  mc_req.mem_user);
                `endif
            end : WriteAddressDataQueuePOP
            else begin
                
                WrPushPtrFree <= WrDataFree;
            end
        end

    end : WriteDataAddrQueueManagement
    


    //------------------------------------------------------------------------------
    //      Memory Controller Request Generation
    //
    //      - Converts frontend arbitration result into backend MC requests.
    //      - Issues either:
    //          * Single READ request, or
    //          * Burst-aligned WRITE request.
    //
    //  NOTE:
    //      - WRITE: req_valid asserted only at first beat.
    //      - READ : single-cycle request without pipelining.
    //------------------------------------------------------------------------------
    always_comb begin : MemoryControllerRequestSetup
        // Write request for memory controller
        mc_req  = '0;
        mc_req.write     = arbitrationMode;
        mc_req.readReady = noc_req.r_ready;
        mc_req.AckReady  = noc_req.b_ready;

        if(arbitrationMode) begin : WriteRequestPhase
            mc_req.req_data_valid = 1;
            mc_req.addr     = WrAddrQueue[assembleWriteAddrIndex].aw.addr; 
            mc_req.mem_addr = WrAddrQueue[assembleWriteAddrIndex].mem_addr;

            {mc_req.mem_id, mc_req.mem_user} = WrDataQueue[assembleWriteDataIndex][AXI_IDWIDTH+AXI_USERWIDTH+ (WR_BEAT_WIDTH * BURST_LENGTH)  - 1 : BURST_LENGTH * WR_BEAT_WIDTH];
            {mc_req.write_strb, mc_req.write_data} = WrDataQueue[assembleWriteDataIndex][WrPopCnt * WR_BEAT_WIDTH +: WR_BEAT_WIDTH];

            // Write request valid
            if(WrPopCnt == 0) begin
                mc_req.req_valid = WrAddrQueue[assembleWriteAddrIndex].fsm;           
            end else mc_req.req_valid = 0;

            if(WrPopCnt == BURSTTIMING) begin
                mc_req.last = 1;
            end else begin
                mc_req.last = 0;
            end
        end : WriteRequestPhase
        
        // Read request for memory controller
        else begin : ReadRequsetPhase
            if(ReadRequestReceived) begin
                mc_req.req_valid = (noc_req.ar_valid);
                mc_req.mem_addr = translatedAddr;
                mc_req.mem_id   = noc_req.ar.id;
                mc_req.mem_user = noc_req.ar.user;
                mc_req.addr     = noc_req.ar.addr;

                `ifdef DISPLAY
                if(mc_req.req_valid) begin
                    $display("[%0t] MemoryControllerFrontend | READ REQUEST SERVING | MEM_Addr: %d-%d-%d-%d-%d-%d (CH-RK-BG-BK-ROW-COL) | ID: %d | User: %d", 
                        $time, mc_req.mem_addr.channel, mc_req.mem_addr.rank, mc_req.mem_addr.bankgroup, mc_req.mem_addr.bank,
                        mc_req.mem_addr.row, mc_req.mem_addr.col, mc_req.mem_id, mc_req.mem_user);
                
                end
                `endif
            end
        end : ReadRequsetPhase
    end : MemoryControllerRequestSetup

    //------------------------------------------------------------------------------
    //      Write Burst Beat Counter
    //
    //      - Tracks current beat index within a write burst.
    //      - Controls data slicing and LAST signal generation.
    //
    //  NOTE:
    //      - Active only during WRITE arbitration phase.
    //------------------------------------------------------------------------------
    always_ff@(posedge clk or negedge rst_n)begin : WrPopCount
        if(!rst_n)begin
            WrPopCnt <= 0;
        end
        else begin
            if(arbitrationMode) begin
                WrPopCnt <= WrPopCnt + 1;
                if(WrPopCnt == BURSTTIMING)begin
                    WrPopCnt <= 0;
                end
            end else begin
                WrPopCnt <= 0;
            end
        end
    end : WrPopCount


    //------------------------------------------------------------------------------
    //      Cache / NoC Response Path
    //
    //      - Forwards backend READ and WRITE responses to cache-side interface.
    //      - Manages ready/valid handshaking for all AXI-like channels.
    //
    //  NOTE:
    //      - Read responses are stalled during write arbitration.
    //      - Backpressure is applied when assembler queues are full.
    //------------------------------------------------------------------------------


    //      But Response need a arbitration Scheduling , because both response from channels comes together.
    //      (TODO) Current Arbitration Scheduling Method -> Queue-depth-aware fairness arbitration
    //              - For prevent starvation, we do count the serving response numbers to dominant channel.
    
    //  Arbitration state machine:
    //      - SERVE_CH0 / SERVE_CH1 indicates which channel is currently served.
    //      - SwitchWait ensures channel switching occurs only after burst completion.

    typedef enum logic {SERVE_CH0, SERVE_CH1} RespArbitrationState_t;
    RespArbitrationState_t MCRespState;
    logic  SwitchWait;
    logic [$clog2(RESPSCHEDULINGCNT) - 1:0] ServingCnt;

    always_ff@(posedge clk or negedge rst_n) begin : MCResponseArbitration
        if(!rst_n) begin
            MCRespState <= SERVE_CH0; 
            SwitchWait <= 0;
        end else begin
             if(SwitchWait) begin
                if(MCRespState) begin
                    if(ch1_MCResp.last) begin
                        SwitchWait <= 0;
                        MCRespState <= SERVE_CH0;
                    end 
                end else if(!MCRespState) begin
                    if(ch0_MCResp.last)begin
                        SwitchWait <= 0;
                        MCRespState <= SERVE_CH1;
                    end
                end
             end
             else if(ServingCnt == RESPSCHEDULINGCNT -1) begin
                if(MCRespState && (Ch0_NumOfReadBufferEntry != 0)) begin
                    if(!ch1_MCResp.r_valid) begin
                        MCRespState <= SERVE_CH0;
                    end else begin
                        if(ch1_MCResp.r_valid && ch1_MCResp.last) begin
                            MCRespState <= SERVE_CH0;
                        end else begin
                            SwitchWait <= 1;
                        end
                    end
                end else if(!MCRespState && (Ch1_NumOfReadBufferEntry != 0)) begin
                    if(!ch0_MCResp.r_valid) begin
                        MCRespState <= SERVE_CH1;
                    end else begin
                        if(ch0_MCResp.r_valid && ch0_MCResp.last) begin
                            MCRespState <= SERVE_CH1;
                        end else begin
                            SwitchWait <= 1;
                        end
                    end
                end
             end else if(Ch0_NumOfReadBufferEntry > Ch1_NumOfReadBufferEntry) begin
                if(MCRespState) begin
                    if(ch1_MCResp.r_valid) begin
                        SwitchWait <= 1;
                        if(ch1_MCResp.r_valid && ch1_MCResp.last) begin
                            MCRespState <= SERVE_CH0;
                        end
                    end else begin
                        MCRespState <= SERVE_CH0;
                    end
                end
             end else if(Ch1_NumOfReadBufferEntry > Ch0_NumOfReadBufferEntry) begin
                if(!MCRespState) begin
                    if(ch0_MCResp.r_valid) begin
                        SwitchWait <= 1;
                        if(ch0_MCResp.r_valid && ch0_MCResp.last) begin
                            MCRespState <= SERVE_CH1;
                        end
                    end else begin
                        MCRespState <= SERVE_CH1;
                    end
                end
             end
        end
    end : MCResponseArbitration

    //------------------------------------------------------------------------------
    //      Starvation Avoidance Mechanism
    //
    //      - Counts consecutive responses served for the same channel.
    //      - Forces channel switch when SERVINGCNT threshold is reached,
    //          if the other channel has pending responses.
    //------------------------------------------------------------------------------
    always_ff@(posedge clk or negedge rst_n) begin : AvoidingRespStarvation
        if(!rst_n) begin
            ServingCnt <= 0;
        end else begin
            if(MCRespState) begin : ResponseForCH1
                if(Ch0_NumOfReadBufferEntry > Ch1_NumOfReadBufferEntry) begin 
                    ServingCnt <= 0;
                end else begin
                    if(ch1_MCResp.last)begin
                        ServingCnt <= ServingCnt + 1;
                    end 
                end
            end : ResponseForCH1 
            else if(!MCRespState) begin : ResponseForCH0
                if(Ch1_NumOfReadBufferEntry > Ch0_NumOfReadBufferEntry) begin
                    ServingCnt <= 0;
                end else begin
                    if(ch0_MCResp.last)begin
                        ServingCnt <= ServingCnt + 1;
                    end
                end
            end : ResponseForCH0
        end
    end : AvoidingRespStarvation





    assign MCRespStateBackend = (MCRespState == SERVE_CH0) ? 0 : 1;
    
    assign noc_resp.r.data   =  MCRespState ? ch1_MCResp.read_data : ch0_MCResp.read_data;
    assign noc_resp.r.id =  MCRespState ? ch1_MCResp.mem_read_id : ch0_MCResp.mem_read_id;
    assign noc_resp.r.user = MCRespState ? ch1_MCResp.mem_read_user : ch0_MCResp.mem_read_user;
    assign noc_resp.r.last = MCRespState ? ch1_MCResp.last : ch0_MCResp.last;
    assign noc_resp.r_valid = MCRespState ? ch1_MCResp.r_valid : ch0_MCResp.r_valid;

    assign noc_resp.b.id = ch1_MCResp.b_valid ? ch1_MCResp.mem_ack_id : ch0_MCResp.b_valid ? ch0_MCResp.mem_ack_id : 0;
    assign noc_resp.b.user = ch1_MCResp.b_valid ? ch1_MCResp.mem_ack_user : ch0_MCResp.b_valid ? ch0_MCResp.mem_ack_user : 0;
    assign noc_resp.b_valid = ch1_MCResp.b_valid || ch0_MCResp.b_valid;



    assign aggregate_ar_ready =  {{NUMRANK{~Ch1_ReadBufferFull}}  & Ch1_RankFSMRdReady,   {NUMRANK{~Ch0_ReadBufferFull}}  & Ch0_RankFSMRdReady};
    assign aggregate_w_ready =   {{NUMRANK{~Ch1_WriteBufferFull}} & Ch1_RankFSMWrReady,   {NUMRANK{~Ch0_WriteBufferFull}} & Ch0_RankFSMWrReady};
    assign aggregate_aw_ready =  {{NUMRANK{~Ch1_WriteBufferFull}} & Ch1_RankFSMWrReady,   {NUMRANK{~Ch0_WriteBufferFull}} & Ch0_RankFSMWrReady};


    assign noc_resp.ar_ready = (|aggregate_ar_ready) && !arbitrationMode;
    assign noc_resp.aw_ready = (|aggregate_aw_ready) && !WrAddrQueueFull;
    assign noc_resp.w_ready  = (|aggregate_w_ready)  && !WrDataQueueFull;







///////////// 위에꺼 Response 수정하기 + Frontend 랑 Top MemoryController 엮이는 거 다시 확인하기

`ifdef  ASSERTION
    CacheArbitrationOverlapping : assert property ( @(posedge clk) disable iff (!rst_n)
        noc_req.ar_valid |-> !(noc_req.aw_valid || noc_req.w_valid)
    ) else $error("MC Frontend: Both RD and WR NoC Request comes together");

    WriteRequestArbitration : assert property ( @(posedge clk) disable iff (!rst_n) 
        arbitrationMode |-> (mc_req.write)
    ) else $error("MC Frontend: Write Arbitration Mode Error");

    ReadRequestArbitration : assert property ( @(posedge clk) disable iff (!rst_n)
        (arbitrationMode) |-> (mc_req.write)
    ) else $error("MC Frontend: (Read Request) Arbitration Mode Error");
`endif
endmodule
