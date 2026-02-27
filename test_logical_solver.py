import unittest
from logical_solver import HumanLogicSolver

class TestHumanLogicSolverAdvanced(unittest.TestCase):
    
    def setUp(self):
        # A simple blank board definition
        self.blank_level = {
            "id": 999,
            "board": "0" * 81,
            "ruleType": "classic",
            "constraints": []
        }

    def test_pointing_pairs(self):
        solver = HumanLogicSolver(self.blank_level)
        cands = solver.candidates
        
        # Clear candidates in Box 0
        for r in range(3):
            for c in range(3):
                cands[r][c] = {1, 2, 3}
                
        # Make a Pointing Pair of 9s in Box 0 on Row 0 (cells 0,0 and 0,1)
        cands[0][0].add(9)
        cands[0][1].add(9)
        
        # Add a 9 in Row 0, Box 1 (which SHOULD be removed)
        cands[0][5] = {1, 9}
        
        # Apply classic rules
        changed = solver._apply_classic_rules()
        
        # Assert 9 was removed from 0,5
        self.assertTrue(changed)
        self.assertNotIn(9, cands[0][5])
        
    def test_naked_pairs(self):
        solver = HumanLogicSolver(self.blank_level)
        cands = solver.candidates
        
        cands[0][0] = {1, 2, 3, 4}
        cands[0][1] = {3, 4} # Pair 1
        cands[0][2] = {3, 4} # Pair 2
        cands[0][3] = {1, 3, 4, 5}
        
        changed = solver._apply_classic_rules()
        
        self.assertTrue(changed)
        self.assertNotIn(3, cands[0][0])
        self.assertNotIn(4, cands[0][0])
        self.assertNotIn(3, cands[0][3])
        self.assertNotIn(4, cands[0][3])
        
    def test_arrow_uniqueness_and_pruning(self):
        level = {
            "id": 999,
            "board": "0" * 81,
            "ruleType": "arrow",
            "arrows": [
                {
                    "bulb": [0, 0],
                    "line": [
                        [0, 1],
                        [0, 2],
                        [0, 3] # 3 cells in the same row/box -> must be unique
                    ]
                }
            ]
        }
        solver = HumanLogicSolver(level)
        cands = solver.candidates
        
        changed = solver._apply_arrow_rules()
        self.assertTrue(changed)
        
        # 1 pruned from bulb
        self.assertNotIn(1, cands[0][0])
        
        # 9 pruned from line
        self.assertNotIn(9, cands[0][1])
        self.assertNotIn(9, cands[0][2])
        self.assertNotIn(9, cands[0][3])
        
        # The line cells are in the same box, so they must be unique.
        # Min sum is 1+2+3 = 6.
        # So Bulb cannot be 2, 3, 4, or 5.
        self.assertNotIn(2, cands[0][0])
        self.assertNotIn(3, cands[0][0])
        self.assertNotIn(4, cands[0][0])
        self.assertNotIn(5, cands[0][0])
        self.assertIn(6, cands[0][0])

    def test_sandwich_combinatorics(self):
        level = {
            "id": 999,
            "board": "0" * 81,
            "ruleType": "sandwich",
            "sandwich_clues": {
                # Row 0 has a sandwich sum of 4.
                "row_sums": [4, -1, -1, -1, -1, -1, -1, -1, -1],
                "col_sums": [-1, -1, -1, -1, -1, -1, -1, -1, -1]
            }
        }
        solver = HumanLogicSolver(level)
        cands = solver.candidates
        
        # Set up a strict scenario for Row 0 where dist must be 1.
        # 1 is at 0,0 and 9 is at 0,2. The middle cell is 0,1.
        cands[0][0] = {1}
        cands[0][2] = {9}
        
        # Ensure that no OTHER cells in the row can be 1 or 9
        # so that (0,2) is the ONLY valid crust pair!
        for c in range(3, 9):
            cands[0][c].discard(1)
            cands[0][c].discard(9)
        
        changed = solver._apply_sandwich_rules()
        self.assertTrue(changed)
        
        # Since clue is 4, distance is 1, the ONLY valid candidate for 0,1 is 4.
        # 2,3,5,6,7,8 must be pruned from 0,1.
        self.assertNotIn(2, cands[0][1])
        self.assertNotIn(3, cands[0][1])
        self.assertIn(4, cands[0][1])
        self.assertNotIn(5, cands[0][1])
        self.assertNotIn(6, cands[0][1])
        self.assertNotIn(7, cands[0][1])
        self.assertNotIn(8, cands[0][1])

    def test_level_585_integration(self):
        level_585 = {
            "id": 585,
            "difficulty": "Insane",
            "ruleType": "arrow,sandwich,non-consecutive",
            "board": "000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "constraints": ["non-consecutive"],
            "arrows": [
                {"bulb": [3, 5], "line": [[4, 6], [3, 7], [2, 7]]},
                {"bulb": [5, 6], "line": [[6, 5], [7, 4], [6, 3]]},
                {"bulb": [0, 7], "line": [[1, 6], [0, 6], [0, 5], [1, 4]]},
                {"bulb": [6, 8], "line": [[6, 7], [7, 8], [8, 7]]},
                {"bulb": [0, 3], "line": [[0, 2], [1, 1], [2, 1]]}
            ],
            "sandwich_clues": {
                "row_sums": [20, 4, 15, 26, 0, -1, 0, 33, 28],
                "col_sums": [5, 0, 0, 8, 23, 4, 0, -1, 0]
            }
        }
        
        solver = HumanLogicSolver(level_585)
        # Expected to solve entirely by logic
        result = solver.solve()
        self.assertTrue(result, "Solver failed to completely resolve Level 585 using only logic.")

if __name__ == "__main__":
    unittest.main()
