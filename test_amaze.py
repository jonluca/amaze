import subprocess
import sys
import textwrap
import unittest
from pathlib import Path

import numpy as np

from amaze import AmazeGame


class AmazeGameTests(unittest.TestCase):
    def test_invalid_directions_leave_the_game_unchanged(self):
        # Keep a regression of the original infinite loop from hanging the suite.
        script = textwrap.dedent("""
            import numpy as np
            from amaze import AmazeGame

            game = AmazeGame(3)
            game.board.fill(1)
            game.board[0, 0] = 2
            board = game.board.copy()
            traversed = game.traversed.copy()
            for direction in ("", "invalid", "u", None):
                try:
                    game.make_move(direction)
                except ValueError:
                    pass
                else:
                    raise AssertionError(f"Invalid direction accepted: {direction!r}")
                np.testing.assert_array_equal(game.board, board)
                np.testing.assert_array_equal(game.traversed, traversed)
                assert game.ball == (0, 0)
        """)
        result = subprocess.run(
            [sys.executable, "-c", script],
            cwd=Path(__file__).resolve().parent,
            timeout=5,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_small_board_graph_starts_at_the_ball_marker(self):
        game = AmazeGame(3)
        game.board.fill(1)
        game.board[1, 1] = 2

        game.generate_graph()

        self.assertEqual(game.ball, (1, 1))
        start = game.nodes[game.ball]
        self.assertIn(start, game.paths)
        for direction, endpoint in {"U": (0, 1), "D": (2, 1), "L": (1, 0), "R": (1, 2)}.items():
            self.assertEqual(start.dirs[direction].index, endpoint)
            self.assertEqual(game.paths[start][start.dirs[direction]]["weight"], 1)

    def test_graph_uses_current_position_when_there_is_no_marker(self):
        game = AmazeGame(3)
        game.board.fill(1)
        game.ball = (2, 2)

        game.generate_graph()

        self.assertEqual(game.ball, (2, 2))
        self.assertIn(game.nodes[game.ball], game.paths)
        self.assertEqual(game.solve_dfs()[0].index, (2, 2))

    def test_rebuilding_graph_discards_old_layout_and_uses_moved_ball(self):
        game = AmazeGame(3)
        game.board.fill(1)
        game.board[1, 1] = 2
        game.generate_graph()
        game.make_move("R")
        self.assertEqual(game.ball, (1, 2))

        game.board[0, :] = 0
        game.board[2, :] = 0
        game.generate_graph()

        self.assertEqual(game.ball, (1, 2))
        self.assertEqual({node.index for node in game.paths}, {(1, 0), (1, 2)})
        self.assertIsNone(game.nodes[1, 1])
        self.assertEqual(game.nodes[1, 2].dirs["L"].index, (1, 0))
        self.assertEqual(game.paths[game.nodes[1, 2]][game.nodes[1, 0]]["weight"], 2)

    def test_graph_rejects_an_ambiguous_or_blocked_start(self):
        game = AmazeGame(3)
        with self.assertRaisesRegex(ValueError, "open cell"):
            game.generate_graph()

        game.board[0, 0] = 2
        game.board[1, 1] = 2
        with self.assertRaisesRegex(ValueError, "at most one ball"):
            game.generate_graph()

    def test_valid_move_still_slides_to_the_wall_and_marks_its_path(self):
        game = AmazeGame(4)
        game.board[1, :3] = 1
        game.board[1, 0] = 2
        game.generate_graph()

        game.make_move("R")

        self.assertEqual(game.ball, (1, 2))
        np.testing.assert_array_equal(game.board[1], [3, 3, 2, 0])
        self.assertTrue(game.traversed[1, 1])
        self.assertTrue(game.traversed[1, 2])


if __name__ == "__main__":
    unittest.main()
