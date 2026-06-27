## Overview
This repository contains the design and implementation of a **5-stage pipelined CPU** for the ARM ISA. The design implements classic pipelining with hazard detection, data forwarding, and branch resolution.

The processor is written in Verilog and targets Xilinx FPGAs. It has been tested on the NetFPGA v2.

## Instruction Encoding

![ISA Encoding Diagram](ARM_ISA.png)
<!-- TODO: add ISA/instruction encoding diagram image -->

All instructions are 32 bits wide with a common field layout:

| Bits    | 31:28 | 27:26 | 25  | 24:21    | 20  | 19:16 | 15:12 | 11:0                |
|---------|-------|-------|-----|----------|-----|-------|-------|---------------------|
| Field   | Cond  | Type  | Imm | Opcode   | Set | Rn    | Rd    | Operand / Rs / Offset |

- **Cond** — 4-bit condition field, evaluated against the NZCV flags to decide whether the instruction executes
- **Type** — top-level instruction class (`00` = data processing, `01` = load/store, `10` = branch)
- **Imm** — selects between register operand (`Rs`, bits [3:0]) and immediate operand (bits [11:0]) for data-processing instructions
- **Opcode** — selects the specific ALU/data-processing operation
- **Set** — when asserted, the instruction updates the NZCV flags
- **Rn** — first source register
- **Rd** — destination register (data processing) or source/destination register (load/store)
- **Operand / Address offset** — immediate value, shifted register, or memory addressing offset depending on instruction class

### Data Processing (Type = `00`)

| Mnemonic | Opcode [24:21] | Operation                  |
|----------|----------------|-----------------------------|
| AND      | `0000`         | Rd = Rn & Operand            |
| XOR      | `0001`         | Rd = Rn ^ Operand            |
| SUB      | `0010`         | Rd = Rn − Operand            |
| RSUB     | `0011`         | Rd = Operand − Rn (reverse subtract) |
| ADD      | `0100`         | Rd = Rn + Operand            |
| ADC      | `0101`         | Rd = Rn + Operand + Carry    |
| SUBC     | `0110`         | Rd = Rn − Operand − !Carry   |
| RSUBC    | `0111`         | Rd = Operand − Rn − !Carry   |
| TST      | `1000`         | Rn & Operand (flags only, no writeback) |
| TEQ      | `1001`         | Rn ^ Operand (flags only, no writeback) |
| CMP      | `1010`         | Rn − Operand (flags only, no writeback) |
| CMN      | `1011`         | Rn + Operand (flags only, no writeback) |
| OR       | `1100`         | Rd = Rn \| Operand           |
| LSL/MOV  | `1101`         | Rd = Operand (optionally shifted) |
| BIC      | `1110`         | Rd = Rn & ~Operand (bit clear) |
| INV      | `1111`         | Rd = ~Operand (bitwise NOT)  |

All data-processing instructions update the NZCV flags when **Set** (bit 20) is asserted. `TST`, `TEQ`, `CMP`, and `CMN` always compute their result for flag-setting purposes only and never write back to `Rd`.

### Load/Store (Type = `01`)

| Mnemonic | Bit 24 (Imm) | Bits [23:20] (P, U, B, W) | Operation |
|----------|--------------|----------------------------|-----------|
| LW       | `0`          | P, U, B, W, **L=1**        | Rd = Mem[Rn + Address offset] |
| SW       | `0`          | P, U, B, W, **L=0**        | Mem[Rn + Address offset] = Rd |

- **P** — pre/post-indexed addressing select
- **U** — up/down (add/subtract offset)
- **B** — byte/word access size
- **W** — writeback of the computed address into `Rn`
- **L** — load (1) vs. store (0), distinguishing `LW` from `SW`

### Branch (Type = `10`)

| Field          | Bits     | Description |
|----------------|----------|--------------|
| L              | `25`     | Link bit — when set, stores the return address (branch-and-link) |
| Signed Immediate | `[23:0]` | 24-bit signed offset, sign-extended and shifted for word alignment, added to the PC |

Branches are conditionally executed based on the 4-bit **Cond** field evaluated against the current NZCV flags (e.g. `EQ`, `NE`, `GT`, `LT`, always/never, etc.), matching the condition-code scheme of classic ARM branch instructions.

## Pipeline Stages

The processor is organized into five stages:

```
IF  →  ID  →  EX  →  MEM  →  WB
```

| Stage | Name              | Function                                                                 |
|-------|-------------------|---------------------------------------------------------------------------|
| IF    | Instruction Fetch | Fetch instruction from instruction memory using PC                       |
| ID    | Decode            | Decode instruction, read register file, generate control signals         |
| EX    | Execute           | ALU operations, branch target/condition resolution, NZCV flag generation |
| MEM   | Memory            | Data memory access (loads/stores) via block RAM                          |
| WB    | Writeback         | Write result back to register file                                       |

