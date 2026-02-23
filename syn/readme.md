# RTL Synthesis Flow

This directory contains synthesis scripts and configuration files
for the DDR4 Memory Controller RTL.

The synthesis flow is used to validate structural correctness,
resource mapping, and timing feasibility of the design.

---

## 🛠 Toolchain

- **Synthesis Tool**: Yosys (0.62+0)
- **Technology Library**: Nangate45 (refernce by https://github.com/ABKGroup/NanGate45-Synopsys-Enablement)
- **Mapping Flow**: Generic RTL → Gate-level (technology-mapped)

---

## 📐 Target Scope

The following modules are synthesized:

- Top-level: `MemoryController.sv`
- Frontend subsystem
- Backend subsystem

BFM and testbench components are excluded.

---

## 🧱 Synthesis Flow (Nangate45)

The synthesis script (`syn_nangate45.ys`) performs
technology-mapped ASIC-style synthesis targeting the
Nangate Open Cell Library (45nm).

### Flow Steps

1. **SystemVerilog Parsing**
   - All synthesizable RTL modules are loaded using `read -sv2012`.

2. **Hierarchy Elaboration**
   - Top module: `MemoryController`

3. **Generic RTL Synthesis**
   - `synth -top MemoryController`

4. **Flip-Flop Normalization**
   - Async resets converted using `adff2dff`
   - FF cleanup with `dffunmap`

5. **Technology Mapping**
   - Sequential mapping: `dfflibmap`
   - Combinational mapping: `abc`
   - Target library: `NangateOpenCellLibrary_typical.lib`

6. **Optimization & Cleanup**
   - `opt`, `opt_clean`

7. **Gate-Level Netlist Generation**
   - Output: `MemoryController_gate_nangate45.v`

8. **Area Statistics**
   - Report generated via `stat -liberty`

---

## 🎯 Objective

This flow validates:

- Full synthesizability of the RTL
- Proper FF mapping
- Technology-aware logic mapping
- Structural ASIC readiness

The flow is used for structural validation and architectural quality
assessment, not final PPA optimization.

---

This project does not target a specific silicon process, but synthesis ensures industry-grade RTL quality.
