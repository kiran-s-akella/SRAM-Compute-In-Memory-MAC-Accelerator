# An SRAM-Based Compute-In-Memory (CIM) Architecture for MAC Acceleration
**End-to-End RTL Design and FPGA Prototyping to SkyWater 130 nm GDSII Physical Implementation**

[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](#)
[![FPGA](https://img.shields.io/badge/FPGA-Digilent%20Basys%203%20(Artix--7)-orange.svg)](#)
[![ASIC](https://img.shields.io/badge/PDK-SkyWater%20130nm%20(SKY130)-green.svg)](#)
[![Flow](https://img.shields.io/badge/Flow-RTL--to--GDSII%20(LibreLane)-purple.svg)](#)

**Authors:** K Ashuthosh Bhat, Shreyas P M, Sriram Kiran Akella  
**Guide:** Dr. Nikhil K S, Department of Electronics and Communication Engineering, NITK Surathkal  

---

## 1. Introduction
In conventional computing systems (Von Neumann and Harvard architectures), a processor must repeatedly fetch weights and operands from memory, execute arithmetic operations, and write results back. While processor speeds have scaled rapidly, memory bandwidth and access latency have lagged-creating the **memory wall** and **von Neumann bottleneck**.

In neural network workloads, fetching weights from memory costs orders of magnitude more energy and latency than the multiply-accumulate (MAC) arithmetic itself. **Compute-in-Memory (CIM)** overcomes this bottleneck by placing arithmetic units directly adjacent to memory arrays. Using standard CMOS-compatible **SRAM**, this project implements an all-digital, weight-stationary 10-lane CIM array in Verilog where trained weights are loaded once and reused locally across incoming activations, verified from RTL simulation through FPGA prototyping and SkyWater 130 nm (SKY130) physical layout.

<p align="center">
 
  <img width="1220" height="614" alt="image" src="https://github.com/user-attachments/assets/8a5c2c9f-3e93-452c-bfbf-f0d5bb0f1dc6" />

  <em>Figure 1: Comparison between (a) Von Neumann architecture and (b) Compute-in-Memory architecture.</em>
</p>

---

## 2. Problem Statement
Conventional neural network accelerators suffer from excessive dynamic power consumption and latency due to continuous weight movement between off-chip/external memory and compute units. Conversely, analog SRAM-based CIM approaches while energy-efficient suffer from process variations, analog noise, and area/power overhead from ADC/DAC peripherals.

**This project addresses these challenges by:**
* Designing a **fully digital, weight-stationary SRAM-CIM architecture** in Verilog that eliminates repeated weight fetching via local lane-level SRAM storage.
* Enabling **parallel MAC execution** across 10 lanes with bit-exact deterministic accuracy.
* Supporting **weight reuse across multiple inputs** (`change_act`) without reloading memory.
* Validating the architecture end-to-end on a **handwritten digit recognition (MNIST)** workload across RTL simulation, **Basys 3 FPGA** hardware benchmarking against a Python/CPU baseline, and **SKY130 RTL-to-GDSII** physical implementation.

---

## 3. Research Gaps

| Reference / Domain | Existing Approach | Key Limitations / Research Gaps | How This Work Addresses It |
| :--- | :--- | :--- | :--- |
| **Conventional Architectures** | Von Neumann / Harvard CPU & external memory | Severe energy and latency penalty from fetching weights on every MAC cycle. | Pairs each MAC unit with dedicated local SRAM; weights are loaded once and reused across inputs. |
| **Analog SRAM CIM**  | Bitline charge-sharing / current summation with ADCs | Sensitive to process variation and noise; requires power- and area-hungry ADC/DAC converters. | Implements an **all-digital CIM** datapath at the SRAM output for bit-exact arithmetic and high portability. |
| **Digital CIM & Prototyping** | Isolated RTL macros or software-only quantization studies | Often lack full end-to-end validation spanning quantization, live FPGA hardware benchmarking, and open-PDK GDSII sign-off. | Delivers a complete **Python → Verilog RTL → Basys 3 FPGA → SKY130 GDSII** flow with zero timing violations. |

---

## 4. Methodology

### 4.1 Bottom-Up Design Approach and Workflow
The system follows a modular bottom-up hardware design flow paired with a parallel Python software training and quantization pipeline:
1. **Software Pipeline:** A single-layer MNIST classifier is trained in Python, quantized to 8-bit integers, and exported as `.hex` files.
2. **Hardware Hierarchy:** Built incrementally from the leaf `mac` unit to single `cimModule` lane (SRAM + MAC) and top-level 10-lane `cimArray` with an FSM controller.
3. **Verification & Implementation:** Bit-exact RTL verification against Python, followed by FPGA deployment (Digilent Basys 3) and ASIC physical design (LibreLane on SKY130).

<p align="center">
 <img width="1018" height="353" alt="image" src="https://github.com/user-attachments/assets/862f07f4-f31d-4b32-b2b9-be613ca9c42e" />


  <em>Figure 2: End-to-end software and bottom-up hardware design workflow.</em>
</p>

### 4.2 Overall Architecture
The top-level `cimArray` integrates **10 parallel CIM lanes** controlled by a central FSM.
* **Shared Input Bus (`data_in`):** An 8-bit bus broadcasts weights sequentially during load states and streams input pixels simultaneously to all 10 lanes during computation.
* **Local Weight Storage:** Each lane instantiates a 1 KB SkyWater 130 nm SRAM macro (`sky130_sram_1kbyte_1rw1r_8x1024_8`), storing 784 8-bit weights for one output digit class.
* **Parallel Output (`mac_output`):** Each lane produces a 32-bit signed dot product, forming a 320-bit combined output vector.

<p align="center">
  <img width="815" height="368" alt="image" src="https://github.com/user-attachments/assets/64720a54-9a2b-471c-9e89-e428e475f2ca" />

  <em>Figure 3: Block diagram of the 10-lane parallel CIM array.</em>
</p>

### 4.3 MAC Unit (`mac.v`)
The MAC unit executes one signed multiply-accumulate operation per clock cycle:
$$\text{acc}_{k+1} = \text{acc}_k + w_k \cdot x_k$$
* **Inputs:** 8-bit signed weight ($w_k$) from local SRAM and 8-bit input activation ($x_k$) from data_in.
* **Datapath:** Multiplies $w_k \times x_k$ into a 16-bit signed product and accumulates into a **32-bit signed register** (providing ample headroom over the 25-bit worst-case sum across 784 cycles without overflow).

<p align="center">
  <img width="794" height="263" alt="image" src="https://github.com/user-attachments/assets/fec8f213-e4ed-46d2-8be8-0eb7b3a2168f" />

  <em>Figure 4: Internal datapath of the 8-bit MAC unit with 32-bit accumulator.</em>
</p>

### 4.4 Controller (`cimArray.v`)
An FSM with a shared address counter orchestrates memory loading and parallel execution:
* **`IDLE`:** Waits for `start_flag`.
* **`WEIGHT0` – `WEIGHT9`:** Sequentially writes 784 weights into each lane's local SRAM via `data_in`.
* **`ACT`:** Broadcasts 784 flattened input pixels to all 10 lanes simultaneously while local SRAMs supply weights.
* **`DONE`:** Asserts completion with valid 320-bit `mac_output`. Asserting `change_act` transitions directly back to `ACT` to process new inputs while **reusing stored weights**.

<p align="center">
  <img width="838" height="155" alt="image" src="https://github.com/user-attachments/assets/6a7e189c-6cfb-4ab7-a0c9-1a10cd0e8547" />

  <em>Figure 5: Controller state transition diagram supporting one-time weight loading and input reuse.</em>
</p>

---

## 5. Results & Observations

### 5.1 RTL Simulation & Handwritten Digit Recognition
* **Bit-Exact Verification:** Simulated in Icarus Verilog and Vivado (`cimArray_tb`) using 8-bit quantized MNIST weights. Hardware outputs matched Python reference values across all 10 lanes.
* **Weight Reuse Verified:** Tested sequential classification (Digit `"4"` with fresh weight load followed by Digit `"3"` using `change_act` without reloading weights), accurately predicting both classes.

<p align="center">
  <img width="1200" height="600" alt="image" src="https://github.com/user-attachments/assets/77eb34ad-0c7d-48e6-8a4f-b7d414c8ad16" />

<img width="1263" height="563" alt="image" src="https://github.com/user-attachments/assets/a1929991-d27a-433c-9a53-074f51d86d48" />

<img width="1235" height="600" alt="image" src="https://github.com/user-attachments/assets/cc1b0b12-ef3b-4590-9845-9bece43646c8" />

  <em>Figure 6: Schematic Of CIM & Behavioral simulation waveform.</em>
</p>

<p align="center">
  <img width="687" height="344" alt="image" src="https://github.com/user-attachments/assets/28b30d4a-52eb-49ef-bbb0-c201d19392a6" />

<img width="700" height="114" alt="image" src="https://github.com/user-attachments/assets/c7186239-1fed-498c-9bce-b17e13cbc07d" />

  <em>Figure 7: Handwritten digit recognition test case "4" verified on the CIM RTL array.</em>
</p>

### 5.2 FPGA Implementation (Digilent Basys 3 @ 50 MHz)
The design was synthesized and implemented on a Xilinx Artix-7 (`xc7a35tcpg236-1`) FPGA at **50 MHz (20.0 ns period)**, mapping each lane's 1 KB weight memory to on-chip BRAM.

| Resource / Parameter | Used / Value | Available | Utilization / Notes |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | 1,260 | 20,800 | 6.06% |
| **Slice Registers (FFs)** | 515 | 41,600 | 1.24% |
| **Block RAM Tiles** | 21.5 | 50 | 43.00% (16× RAMB36E1, 11× RAMB18E1) |
| **DSP Slices** | 0 | 90 | 0.00% (100% fabric-synthesized arithmetic) |
| **On-Chip Power** | **0.094 W** Total | — | 0.021 W Dynamic (`cim` core: 0.001 W), 0.073 W Static |
| **Inference Latency** | **15.68 µs** | — | 784 active clock cycles @ 50 MHz |

<p align="center">
  <img width="1150" height="588" alt="image" src="https://github.com/user-attachments/assets/84eae8e5-a9fd-4bab-b5c3-3307d89f480b" />

  <em>Figure 8: Bitstream running live on the Digilent Basys 3 Artix-7 FPGA board.</em>
</p>

### 5.3 Hardware vs. Software Baseline Comparison
Compared against single-layer MNIST inference in Python on an **Intel Core i5-1135G7 CPU** (99.7% accuracy):

| Metric | Basys 3 FPGA (Artix-7 @ 50 MHz) | Python / CPU (Intel i5-1135G7) | Improvement |
| :--- | :--- | :--- | :--- |
| **Inference Time** | **15.68 µs** (784 cycles) | 5,000 µs (5 ms) | **~319× faster** |
| **Average Power** | **0.094 W** total (0.021 W dynamic) | 11.2 W (CPU package power)| **~119× lower power** |
| **Energy / Inference** | **~1.47 µJ** total (~0.33 µJ dynamic) | ~56,000 µJ| **~38,000× more efficient** |

<p align="center">
  <img width="875" height="257" alt="image" src="https://github.com/user-attachments/assets/ff02af96-97b7-4ee6-aa58-abe2f7066d20" />

  <em>Figure 9: Comparison of inference latency, average power, and energy per inference (FPGA vs. CPU).</em>
</p>

### 5.4 Physical Design & GDSII Sign-Off (SKY130 @ 25 MHz)
The RTL-to-GDSII physical implementation was completed using **LibreLane** on the **SkyWater 130 nm (SKY130)** PDK at a **40 ns clock period (25 MHz)** with hard 1 KB SRAM macros.

| Physical Design Metric | Result / Value |
| :--- | :--- |
| **Die / Core Area** | $8.17\text{ mm}^2$ ($3800 \times 2150\ \mu\text{m}$) / $8.06\text{ mm}^2$ Core |
| **Macros & Standard Cells** | 11 hard macros ($5.093\text{ mm}^2$) + 38,833 standard cells ($58,980.3\ \mu\text{m}^2$)|
| **Setup Timing (25 MHz)** | Worst Slack: **+6.75 ns** \| WNS: **0.0 ns** \| TNS: **0.0 ns** (0 violations) |
| **Hold Timing (25 MHz)** | Worst Slack: **+0.029 ns** \| WNS: **0.0 ns** \| TNS: **0.0 ns** (0 violations) |
| **Total Power (`nom_tt_025C_1v80`)** | **0.940 mW** (Internal: 0.609 mW, Switching: 0.319 mW, Leakage: 0.012 mW)|
| **Power Grid & Physical Checks** | **0 PG violations** (Worst IR drop: ~0.197 mV); DRC/LVS & Magic overlap clean |

<p align="center">
  <img width="900" height="538" alt="image" src="https://github.com/user-attachments/assets/0dad8cc0-d5e9-4394-be55-f63e4b08d27d" />

  <em>Figure 10: Final routed GDSII layout of the 10-lane CIM array on SkyWater 130 nm in LibreLane (25 MHz).</em>
</p>

---

## 6. Conclusion & Future Scope

### Conclusion
This project successfully demonstrated an end-to-end digital SRAM-based Compute-in-Memory MAC accelerator from Verilog RTL to GDSII layout. By co-locating local SRAM macros with parallel 8-bit MAC units and reusing weights across activations (`change_act`), the architecture eliminates redundant memory transfers. It achieved bit-exact MNIST digit classification, **15.68 µs** inference at **0.094 W** on a Basys 3 FPGA (~38,000× lower energy than CPU execution), and a timing-clean **0.940 mW** GDSII layout on SkyWater 130 nm.

### Future Scope
* **Multi-Layer Support & Bias Addition:** Integrate bias registers and intermediate activation buffers to support deep multi-layer neural networks.
* **Sub-Byte Quantization & Higher Parallelism:** Scale to 4-bit/2-bit precision and multi-MAC per lane configurations for higher TOPS/W throughput.
* **Low power wearable devices:** Adapt the sub-milliwatt SKY130 core for continuous wearable physiological monitoring (e.g., ECG classification).
* **Multi-Tile Scaling & Tape-Out:** Tile multiple 10-lane arrays with a standard bus interconnect and I/O pad-ring for silicon fabrication.

---

## Repository Structure
```text
├── rtl/                  # Verilog source files (mac.v, cimModule.v, cimArray.v, fpga_top.v)
├── tb/                   # Self-checking testbenches (cimArray_tb.v)
├── software/             # Python MNIST training, 8-bit quantization, and hex export scripts
├── fpga/                 # Vivado constraints (.xdc) and resource/power reports
├── physical_design/      # LibreLane SKY130 configuration, STA reports, and GDSII views
└── docs/figures/         # Architecture diagrams, waveforms, FPGA photo, and GDSII layout images
```