## Datapath Architecture

![Datapath Diagram](ARM_PIPELINE.png)
<!-- TODO: add datapath diagram image -->

The full datapath is organized around four pipeline register boundaries — **IF/ID**, **ID/EX**, **EX/MEM**, and **MEM/WB** — each latching control and data signals between adjacent stages.

**IF stage.** The `PC` block is controlled by `PC_load`, `PC_inc`, `Branch`, and `Branch address` inputs and outputs the current `PC (31:0)`. This feeds `Instruction Memory (IMEM)`, which also exposes `Instruction_address`, `Instruction`, `Instruction_write`, and `wb` ports for external instruction loading/inspection. The fetched instruction and PC value are latched into the **IF/ID** register.

**ID stage.** Out of IF/ID, the instruction feeds the `Control Unit`, which decodes the opcode and generates control signals — `Write data`, `Write addr`, `Reg write`, and the `ALU OP` / `ALU SRC` selects that travel alongside the datapath into the EX stage. In parallel, the instruction's register fields drive the `Register File (CRF)`, which reads two operands — `Read data 1 (32)` and `Read data 2 (32)` — addressed by `Reg A addr` and `Reg B addr`. The branch offset path runs alongside decode: the immediate field is sign-extended (`Sign Extend`, 32-bit result), shifted left by 2 (`<<2`) for word alignment, and added to `PC + 4 (32)` in the `Adder (+)` to produce `Branch address (32)`. Register read data, control signals, and the computed branch address are all latched into the **ID/EX** register.

**EX stage.** Out of ID/EX, `Read data 1` and `Read data 2` pass through a pair of muxes (`EXMUX Reg`) that select between register file outputs and forwarded values supplied by the `FU` (Forwarding Unit), before reaching the `ALU`. The ALU performs the operation selected by `ALU OP` / `ALU SRC`, producing a result and the `Flags` (NZCV) output. The `FU` taps the EX/MEM and MEM/WB register outputs to resolve RAW hazards without stalling. The ALU result, flags, and associated control signals are latched into the **EX/MEM** register.

**MEM stage.** Out of EX/MEM, the ALU result addresses `Data Memory (DMEM)`, which takes `Data in` (the store value) and is controlled by `Mem. write` / `Mem. read`. The load result and the ALU result are both latched into the **MEM/WB** register.

**WB stage.** Out of MEM/WB, a final 2:1 mux selects between the ALU result (`0`) and the memory read result, `MemData (32)` (`1`), to produce `wb data` — the value written back into the register file.

**Hazard/control loop.** The `HDU` (Hazard Detection Unit) watches the ID/EX register contents and asserts `stall` back into the PC and IF/ID register to hold the pipeline for load-use hazards. The branch resolution path (`Branch`, `Branch address`) feeds back into the `PC` block and `IMEM` addressing to redirect fetch on a taken branch.

## Hazards Handled

### Structural Hazards
Instruction and data memory are accessed via separate ports (Harvard-style at the pipeline level), avoiding IF/MEM stage memory port conflicts.

### Data Hazards
- **RAW hazards** are resolved via the `FU` (Forwarding Unit), prioritizing the most recent result (EX/MEM forwarding over MEM/WB forwarding when both apply).
- **Load-use hazards** are detected by the `HDU` when a load's destination register matches a source register of the immediately following instruction. Because data memory is implemented in block RAM with registered (one-cycle-late) read data, the stall condition is generated one cycle after the naive "textbook" detection point, and the stall logic uses non-blocking assignments to avoid race conditions with the pipeline register updates.

### Control Hazards
- Branch condition and target are resolved in the EX stage.
- On a taken branch, the IF and ID stage instructions (not yet committed) are flushed in the same cycle that the branch-taken signal is asserted combinationally — flushing on a registered/delayed version of that signal would flush one cycle too late and allow an incorrect instruction to execute.

## Features

- **5-stage in-order pipeline** with full datapath (IF/ID/EX/MEM/WB)
- **Hazard Detection Unit (HDU)** for load-use hazards, correctly accounting for block RAM read latency
- **Forwarding unit (FU)** to resolve EX/MEM and MEM/WB data hazards without unnecessary stalling
- **ARM-style conditional branching**, with NZCV condition flag evaluation and a 24-bit signed branch immediate, sign-extended and shifted for word alignment
- **Branch flush logic** that flushes IF and ID stage instructions in the same cycle as a taken branch
- **Per-pipeline NZCV flag register**, updated only by instructions that set flags
- **Aligned writeback path**, with load data correctly registered and aligned with the writeback mux





