import SwiftUI

struct RulesListView: View {
    let rules: [SudokuRuleType]
    var spacing: CGFloat = 6
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            // 1. Full Mode: Icon + Text
            HStack(spacing: spacing) {
                ForEach(rules, id: \.self) { rule in
                    SudokuRuleTagView(rule: rule, isCompact: false)
                }
            }
            
            // 2. Compact Mode: Icons Only
            HStack(spacing: spacing - 2) {
                ForEach(rules, id: \.self) { rule in
                    SudokuRuleTagView(rule: rule, isCompact: true)
                }
            }
            
            // 3. Fallback: Scrollable Icons Only (rare edge case for 8+ rules)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing - 2) {
                    ForEach(rules, id: \.self) { rule in
                        SudokuRuleTagView(rule: rule, isCompact: true)
                    }
                }
            }
        }
    }
}
