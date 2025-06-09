# EvoChirp – Bird Song Evolution Simulator

This repository contains the GNU Assembly implementation of **EvoChirp**, a bird song evolution simulator developed for the CMPE230 Systems Programming course at Boğaziçi University (Spring 2025). EvoChirp models the generational transformation of bird songs based on species-specific rules and a sequence of operators.

---

##  Project Overview

Birdsong plays a crucial role in avian communication. In EvoChirp:

- **Input:** A single line containing `<Species> <Song Expression>`, where:
  - `<Species>` is one of `Sparrow`, `Warbler`, or `Nightingale`.
  - `<Song Expression>` is a space‑separated sequence of notes (`C`, `T`, `D`) and operators (`+`, `-`, `*`, `H`).

- **Evolution Rules:** Each operator transforms the song buffer according to species-specific semantics:
  - **Merge (`+`)**: combines recent notes (e.g., `X Y + → X-Y` for Sparrow).
  - **Repeat (`*`)**: duplicates notes or patterns.
  - **Reduce (`-`)**: removes notes by softness or repetition logic.
  - **Harmonize (`H`)**: applies global or local melody adjustments.

- **Output:** For each operator (generation), prints:
  ```
  <Species> Gen N: <current song>
  ```
  where `N` is the zero‑based generation index.

---

##  Repository Structure

```
evochirp/
├── src/                      # Assembly source directory
│   └── evochirp.s            # Main GNU Assembly source (.s)
├── Makefile                  # Build and test automation
├── docs/
│   └──report.pdf             # Detailed project report
├── test/                     # Test harness scripts
│   ├── checker.py            # Single-case checker
│   └── grader.py             # Batch grading script
├── test-cases/               # Input/output pairs for automated grading
│   ├── input_00.txt
│   ├── output_00.txt
│   ├── input_01.txt
│   ├── output_01.txt
│   └── ...
├── .gitignore                # Common ignores
└── README.md                 # This documentation file
```

---

##  Build & Run Instructions

1. **Build the executable**  
   ```bash
   make
   ```
   This assembles `evochirp.s` and links into the `evochirp` binary.

2. **Run the simulator**  
   ```bash
   ./evochirp
   ```
   Enter your song expression (e.g., `Sparrow C C + D T * H`), then press Enter.

---

##  Automated Testing

- **Single test case**  
  ```bash
  python3 test/checker.py ./evochirp test-cases/input1.txt test-cases/output1.txt
  ```

- **Batch grading**  
  ```bash
  python3 test/grader.py ./evochirp test-cases/
  ```

---

##  Song Evolution Semantics

### Notes
- `C` – Chirp (soft, high-pitched)
- `T` – Trill (oscillating call)
- `D` – Deep Call (low resonant tone)

### Operators
| Operator | Behavior (Species)                                                     |
|----------|-------------------------------------------------------------------------|
| `+`      | Merge two recent notes:<br>• Sparrow: `X Y + → X-Y`<br>• Warbler: `X Y + → T-C`<br>• Nightingale: duplicate pair |
| `*`      | Repeat notes:<br>• Sparrow: duplicate last note<br>• Warbler: echo last pair<br>• Nightingale: duplicate entire song |
| `-`      | Reduce notes by softness or repetition:<br>• Sparrow: remove softest (`C` > `T` > `D`)<br>• Warbler: drop last note<br>• Nightingale: remove recent repetition |
| `H`      | Harmonize:<br>• Sparrow: swap `C↔T`, expand `D→D-T`<br>• Warbler: append trill<br>• Nightingale: rearrange last three notes |

---

##  Memory Layout & Buffers

- **input_buf** (1024 B): stores the raw input line.
- **temp_buf** (1024 B): staging area for transformations.
- **song_buf** (1024 B): final buffer for printing each generation.

The program uses low‑level buffer pointers and AT&T‑syntax instructions for in‑place modifications, with full-buffer copies per generation.

---

##  Register Usage

Each register has a dedicated job throughout the assembly interpreter:

| Register          | Role                                                          |
|-------------------|---------------------------------------------------------------|
| `%r13`            | Generation counter (–1 → 0 on first increment)                |
| `%r14`            | "Recent-note" counter (guards merges/repeats)                 |
| `%r12`            | Input-scanner pointer (walks through `input_buf`)             |
| `%r15`            | Write pointer into `temp_buf`                                 |
| `%r10`, `%r11`    | Scratch pointers for copying between `temp_buf` and `song_buf`|
| `%rax, %rdi, %rsi, %rdx, %rcx` | Syscall arguments and loop counters           |


##  Documentation & Report

- **Project Report:** `docs/report.pdf` – methodology, implementation details, register usage, and performance analysis.

---

##  License

This project is released under the MIT License. See `LICENSE` for details.
