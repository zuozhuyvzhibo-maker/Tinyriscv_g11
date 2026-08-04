#!/usr/bin/env python3
"""Generate one compact self-checking image for the retained project ISA.

The image is deliberately linker/toolchain independent.  It covers every
implemented RV32I instruction, the NOP pseudo-instruction, and the three
course extensions (sID, rT, and if).  It is shared by all four cores.

Architectural result convention:
  x26 == 1, x27 == 1, x25 == 0  -> all checks passed
  x26 == 1, x27 == 0, x25 != 0  -> failed; x25 is the failure code

On failure, the program also attempts to send the low byte of x25 through
the course ``if`` instruction.  On success, UART emits the selected core's
10-byte sID followed by A5 after the rT transaction has completed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional


ROM_WORDS = 256
RAM_WORDS = 16

OP_LOAD = 0b0000011
OP_MISC_MEM = 0b0001111
OP_IMM = 0b0010011
OP_AUIPC = 0b0010111
OP_STORE = 0b0100011
OP_REG = 0b0110011
OP_LUI = 0b0110111
OP_BRANCH = 0b1100011
OP_JALR = 0b1100111
OP_JAL = 0b1101111
OP_CUSTOM = 0b0101111


def _signed(value: int, bits: int) -> int:
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def _require_signed(value: int, bits: int, what: str) -> None:
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    if not lo <= value <= hi:
        raise ValueError(f"{what} {value} is outside signed {bits}-bit range")


def enc_r(funct7: int, rs2: int, rs1: int, funct3: int, rd: int,
          opcode: int = OP_REG) -> int:
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)


def enc_i(imm: int, rs1: int, funct3: int, rd: int,
          opcode: int = OP_IMM) -> int:
    _require_signed(imm, 12, "I-immediate")
    return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | \
           (opcode & 0x7F)


def enc_s(imm: int, rs2: int, rs1: int, funct3: int) -> int:
    _require_signed(imm, 12, "S-immediate")
    value = imm & 0xFFF
    return (((value >> 5) & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           ((value & 0x1F) << 7) | OP_STORE


def enc_b(imm: int, rs2: int, rs1: int, funct3: int) -> int:
    if imm & 1:
        raise ValueError(f"B-immediate {imm} is not 2-byte aligned")
    _require_signed(imm, 13, "B-immediate")
    value = imm & 0x1FFF
    return (((value >> 12) & 1) << 31) | \
           (((value >> 5) & 0x3F) << 25) | ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           (((value >> 1) & 0xF) << 8) | (((value >> 11) & 1) << 7) | \
           OP_BRANCH


def enc_u(upper: int, rd: int, opcode: int) -> int:
    return ((upper & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | \
           (opcode & 0x7F)


def enc_j(imm: int, rd: int) -> int:
    if imm & 1:
        raise ValueError(f"J-immediate {imm} is not 2-byte aligned")
    _require_signed(imm, 21, "J-immediate")
    value = imm & 0x1FFFFF
    return (((value >> 20) & 1) << 31) | \
           (((value >> 1) & 0x3FF) << 21) | \
           (((value >> 11) & 1) << 20) | \
           (((value >> 12) & 0xFF) << 12) | ((rd & 0x1F) << 7) | \
           OP_JAL


@dataclass
class Fixup:
    index: int
    kind: str
    label: str
    rs1: int = 0
    rs2: int = 0
    funct3: int = 0
    rd: int = 0
    addend: int = 0


class Program:
    def __init__(self) -> None:
        self.words: List[int] = []
        self.labels: Dict[str, int] = {}
        self.fixups: List[Fixup] = []
        self.coverage: Dict[str, List[dict]] = {}
        self.failure_codes: Dict[str, str] = {}
        self.next_failure_code = 1

    @property
    def pc(self) -> int:
        return len(self.words) * 4

    def emit(self, word: int, mnemonic: Optional[str] = None,
             note: str = "") -> int:
        index = len(self.words)
        self.words.append(word & 0xFFFFFFFF)
        if mnemonic:
            self.coverage.setdefault(mnemonic, []).append(
                {"word_index": index, "pc": index * 4, "note": note}
            )
        return index

    def label(self, name: str) -> None:
        if name in self.labels:
            raise ValueError(f"duplicate label {name}")
        self.labels[name] = self.pc

    def branch(self, funct3: int, rs1: int, rs2: int, label: str,
               mnemonic: Optional[str] = None, note: str = "") -> None:
        index = self.emit(0, mnemonic, note)
        self.fixups.append(Fixup(index, "branch", label, rs1=rs1,
                                 rs2=rs2, funct3=funct3))

    def jal(self, rd: int, label: str, mnemonic: Optional[str] = None,
            note: str = "") -> None:
        index = self.emit(0, mnemonic, note)
        self.fixups.append(Fixup(index, "jal", label, rd=rd))

    def addi_label(self, rd: int, label: str, addend: int = 0) -> None:
        index = self.emit(0)
        self.fixups.append(Fixup(index, "addi_label", label, rd=rd,
                                 addend=addend))

    def li(self, rd: int, value: int) -> None:
        value &= 0xFFFFFFFF
        signed_value = _signed(value, 32)
        if -2048 <= signed_value <= 2047:
            self.emit(enc_i(signed_value, 0, 0b000, rd))
            return
        upper = ((value + 0x800) >> 12) & 0xFFFFF
        base = (upper << 12) & 0xFFFFFFFF
        lower = _signed((value - base) & 0xFFFFFFFF, 32)
        if not -2048 <= lower <= 2047:
            raise AssertionError(f"bad li split for 0x{value:08x}")
        self.emit(enc_u(upper, rd, OP_LUI))
        if lower:
            self.emit(enc_i(lower, rd, 0b000, rd))

    def set_failure(self, description: str) -> int:
        code = self.next_failure_code
        if code > 255:
            raise ValueError("failure code no longer fits in one UART byte")
        self.next_failure_code += 1
        self.failure_codes[str(code)] = description
        self.emit(enc_i(code, 0, 0b000, 25))
        return code

    def check_value(self, reg: int, expected: int, description: str) -> None:
        self.li(4, expected)
        self.set_failure(description)
        self.branch(0b001, reg, 4, "fail")  # BNE

    def check_regs(self, lhs: int, rhs: int, description: str) -> None:
        self.set_failure(description)
        self.branch(0b001, lhs, rhs, "fail")

    def resolve(self) -> None:
        for fixup in self.fixups:
            if fixup.label not in self.labels:
                raise ValueError(f"undefined label {fixup.label}")
            source_pc = fixup.index * 4
            target_pc = self.labels[fixup.label]
            if fixup.kind == "branch":
                self.words[fixup.index] = enc_b(target_pc - source_pc,
                                                 fixup.rs2, fixup.rs1,
                                                 fixup.funct3)
            elif fixup.kind == "jal":
                self.words[fixup.index] = enc_j(target_pc - source_pc,
                                                 fixup.rd)
            elif fixup.kind == "addi_label":
                value = target_pc + fixup.addend
                _require_signed(value, 12, "label address")
                self.words[fixup.index] = enc_i(value, 0, 0b000, fixup.rd)
            else:
                raise ValueError(f"unknown fixup type {fixup.kind}")


def build_program() -> Program:
    p = Program()

    # Shared completion/status convention and UART enable.  x31 remains the
    # threshold register for the course IF instruction.
    p.emit(enc_i(0, 0, 0b000, 26))
    p.emit(enc_i(0, 0, 0b000, 27))
    p.emit(enc_i(0, 0, 0b000, 25))
    p.emit(enc_i(0, 0, 0b000, 31))
    p.li(20, 0x30000000)
    p.emit(enc_i(1, 0, 0b000, 21))
    p.emit(enc_s(0, 21, 20, 0b010))

    # Register-register ALU instructions.
    p.li(1, 5)
    p.li(2, 3)
    p.li(5, -3)
    r_tests = [
        ("ADD", 0x00, 0b000, 1, 2, 8),
        ("SUB", 0x20, 0b000, 1, 2, 2),
        ("SLL", 0x00, 0b001, 1, 2, 40),
        ("SLT", 0x00, 0b010, 5, 1, 1),
        ("SLTU", 0x00, 0b011, 5, 1, 0),
        ("XOR", 0x00, 0b100, 1, 2, 6),
        ("SRL", 0x00, 0b101, 5, 2, 0x1FFFFFFF),
        ("SRA", 0x20, 0b101, 5, 2, 0xFFFFFFFF),
        ("OR", 0x00, 0b110, 1, 2, 7),
        ("AND", 0x00, 0b111, 1, 2, 1),
    ]
    for name, funct7, funct3, rs1, rs2, expected in r_tests:
        p.emit(enc_r(funct7, rs2, rs1, funct3, 3), name,
               f"{name} result check")
        p.check_value(3, expected, f"{name} result")

    # Immediate ALU instructions, including signed and high-bit operands.
    i_tests = [
        ("ADDI", -5, 1, 0b000, 0),
        ("SLTI", -2, 5, 0b010, 1),
        ("SLTIU", -1, 1, 0b011, 1),
        ("XORI", -1, 1, 0b100, 0xFFFFFFFA),
        ("ORI", 0x120, 1, 0b110, 0x125),
        ("ANDI", 0x0FF, 5, 0b111, 0x0FD),
    ]
    for name, imm, rs1, funct3, expected in i_tests:
        p.emit(enc_i(imm, rs1, funct3, 3), name,
               f"{name} immediate result check")
        p.check_value(3, expected, f"{name} result")

    p.emit(enc_i(4, 1, 0b001, 3), "SLLI", "left shift by four")
    p.check_value(3, 0x50, "SLLI result")
    p.emit(enc_i(4, 5, 0b101, 3), "SRLI", "logical right shift")
    p.check_value(3, 0x0FFFFFFF, "SRLI result")
    p.emit(enc_i((0x20 << 5) | 4, 5, 0b101, 3), "SRAI",
           "arithmetic right shift")
    p.check_value(3, 0xFFFFFFFF, "SRAI result")

    # x0 immutability and the standard NOP pseudo-instruction.
    p.emit(enc_i(123, 0, 0b000, 0), note="attempted x0 write")
    p.emit(enc_r(0x20, 1, 1, 0b000, 3))  # SUB x3,x1,x1 -> independent zero
    p.check_regs(0, 3, "x0 hard-wired zero")
    p.emit(0x00000013, "NOP", "ADDI x0,x0,0 pseudo-instruction")

    # Memory instructions use only two of the 16 shared RAM words.
    p.li(20, 0x10000000)
    p.li(1, 0xA1B2C3D4)
    p.emit(enc_s(0, 1, 20, 0b010), "SW", "word store to RAM word 0")

    load_tests = [
        ("LB", 0, 0b000, 0xFFFFFFD4),
        ("LBU", 1, 0b100, 0x000000C3),
        ("LH", 0, 0b001, 0xFFFFC3D4),
        ("LHU", 2, 0b101, 0x0000A1B2),
        ("LW", 0, 0b010, 0xA1B2C3D4),
    ]
    for name, offset, funct3, expected in load_tests:
        p.emit(enc_i(offset, 20, funct3, 3, OP_LOAD), name,
               f"load from RAM byte offset {offset}")
        p.check_value(3, expected, f"{name} result/sign extension")

    p.li(1, 0x5A)
    p.emit(enc_s(1, 1, 20, 0b000), "SB", "byte lane 1")
    p.emit(enc_i(0, 20, 0b010, 3, OP_LOAD))
    p.check_value(3, 0xA1B25AD4, "SB byte-lane preservation")
    p.li(1, 0x6677)
    p.emit(enc_s(2, 1, 20, 0b001), "SH", "upper halfword")
    p.emit(enc_i(0, 20, 0b010, 3, OP_LOAD))
    p.check_value(3, 0x66775AD4, "SH halfword-lane preservation")

    # A direct load-use dependency is kept intentionally (no inserted NOP).
    p.li(1, 0x11223344)
    p.emit(enc_s(4, 1, 20, 0b010))
    p.emit(enc_i(4, 20, 0b010, 2, OP_LOAD))
    p.emit(enc_i(1, 2, 0b000, 3))
    p.check_value(3, 0x11223345, "load-use interlock")

    # Each conditional branch is exercised once taken and once not taken.
    p.li(1, -1)
    p.li(2, 1)
    branch_tests = [
        ("BEQ", 0b000, 1, 1, 1, 2),
        ("BNE", 0b001, 1, 2, 1, 1),
        ("BLT", 0b100, 1, 2, 2, 1),
        ("BGE", 0b101, 2, 1, 1, 2),
        ("BLTU", 0b110, 2, 1, 1, 2),
        ("BGEU", 0b111, 1, 2, 2, 1),
    ]
    for name, funct3, taken_rs1, taken_rs2, nt_rs1, nt_rs2 in branch_tests:
        good_label = f"{name.lower()}_taken_ok"
        p.set_failure(f"{name} taken path")
        p.branch(funct3, taken_rs1, taken_rs2, good_label, name,
                 "taken case")
        p.jal(0, "fail")
        p.label(good_label)
        p.set_failure(f"{name} not-taken path")
        p.branch(funct3, nt_rs1, nt_rs2, "fail", name,
                 "not-taken case")

    # Upper-immediate and PC-relative instructions.
    p.emit(enc_u(0x12345, 3, OP_LUI), "LUI", "0x12345 upper immediate")
    p.check_value(3, 0x12345000, "LUI result")
    auipc_pc = p.pc
    p.emit(enc_u(0, 3, OP_AUIPC), "AUIPC", "zero upper, result is PC")
    p.check_value(3, auipc_pc, "AUIPC PC base")

    # JAL verifies both control transfer and its link value.
    p.set_failure("JAL control transfer")
    jal_pc = p.pc
    p.jal(5, "jal_target", "JAL", "forward transfer and link")
    p.jal(0, "fail")
    p.label("jal_target")
    p.check_value(5, jal_pc + 4, "JAL link register")

    # FENCE is architecturally a no-op for this single-hart memory system.
    p.emit(0x0000000F, "FENCE", "predecessor/successor masks are zero")
    p.emit(enc_i(7, 0, 0b000, 3))
    p.check_value(3, 7, "execution continued after FENCE")

    # Simple back-to-back forwarding chain.
    p.emit(enc_i(7, 0, 0b000, 1))
    p.emit(enc_i(1, 1, 0b000, 2))
    p.emit(enc_r(0, 1, 2, 0b000, 3))
    p.check_value(3, 15, "EX forwarding chain")

    # Course extensions.  The bus/UART model provides the external checks.
    p.emit(enc_i(0, 0, 0b000, 0, OP_CUSTOM), "sID",
           "emit selected core's ten-byte student ID")
    p.emit(enc_i(0, 0, 0b001, 14, OP_CUSTOM), "rT",
           "read LM75; Icarus checks x14 and bus protocol")
    p.li(31, -1)
    p.li(5, 10)
    p.emit(enc_i(7, 5, 0b010, 13, OP_CUSTOM), "if",
           "non-firing result path: 10+7")
    p.check_value(13, 17, "if non-firing result")
    p.li(31, 0)
    # sID retires after posting its command; it does not wait for all ten
    # physical bytes.  A single idle observation can occur between ID bytes,
    # so require two consecutive UART-status reads with busy==0.
    p.li(20, 0x30000000)
    p.label("success_uart_idle")
    p.emit(enc_i(4, 20, 0b010, 6, OP_LOAD))
    p.emit(enc_i(1, 6, 0b111, 6))
    p.branch(0b001, 6, 0, "success_uart_idle")
    p.emit(enc_i(4, 20, 0b010, 6, OP_LOAD))
    p.emit(enc_i(1, 6, 0b111, 6))
    p.branch(0b001, 6, 0, "success_uart_idle")
    p.li(5, 0xA5)
    p.emit(enc_i(0, 5, 0b010, 13, OP_CUSTOM), "if",
           "firing path emits UART marker A5")
    p.check_value(13, 0, "if firing path clears destination")

    # The course-scope image uses the word-aligned JALR targets exercised by
    # the existing software, while still checking both transfer and link.
    # A separate strict conformance test is required to observe bit-zero
    # clearing with an odd source address.
    p.addi_label(7, "jalr_target", addend=0)
    jalr_pc = p.pc
    p.emit(enc_i(0, 7, 0b000, 8, OP_JALR), "JALR",
           "word-aligned source address; verify transfer and link")
    p.jal(0, "fail")
    p.label("jalr_target")
    jalr_target_pc = p.pc
    p.emit(enc_u(0, 9, OP_AUIPC), note="observe aligned JALR target PC")
    p.check_value(9, jalr_target_pc, "JALR aligned target address")
    p.check_value(8, jalr_pc + 4, "JALR link register")

    p.li(25, 0)
    p.li(27, 1)
    p.li(26, 1)
    p.label("success_loop")
    p.jal(0, "success_loop")

    # Failure path: keep x27 at zero, emit the one-byte failure code when the
    # IF/UART path is operational, then assert completion for LED observation.
    p.label("fail")
    p.li(20, 0x30000000)
    p.label("fail_uart_idle")
    p.emit(enc_i(4, 20, 0b010, 6, OP_LOAD))
    p.emit(enc_i(1, 6, 0b111, 6))
    p.branch(0b001, 6, 0, "fail_uart_idle")
    p.emit(enc_i(4, 20, 0b010, 6, OP_LOAD))
    p.emit(enc_i(1, 6, 0b111, 6))
    p.branch(0b001, 6, 0, "fail_uart_idle")
    p.li(31, 0)
    for _ in range(4):
        p.emit(0x00000013)
    p.emit(enc_i(0, 25, 0b010, 0, OP_CUSTOM), note="UART failure code")
    p.li(26, 1)
    p.label("fail_loop")
    p.jal(0, "fail_loop")

    p.resolve()
    return p


REQUIRED_COVERAGE = [
    "ADD", "SUB", "SLL", "SLT", "SLTU", "XOR", "SRL", "SRA", "OR", "AND",
    "ADDI", "SLTI", "SLTIU", "XORI", "ORI", "ANDI", "SLLI", "SRLI", "SRAI",
    "LB", "LBU", "LH", "LHU", "LW", "SB", "SH", "SW",
    "BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU",
    "JAL", "JALR", "LUI", "AUIPC", "FENCE", "NOP",
    "sID", "rT", "if",
]


def write_outputs(program: Program, image_path: Path, manifest_path: Path) -> None:
    missing = sorted(set(REQUIRED_COVERAGE) - set(program.coverage))
    if missing:
        raise ValueError(f"coverage missing: {', '.join(missing)}")
    if len(program.words) > ROM_WORDS:
        raise ValueError(
            f"program needs {len(program.words)} words, exceeds {ROM_WORDS}-word ROM"
        )

    # The physical ROM image is padded to its exact 256-word depth.  The
    # manifest distinguishes executable words from harmless NOP padding.
    file_words = program.words + [0x00000013] * (ROM_WORDS - len(program.words))
    image_text = "".join(f"{word:08x}\n" for word in file_words)
    image_sha = hashlib.sha256(image_text.encode("ascii")).hexdigest()
    for entries in program.coverage.values():
        for entry in entries:
            entry["word"] = f"{program.words[entry['word_index']]:08x}"

    ids = {
        "LHR": "2023310936",
        "LDK": "2025210905",
        "SY": "2025210870",
        "WJE": "2025316191",
    }
    manifest = {
        "format": "tinyriscv-one-word-per-line-hex",
        "validation_profile": "course-rv32i-aligned-jalr-plus-extensions",
        "image": image_path.name,
        "sha256": image_sha,
        "rom": {
            "capacity_words": ROM_WORDS,
            "used_words": len(program.words),
            "free_words": ROM_WORDS - len(program.words),
            "used_bytes": len(program.words) * 4,
            "file_words_with_nop_padding": len(file_words),
            "file_bytes_with_nop_padding": len(file_words) * 4,
        },
        "ram": {
            "capacity_words": RAM_WORDS,
            "used_word_indices": [0, 1],
            "stack_used": False,
        },
        "completion": {
            "pass": {"x26": 1, "x27": 1, "x25": 0, "leds": "all four"},
            "fail": {"x26": 1, "x27": 0, "x25": "failure_codes key",
                     "uart": "one failure-code byte when IF/UART is usable"},
        },
        "expected_success_uart_hex": {
            core: sid.encode("ascii").hex(" ") + " a5" for core, sid in ids.items()
        },
        "lm75_simulation_word": "1900",
        "lm75_expected_x14": "00000032",
        "coverage": program.coverage,
        "failure_codes": program.failure_codes,
        "semantic_checks": [
            "every retained RV32I instruction executes at least once",
            "all six branches execute taken and not-taken cases",
            "signed/unsigned subword loads and byte/halfword store lanes",
            "x0 immutability, EX forwarding, and direct load-use dependency",
            "JAL/JALR aligned targets and link values",
            "sID byte stream, rT LM75 protocol/value, and IF fire/no-fire paths",
        ],
        "not_in_project_isa": [
            "M extension", "A extension", "C extension", "floating point",
            "CSR instructions", "ECALL/EBREAK", "interrupt/exception return",
            "FENCE.I/Zifencei",
        ],
        "notes": [
            "One image is downloaded once and reused while the four cores are selected in turn.",
            "The firmware cannot self-verify sID bytes or the physical LM75 transaction; the companion Icarus testbench verifies them externally.",
            "On a board, success requires the LM75 to acknowledge. A valid temperature of zero is not treated as an error.",
            "Course-scope JALR testing uses word-aligned targets; the known upstream bit-zero deviation is documented but is not a pass gate for this image.",
        ],
    }

    image_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    image_path.write_text(image_text, encoding="ascii", newline="\n")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
                             encoding="utf-8", newline="\n")

    print(f"IMAGE={image_path}")
    print(f"MANIFEST={manifest_path}")
    print(f"WORDS={len(program.words)} BYTES={len(program.words) * 4} "
          f"FREE_WORDS={ROM_WORDS - len(program.words)}")
    print(f"SHA256={image_sha}")


def parse_args() -> argparse.Namespace:
    script = Path(__file__).resolve()
    repo_root = script.parents[3]
    default_image = repo_root / "rtl" / "lhr" / "tests" / "programs" / \
                    "all_isa_selfcheck.data"
    default_manifest = repo_root / "rtl" / "merged" / "verification" / \
                       "all_isa_selfcheck_manifest.json"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=default_image)
    parser.add_argument("--manifest", type=Path, default=default_manifest)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    write_outputs(build_program(), args.output.resolve(), args.manifest.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
