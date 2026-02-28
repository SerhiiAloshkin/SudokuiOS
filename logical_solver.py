import json
import sys

class HumanLogicSolver:
    def __init__(self, level_data):
        self.level_data = level_data
        self.candidates = [[set(range(1, 10)) for _ in range(9)] for _ in range(9)]
        
        board_str = self.level_data.get("board", "0"*81)
        for i, char in enumerate(board_str):
            if char != '0':
                r, c = i // 9, i % 9
                self.candidates[r][c] = {int(char)}
                
        self.rules = self.level_data.get("ruleType", "")
        self.constraints = self.level_data.get("constraints", [])

    def get_neighbors(self, r, c):
        neighbors = []
        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < 9 and 0 <= nc < 9:
                neighbors.append((nr, nc))
        return neighbors

    def get_houses(self, r, c):
        houses = []
        houses.append([(r, ic) for ic in range(9)])
        houses.append([(ir, c) for ir in range(9)])
        br, bc = (r // 3) * 3, (c // 3) * 3
        houses.append([(br + i // 3, bc + i % 3) for i in range(9)])
        return houses

    def get_knight_moves(self, r, c):
        moves = []
        for dr, dc in [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < 9 and 0 <= nc < 9:
                moves.append((nr, nc))
        return moves

    def get_king_moves(self, r, c):
        moves = []
        for dr in [-1, 0, 1]:
            for dc in [-1, 0, 1]:
                if dr == 0 and dc == 0: continue
                nr, nc = r + dr, c + dc
                if 0 <= nr < 9 and 0 <= nc < 9:
                    moves.append((nr, nc))
        return moves

    def remove_candidate(self, r, c, val):
        if val in self.candidates[r][c]:
            self.candidates[r][c].remove(val)
            return True
        return False

    def _apply_classic_rules(self):
        import itertools
        changed = False
        
        # 1. Naked Singles
        for r in range(9):
            for c in range(9):
                if len(self.candidates[r][c]) == 1:
                    val = list(self.candidates[r][c])[0]
                    for house in self.get_houses(r, c):
                        for hr, hc in house:
                            if (hr, hc) != (r, c):
                                if self.remove_candidate(hr, hc, val): changed = True

        # 2. Hidden Singles
        for r in range(9):
            for c in range(9):
                if len(self.candidates[r][c]) > 1:
                    found_hidden = False
                    for val in list(self.candidates[r][c]):
                        for house in self.get_houses(r, c):
                            count = sum(1 for hr, hc in house if val in self.candidates[hr][hc])
                            if count == 1:
                                if len(self.candidates[r][c]) > 1:
                                    self.candidates[r][c] = {val}
                                    changed = True
                                    found_hidden = True
                                break
                        if found_hidden: break

        # 3. Naked Pairs
        for r in range(9):
            for c in range(9):
                if len(self.candidates[r][c]) == 2:
                    pair = self.candidates[r][c]
                    for house in self.get_houses(r, c):
                        # Find other cells in the same house with the EXACT same pair
                        match_cells = [(hr, hc) for hr, hc in house if self.candidates[hr][hc] == pair]
                        if len(match_cells) == 2:
                            # Remove these two values from all OTHER cells in the house
                            for hr, hc in house:
                                if (hr, hc) not in match_cells:
                                    for val in pair:
                                        if self.remove_candidate(hr, hc, val): changed = True

        # 4. Pointing Pairs / Box-Line Reduction
        for br in range(3):
            for bc in range(3):
                box_cells = [(br * 3 + i // 3, bc * 3 + i % 3) for i in range(9)]
                for val in range(1, 10):
                    cells_with_val = [(r, c) for r, c in box_cells if val in self.candidates[r][c]]
                    if len(cells_with_val) >= 2:
                        # Check if they share a row
                        if all(r == cells_with_val[0][0] for r, c in cells_with_val):
                            row = cells_with_val[0][0]
                            for c in range(9):
                                if (row, c) not in box_cells:
                                    if self.remove_candidate(row, c, val): changed = True
                        # Check if they share a column
                        if all(c == cells_with_val[0][1] for r, c in cells_with_val):
                            col = cells_with_val[0][1]
                            for r in range(9):
                                if (r, col) not in box_cells:
                                    if self.remove_candidate(r, col, val): changed = True

        # 5. Naked Triples & Hidden Pairs
        houses_list = []
        for i in range(9):
            houses_list.append([(i, j) for j in range(9)]) # rows
            houses_list.append([(j, i) for j in range(9)]) # cols
        for br in range(3):
            for bc in range(3):
                houses_list.append([(br * 3 + i // 3, bc * 3 + i % 3) for i in range(9)]) # boxes

        for house in houses_list:
            # Naked Triples
            possible_cells = [(hr, hc) for hr, hc in house if 2 <= len(self.candidates[hr][hc]) <= 3]
            if len(possible_cells) >= 3:
                for triple in itertools.combinations(possible_cells, 3):
                    union_cands = set()
                    for tr, tc in triple:
                        union_cands.update(self.candidates[tr][tc])
                    if len(union_cands) == 3:
                        for hr, hc in house:
                            if (hr, hc) not in triple:
                                for val in union_cands:
                                    if self.remove_candidate(hr, hc, val): changed = True
                                    
            # Hidden Pairs
            for val1, val2 in itertools.combinations(range(1, 10), 2):
                cells_with_val1 = [(hr, hc) for hr, hc in house if val1 in self.candidates[hr][hc]]
                cells_with_val2 = [(hr, hc) for hr, hc in house if val2 in self.candidates[hr][hc]]
                if len(cells_with_val1) == 2 and cells_with_val1 == cells_with_val2:
                    for hr, hc in cells_with_val1:
                        cands_to_remove = set(self.candidates[hr][hc]) - {val1, val2}
                        for v in cands_to_remove:
                            if self.remove_candidate(hr, hc, v): changed = True

        return changed

    def _apply_knight_rules(self):
        changed = False
        if "knight" not in self.rules and "knight" not in self.constraints and "anti-knight" not in self.rules and "anti-knight" not in self.constraints:
            return False
        for r in range(9):
            for c in range(9):
                if len(self.candidates[r][c]) == 1:
                    val = list(self.candidates[r][c])[0]
                    for nr, nc in self.get_knight_moves(r, c):
                        if self.remove_candidate(nr, nc, val): changed = True
        return changed

    def _apply_king_rules(self):
        changed = False
        if "king" not in self.rules and "king" not in self.constraints and "anti-king" not in self.rules and "anti-king" not in self.constraints:
            return False
        for r in range(9):
            for c in range(9):
                if len(self.candidates[r][c]) == 1:
                    val = list(self.candidates[r][c])[0]
                    for nr, nc in self.get_king_moves(r, c):
                        if self.remove_candidate(nr, nc, val): changed = True
        return changed

    def _apply_non_consecutive_rules(self):
        changed = False
        if "non-consecutive" not in self.rules and "non-consecutive" not in self.constraints:
            return False
        for r in range(9):
            for c in range(9):
                if len(self.candidates[r][c]) == 1:
                    val = list(self.candidates[r][c])[0]
                    for nr, nc in self.get_neighbors(r, c):
                        if self.remove_candidate(nr, nc, val - 1): changed = True
                        if self.remove_candidate(nr, nc, val + 1): changed = True
                else:
                    for nr, nc in self.get_neighbors(r, c):
                        neighbor_cands = self.candidates[nr][nc]
                        for v in list(self.candidates[r][c]):
                            if not any(abs(v - nv) != 1 for nv in neighbor_cands):
                                if self.remove_candidate(r, c, v): changed = True
        return changed

    def _apply_thermo_rules(self):
        changed = False
        thermoPaths = self.level_data.get("thermoPaths", [])
        for path in thermoPaths:
            for i in range(1, len(path)):
                r_prev, c_prev = path[i-1]
                r_curr, c_curr = path[i]
                if not self.candidates[r_prev][c_prev]: continue
                min_prev = min(self.candidates[r_prev][c_prev])
                for v in list(self.candidates[r_curr][c_curr]):
                    if v <= min_prev:
                        if self.remove_candidate(r_curr, c_curr, v): changed = True
            for i in range(len(path)-2, -1, -1):
                r_curr, c_curr = path[i]
                r_next, c_next = path[i+1]
                if not self.candidates[r_next][c_next]: continue
                max_next = max(self.candidates[r_next][c_next])
                for v in list(self.candidates[r_curr][c_curr]):
                    if v >= max_next:
                        if self.remove_candidate(r_curr, c_curr, v): changed = True
        return changed

    def _apply_arrow_rules(self):
        changed = False
        for arrow in self.level_data.get("arrows", []):
            bulb_r, bulb_c = arrow["bulb"]
            line = arrow["line"]
            
            if not self.candidates[bulb_r][bulb_c]: continue
            if any(not self.candidates[lr][lc] for lr, lc in line): continue
            
            valid_bulb = set()
            valid_line = [set() for _ in line]
            line_vals = [0] * len(line)
            max_bulb = max(self.candidates[bulb_r][bulb_c])
            
            def dfs(idx, current_sum):
                if current_sum > max_bulb: return False
                if idx == len(line):
                    if current_sum in self.candidates[bulb_r][bulb_c]:
                        valid_bulb.add(current_sum)
                        return True
                    return False
                    
                lr, lc = line[idx]
                found_any = False
                for v in self.candidates[lr][lc]:
                    if v == 9: continue
                    collision = False
                    for p_idx in range(idx):
                        if line_vals[p_idx] == v:
                            pr, pc = line[p_idx]
                            if pr == lr or pc == lc or (pr//3 == lr//3 and pc//3 == lc//3):
                                collision = True
                                break
                    if collision: continue
                    
                    line_vals[idx] = v
                    if dfs(idx + 1, current_sum + v):
                        valid_line[idx].add(v)
                        found_any = True
                return found_any
            dfs(0, 0)
            
            for v in list(self.candidates[bulb_r][bulb_c]):
                if v not in valid_bulb:
                    if self.remove_candidate(bulb_r, bulb_c, v): changed = True
            for i, (lr, lc) in enumerate(line):
                for v in list(self.candidates[lr][lc]):
                    if v not in valid_line[i]:
                        if self.remove_candidate(lr, lc, v): changed = True
        return changed

    def _apply_killer_rules(self):
        changed = False
        cages = self.level_data.get("cages", [])
        for cage in cages:
            target = cage.get("sum", 0)
            cells = cage.get("cells", [])
            if not target or not cells: continue
            if any(not self.candidates[r][c] for r, c in cells): continue
            
            for i, (cr, cc) in enumerate(cells):
                other_min_sum = sum(min(self.candidates[or_r][or_c]) for j, (or_r, or_c) in enumerate(cells) if i != j)
                for v in list(self.candidates[cr][cc]):
                    if v + other_min_sum > target:
                        if self.remove_candidate(cr, cc, v): changed = True
                        
            for i, (cr, cc) in enumerate(cells):
                other_max_sum = sum(max(self.candidates[or_r][or_c]) for j, (or_r, or_c) in enumerate(cells) if i != j)
                for v in list(self.candidates[cr][cc]):
                    if v + other_max_sum < target:
                        if self.remove_candidate(cr, cc, v): changed = True
                        
            for i, (cr, cc) in enumerate(cells):
                if len(self.candidates[cr][cc]) == 1:
                    val = list(self.candidates[cr][cc])[0]
                    for j, (or_r, or_c) in enumerate(cells):
                        if i != j:
                            if self.remove_candidate(or_r, or_c, val): changed = True
        return changed

    def _apply_odd_even_rules(self):
        changed = False
        parity_str = self.level_data.get("parity", "")
        if not parity_str:
            return False
            
        for i, char in enumerate(parity_str):
            if i >= 81: break
            r, c = i // 9, i % 9
            if char == '1':
                for v in [2, 4, 6, 8]:
                    if self.remove_candidate(r, c, v): changed = True
            elif char == '2':
                for v in [1, 3, 5, 7, 9]:
                    if self.remove_candidate(r, c, v): changed = True
        return changed

    def _apply_kropki_rules(self):
        changed = False
        white_dots = self.level_data.get("white_dots", [])
        black_dots = self.level_data.get("black_dots", [])
        negative = self.level_data.get("negative_constraint", False)
        
        def apply_dot(dot_list, relation_fn):
            c = False
            for d in dot_list:
                (r1, c1), (r2, c2) = d[0], d[1]
                if not self.candidates[r1][c1] or not self.candidates[r2][c2]: continue
                
                cands1 = self.candidates[r1][c1]
                cands2 = self.candidates[r2][c2]
                
                for v1 in list(cands1):
                    if not any(relation_fn(v1, v2) for v2 in cands2):
                        if self.remove_candidate(r1, c1, v1): c = True
                for v2 in list(cands2):
                    if not any(relation_fn(v1, v2) for v1 in cands1):
                        if self.remove_candidate(r2, c2, v2): c = True
            return c
            
        if apply_dot(white_dots, lambda a, b: abs(a - b) == 1): changed = True
        if apply_dot(black_dots, lambda a, b: a == 2*b or b == 2*a): changed = True
        
        if negative:
            wd_set = set()
            bd_set = set()
            for d in white_dots:
                wd_set.add((tuple(d[0]), tuple(d[1])))
                wd_set.add((tuple(d[1]), tuple(d[0])))
            for d in black_dots:
                bd_set.add((tuple(d[0]), tuple(d[1])))
                bd_set.add((tuple(d[1]), tuple(d[0])))
                
            for r in range(9):
                for c in range(9):
                    for nr, nc in self.get_neighbors(r, c):
                        p1 = (r, c)
                        p2 = (nr, nc)
                        if p1 < p2:
                            has_white = (p1, p2) in wd_set
                            has_black = (p1, p2) in bd_set
                            
                            cands1 = self.candidates[r][c]
                            cands2 = self.candidates[nr][nc]
                            
                            if not has_white:
                                for v1 in list(cands1):
                                    if all(abs(v1 - v2) == 1 for v2 in cands2):
                                        if self.remove_candidate(r, c, v1): changed = True
                                for v2 in list(cands2):
                                    if all(abs(v1 - v2) == 1 for v1 in cands1):
                                        if self.remove_candidate(nr, nc, v2): changed = True
                                        
                            if not has_black:
                                for v1 in list(cands1):
                                    if all(v1 == 2*v2 or v2 == 2*v1 for v2 in cands2):
                                        if self.remove_candidate(r, c, v1): changed = True
                                for v2 in list(cands2):
                                    if all(v1 == 2*v2 or v2 == 2*v1 for v1 in cands1):
                                        if self.remove_candidate(nr, nc, v2): changed = True
        return changed

    def get_sandwich_combinations(self, target):
        if hasattr(self, 'sandwich_combo_cache') and target in self.sandwich_combo_cache:
            return self.sandwich_combo_cache[target]
            
        candidates = [2, 3, 4, 5, 6, 7, 8]
        results = []
        def find_combos(remainder, current, start_idx):
            if remainder == 0:
                results.append(set(current))
                return
            if remainder < 0: return
            for i in range(start_idx, len(candidates)):
                find_combos(remainder - candidates[i], current + [candidates[i]], i + 1)
        find_combos(target, [], 0)
        
        if not hasattr(self, 'sandwich_combo_cache'):
            self.sandwich_combo_cache = {}
        self.sandwich_combo_cache[target] = results
        return results

    def _apply_sandwich_rules(self):
        changed = False
        row_clues = self.level_data.get("sandwich_clues", {}).get("row_sums", [])
        col_clues = self.level_data.get("sandwich_clues", {}).get("col_sums", [])
        if not row_clues or not col_clues: return False
        
        def process_sandwich(house_cells, clue):
            if clue == -1 or clue is None: return False
            internal_changed = False
            
            all_combos = self.get_sandwich_combinations(clue)
            outside_clue = 35 - clue
            outside_combos = self.get_sandwich_combinations(outside_clue)
            
            valid_scenarios = []
            for i in range(9):
                for j in range(i + 1, 9):
                    r1, c1 = house_cells[i]
                    r2, c2 = house_cells[j]
                    dist = j - i - 1
                    
                    v_combos = [c for c in all_combos if len(c) == dist]
                    v_out = [c for c in outside_combos if len(c) == 7 - dist]
                    
                    if not v_combos or not v_out: continue
                        
                    i_1 = 1 in self.candidates[r1][c1]
                    i_9 = 9 in self.candidates[r1][c1]
                    j_1 = 1 in self.candidates[r2][c2]
                    j_9 = 9 in self.candidates[r2][c2]
                    
                    if (i_1 and j_9) or (i_9 and j_1):
                        valid_scenarios.append((i, j, v_combos, v_out))
            if not valid_scenarios: return False
            for idx in range(9):
                r, c = house_cells[idx]
                allowed_values = set()
                
                for start_idx, end_idx, v_combos, v_out_combos in valid_scenarios:
                    r1, c1 = house_cells[start_idx]
                    r2, c2 = house_cells[end_idx]
                    i_1 = 1 in self.candidates[r1][c1]
                    i_9 = 9 in self.candidates[r1][c1]
                    j_1 = 1 in self.candidates[r2][c2]
                    j_9 = 9 in self.candidates[r2][c2]
                    
                    if idx == start_idx:
                        if i_1 and j_9: allowed_values.add(1)
                        if i_9 and j_1: allowed_values.add(9)
                    elif idx == end_idx:
                        if i_1 and j_9: allowed_values.add(9)
                        if i_9 and j_1: allowed_values.add(1)
                    elif start_idx < idx < end_idx:
                        for combo in v_combos: allowed_values.update(combo)
                    else:
                        for combo in v_out_combos: allowed_values.update(combo)
                            
                for v in list(self.candidates[r][c]):
                    if v not in allowed_values:
                        if self.remove_candidate(r, c, v): internal_changed = True
            return internal_changed
        for r in range(9):
            if process_sandwich([(r, c) for c in range(9)], row_clues[r]): changed = True
        for c in range(9):
            if process_sandwich([(r, c) for r in range(9)], col_clues[c]): changed = True
        return changed

    def solve(self):
        pass_num = 1
        while True:
            changed = False
            
            if self._apply_classic_rules(): changed = True
            if self._apply_knight_rules(): changed = True
            if self._apply_king_rules(): changed = True
            if self._apply_non_consecutive_rules(): changed = True
            if self._apply_thermo_rules(): changed = True
            if self._apply_arrow_rules(): changed = True
            if self._apply_killer_rules(): changed = True
            if self._apply_odd_even_rules(): changed = True
            if self._apply_kropki_rules(): changed = True
            if self._apply_sandwich_rules(): changed = True
            
            resolved_count = sum(1 for r in range(9) for c in range(9) if len(self.candidates[r][c]) == 1)
            print(f"Pass {pass_num}: {resolved_count}/81 cells resolved.")
            
            if resolved_count == 81:
                print("✅ HUMAN SOLVABLE: Solved entirely by logic!")
                self.print_board()
                return True
            
            if not changed:
                print("❌ REQUIRES GUESSING: Got stuck. Not human-solvable with basic constraints.")
                print("Stuck board state:")
                self.print_board()
                return False
                
            pass_num += 1

    def print_board(self):
        print("-" * 19)
        for r in range(9):
            row_str = ""
            for c in range(9):
                if len(self.candidates[r][c]) == 1:
                    row_str += str(list(self.candidates[r][c])[0]) + " "
                else:
                    row_str += ". "
            print(row_str.strip())
        print("-" * 19)

if __name__ == "__main__":
    # 1. Check if the user provided an argument in the terminal
    if len(sys.argv) < 2:
        print("Usage: python logical_solver.py <level_number>")
        print("Example: python logical_solver.py 582")
        sys.exit(1) # Exit with an error code
        
    # 2. Try to convert the argument to an integer
    try:
        LEVEL_ID_TO_TEST = int(sys.argv[1])
    except ValueError:
        print("Error: The level number must be a valid integer.")
        sys.exit(1)

    # 3. Path to your master levels file
    file_path = "SudokuiOS/Levels.json" 

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            all_levels = json.load(f)
        
        # Search for the level
        target_level = None
        for level in all_levels:
            if level.get("id") == LEVEL_ID_TO_TEST:
                target_level = level
                break
        
        # Run the solver if found
        if target_level:
            print(f"Testing Level {target_level['id']} (Rules: {target_level.get('ruleType', 'classic')})...")
            solver = HumanLogicSolver(target_level)
            solver.solve()
        else:
            print(f"Error: Level {LEVEL_ID_TO_TEST} was not found in {file_path}.")

    except FileNotFoundError:
        print(f"Error: Could not find the file at {file_path}. Make sure you are in the correct directory.")