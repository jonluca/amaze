#!/usr/bin/env python3
"""Independently replay saved Classic routes and compare the bundled Swift table."""

import argparse
import json
from pathlib import Path
import re


IOS = Path(__file__).resolve().parent.parent
DIRECTIONS = {"up": (-1, 0), "down": (1, 0), "left": (0, -1), "right": (0, 1)}
SWIFT_ENTRY = re.compile(
    r"Entry\(width: (\d+), height: (\d+), startIndex: (\d+), "
    r"mask0: (0x[0-9a-f]+), mask1: (0x[0-9a-f]+), "
    r"mask2: (0x[0-9a-f]+), mask3: (0x[0-9a-f]+), "
    r"minimumMoves: (\d+)\), // Level (\d+)"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def verify_route(entry: dict) -> tuple:
    number = entry["number"]
    grid = entry["grid"]
    width, height, start = (grid[key] for key in ("width", "height", "startIndex"))
    require(all(type(value) is int for value in (number, width, height, start)), "Noninteger grid identity")
    require(1 <= number <= 1_000 and 1 <= width <= 16 and 1 <= height <= 16, f"Invalid dimensions: {number}")
    indices = grid["openCells"]
    require(all(type(index) is int for index in indices), f"Noninteger cell: {number}")
    require(indices == sorted(set(indices)), f"Duplicate or unordered cells: {number}")
    cells = {divmod(index, 16) for index in indices}
    require(all(0 <= row < height and 0 <= column < width for row, column in cells), f"Cell outside grid: {number}")
    position = divmod(start, 16)
    require(position in cells, f"Start is not open: {number}")
    route = entry["route"]
    moves = entry["minimumMoves"]
    require(type(moves) is int and moves >= 0 and len(route) == moves, f"Invalid route length: {number}")
    painted = {position}
    for direction in route:
        require(painted != cells, f"Route continued after completion: {number}")
        require(direction in DIRECTIONS, f"Unknown direction: {number}")
        delta_row, delta_column = DIRECTIONS[direction]
        before = position
        while (next_cell := (position[0] + delta_row, position[1] + delta_column)) in cells:
            position = next_cell
            painted.add(position)
        require(position != before, f"Blocked swipe: {number}")
    require(painted == cells, f"Route leaves unpainted cells: {number}")
    return width, height, start, tuple(indices)


def verify_swift(entries: list[dict], path: Path) -> None:
    matches = SWIFT_ENTRY.findall(path.read_text())
    require(len(matches) == len(entries), "Swift table does not contain the exact number of proof entries")
    for proof, fields in zip(entries, matches, strict=True):
        grid = proof["grid"]
        expected_masks = [0] * 4
        for index in grid["openCells"]:
            expected_masks[index // 64] |= 1 << (index % 64)
        actual = tuple(int(value, 0) for value in fields)
        expected = (grid["width"], grid["height"], grid["startIndex"], *expected_masks,
                    proof["minimumMoves"], proof["number"])
        require(actual == expected, f"Swift geometry/count differs from proof: {proof['number']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proofs", type=Path, default=IOS / "Validation/PerfectCounts/classic-1-1000.json")
    parser.add_argument("--swift", type=Path, default=IOS / "PrismRoll/Core/MazePerfectMoveCatalog+Generated.swift")
    parser.add_argument("--allow-partial", action="store_true", help="Replay a generation checkpoint without checking the final Swift table")
    args = parser.parse_args()
    artifact = json.loads(args.proofs.read_text())
    require(artifact["schemaVersion"] == 1, "Unsupported proof schema")
    require(artifact["coordinateEncoding"] == "row * 16 + column", "Unsupported coordinates")
    entries = artifact["entries"]
    numbers = [entry["number"] for entry in entries]
    require(numbers == sorted(set(numbers)), "Duplicate or unordered level numbers")
    if not args.allow_partial:
        require(numbers == list(range(1, 1_001)), "Expected every Classic level from 1 through 1000")
    by_grid = {}
    for entry in entries:
        grid = verify_route(entry)
        require(grid not in by_grid, f"Duplicate board: levels {by_grid.get(grid)} and {entry['number']}")
        by_grid[grid] = entry["number"]
    if not args.allow_partial:
        require(len(by_grid) == len(entries), "Classic catalog repeats a complete board/start identity")
        require(len({tuple(entry["grid"]["openCells"]) for entry in entries}) == len(entries),
                "Classic catalog repeats a wall layout even when ignoring start")
        verify_swift(entries, args.swift)
    suffix = "checkpoint routes" if args.allow_partial else "routes and exact Swift table entries"
    print(f"Verified {len(entries)} Classic {suffix}; {len(by_grid)} distinct grids; {sum(e['minimumMoves'] for e in entries)} legal swipes")


if __name__ == "__main__":
    main()
