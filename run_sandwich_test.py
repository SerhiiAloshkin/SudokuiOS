from logical_solver import HumanLogicSolver

level = {
    "id": 999,
    "board": "0" * 81,
    "ruleType": "sandwich",
    "sandwich_clues": {
        "row_sums": [4, -1, -1, -1, -1, -1, -1, -1, -1],
        "col_sums": [-1, -1, -1, -1, -1, -1, -1, -1, -1]
    }
}

solver = HumanLogicSolver(level)
solver.candidates[0][0] = {1}
solver.candidates[0][2] = {9}

solver._apply_sandwich_rules()
print(solver.candidates[0][1])
