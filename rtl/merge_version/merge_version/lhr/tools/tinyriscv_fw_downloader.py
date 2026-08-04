"""Download a TinyRISC-V program through the 35-byte FPGA UART protocol.

The downloader accepts either a binary image or the course ``.data`` format.
Each hexadecimal word in a ``.data`` file is converted to four little-endian
bytes before transmission, matching the FPGA program-memory word layout.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
from typing import Iterable


ACK = 0x06
NAK = 0x15
PACKET_LEN = 35
PAYLOAD_LEN = 32
FILE_NAME_LEN = 24
FILE_SIZE_OFFSET = 24
CRC_LOW_INDEX = 33
CRC_HIGH_INDEX = 34


def crc16_modbus(data: Iterable[int]) -> int:
    """Return the CRC-16/Modbus value used by fpga_uart_debug.v."""
    crc = 0xFFFF
    for value in data:
        crc ^= value
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc


def load_image(path: Path) -> bytes:
    """Load a raw binary or convert a course hexadecimal ``.data`` file."""
    if path.suffix.lower() != ".data":
        return path.read_bytes()

    image = bytearray()
    for line_number, source_line in enumerate(
        path.read_text(encoding="ascii").splitlines(), start=1
    ):
        line = source_line.split("//", 1)[0].split("#", 1)[0].strip()
        if not line:
            continue
        if line.lower().startswith("0x"):
            line = line[2:]
        if len(line) > 8:
            raise ValueError(
                f"{path}:{line_number}: expected one 32-bit hexadecimal word"
            )
        try:
            word = int(line, 16)
        except ValueError as error:
            raise ValueError(
                f"{path}:{line_number}: invalid hexadecimal word {line!r}"
            ) from error
        image.extend(word.to_bytes(4, byteorder="little", signed=False))
    return bytes(image)


def build_packet(number: int, payload: bytes) -> bytes:
    """Build one packet and append its little-endian CRC."""
    if len(payload) > PAYLOAD_LEN:
        raise ValueError("packet payload exceeds 32 bytes")
    packet = bytearray(PACKET_LEN)
    packet[0] = number & 0xFF
    packet[1 : 1 + len(payload)] = payload
    crc = crc16_modbus(packet[1:33])
    packet[CRC_LOW_INDEX] = crc & 0xFF
    packet[CRC_HIGH_INDEX] = (crc >> 8) & 0xFF
    return bytes(packet)


def build_packets(image_path: Path, image: bytes) -> list[bytes]:
    """Build the metadata packet and every 32-byte program packet."""
    if len(image) > 0xFFFFFFFF:
        raise ValueError("image is too large for the 32-bit FPGA header")

    header = bytearray(PAYLOAD_LEN)
    encoded_name = image_path.name.encode("ascii", errors="replace")
    header[: min(len(encoded_name), FILE_NAME_LEN)] = encoded_name[:FILE_NAME_LEN]
    header[FILE_SIZE_OFFSET : FILE_SIZE_OFFSET + 4] = len(image).to_bytes(
        4, byteorder="big"
    )

    packets = [build_packet(0, bytes(header))]
    data_packet_count = len(image) // PAYLOAD_LEN + 1
    for packet_index in range(data_packet_count):
        start = packet_index * PAYLOAD_LEN
        packets.append(build_packet(packet_index + 1, image[start : start + PAYLOAD_LEN]))
    return packets


def transmit(port: str, baud: int, timeout: float, packets: list[bytes]) -> None:
    """Transmit all packets, requiring an ACK after each packet."""
    try:
        import serial
    except ImportError as error:
        raise RuntimeError("pyserial is required: python -m pip install pyserial") from error

    with serial.Serial(
        port=port,
        baudrate=baud,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=timeout,
        xonxoff=False,
        rtscts=False,
        dsrdtr=False,
    ) as serial_port:
        serial_port.reset_input_buffer()
        for index, packet in enumerate(packets):
            serial_port.write(packet)
            serial_port.flush()
            response = serial_port.read(1)
            if response != bytes([ACK]):
                label = "timeout" if not response else f"0x{response[0]:02x}"
                if response == bytes([NAK]):
                    label = "NAK (0x15)"
                raise RuntimeError(f"packet {index} failed: FPGA returned {label}")
            print(f"packet {index}/{len(packets) - 1}: ACK")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download a .data or .bin program to the TinyRISC-V FPGA wrapper."
    )
    parser.add_argument("image", type=Path, help="course .data file or raw .bin image")
    parser.add_argument("--port", help="serial port, for example COM3")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--timeout", type=float, default=3.0)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate conversion and packet generation without opening a serial port",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        image_path = args.image.resolve(strict=True)
        image = load_image(image_path)
        packets = build_packets(image_path, image)
        print(f"image: {image_path}")
        print(f"program bytes: {len(image)}")
        print(f"35-byte packets: {len(packets)} (one header plus program data)")
        if args.dry_run:
            print("dry-run: packet construction passed")
            return 0
        if not args.port:
            raise ValueError("--port is required unless --dry-run is selected")
        transmit(args.port, args.baud, args.timeout, packets)
        print("download complete; set uart_debug_pin low to run the processor")
        return 0
    except (OSError, RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
