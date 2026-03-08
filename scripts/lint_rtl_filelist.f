# ===============================
# Common (packages / interfaces)
# ===============================
common/MemoryController_Definitions.sv
common/DDR4Interface.sv
common/DRAMTimingCounter.sv
common/DualPortBuffer.sv
common/priority_ptr_WriteBuf.sv
common/PriorityEncoder_LSB.sv

# ===============================
# Backend
# ===============================
backend/RankController/APTimingScheduler.sv
backend/ChannelController/CMDGrantScheduler.sv
backend/ChannelController/CMDTurnaroundGrant.sv
backend/ChannelController/DQRdWrCCDGrant.sv
backend/ChannelController/DQTurnaroundGrant.sv
backend/PHYController/PHYController.sv
backend/PHYController/PHYReadMode.sv
backend/PHYController/PHYWriteMode.sv
backend/RankController/RankExecutionUnit.sv
backend/RankController/RankSched.sv
backend/RankController/RankController.sv
backend/RWBufferController/ReadBufferController.sv
backend/RWBufferController/WriteBufferController.sv
backend/ChannelController/ChannelController.sv
backend/MemoryControllerBackend.sv

# ===============================
# Frontend
# ===============================
frontend/AddressTranslationUnit.sv
frontend/MemoryControllerFrontend.sv

# ===============================
# Top
# ===============================
MemoryController.sv
