# ===============================
# Packages / Interfaces
# ===============================
../rtl/common/MemoryController_Definitions.sv
../rtl/common/DDR4Interface.sv
../tb/uvm/svut_if.sv

# ===============================
# Common Modules
# ===============================
../rtl/common/DRAMTimingCounter.sv
../rtl/common/DualPortBuffer.sv
../rtl/common/priority_ptr_WriteBuf.sv
../rtl/common/PriorityEncoder_LSB.sv

# ===============================
# Backend
# ===============================
../rtl/backend/RankController/APTimingScheduler.sv
../rtl/backend/ChannelController/CMDGrantScheduler.sv
../rtl/backend/ChannelController/CMDTurnaroundGrant.sv
../rtl/backend/ChannelController/DQRdWrCCDGrant.sv
../rtl/backend/ChannelController/DQTurnaroundGrant.sv
../rtl/backend/PHYController/PHYController.sv
../rtl/backend/PHYController/PHYReadMode.sv
../rtl/backend/PHYController/PHYWriteMode.sv
../rtl/backend/RankController/RankExecutionUnit.sv
../rtl/backend/RankController/RankSched.sv
../rtl/backend/RankController/RankController.sv
../rtl/backend/RWBufferController/ReadBufferController.sv
../rtl/backend/RWBufferController/WriteBufferController.sv
../rtl/backend/ChannelController/ChannelController.sv
../rtl/backend/MemoryControllerBackend.sv

# ===============================
# Frontend
# ===============================
../rtl/frontend/AddressTranslationUnit.sv
../rtl/frontend/MemoryControllerFrontend.sv

# ===============================
# Top RTL
# ===============================
../rtl/MemoryController.sv

# ===============================
# BFM
# ===============================
../bfm/MemoryBankFSM.sv
../bfm/MemoryRank.sv
../bfm/MemoryChannel.sv
../bfm/MemoryBFM.sv

# ===============================
# Testbench
# ===============================
../tb/uvm/lfsr_driver.sv
../tb/uvm/driver.sv
../tb/uvm/monitor.sv
../tb/uvm/scoreboard.sv
../tb/uvm/Top_xsim.sv
