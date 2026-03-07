import SwiftUI

struct KillerHelperView: View {
    let sum: Int
    let count: Int
    let rules: [SudokuRuleType]
    let cageCells: [[Int]]
    let markedCombinations: Set<[Int]>
    let onToggle: ([Int]) -> Void
    let onDismiss: () -> Void
    
    private var combinations: [[Int]] {
        let base = KillerMath.getCombinations(sum: sum, count: count, rules: rules, cageCells: cageCells)
        return base.sorted { c1, c2 in
            let s1 = markedCombinations.contains(c1)
            let s2 = markedCombinations.contains(c2)
            if s1 != s2 { return s1 } // Selected first
            
            // Consistent tie-breaker:
            // 1. Length Descending (usually same in Killer)
            if c1.count != c2.count { return c1.count > c2.count }
            // 2. Element-wise ascending
            for (v1, v2) in zip(c1, c2) {
                if v1 != v2 { return v1 < v2 }
            }
            return false
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dimmed Background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        onDismiss()
                    }
                
                // 2. Main Container
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(radius: 20)
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Killer Cage \(sum)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("\(count) cells")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: onDismiss) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        
                        Divider()
                        
                        if combinations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                    .foregroundColor(.orange)
                                Text("No valid combinations")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                        } else {
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(combinations, id: \.self) { combo in
                                        KillerCombinationRowView(
                                            combination: combo,
                                            isSelected: markedCombinations.contains(combo)
                                        ) {
                                            onToggle(combo)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .frame(maxHeight: geometry.size.height * 0.7)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .frame(width: 320)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
            }
        }
    }
}

private struct KillerCombinationRowView: View {
    let combination: [Int]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                ForEach(combination, id: \.self) { num in
                    KillerCombinationTokenView(number: num, isSelected: isSelected)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray.opacity(0.4))
                    .font(.title2)
            }
            .padding(12)
            .background(rowBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.green.opacity(0.05) : Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
            )
    }
}

private struct KillerCombinationTokenView: View {
    let number: Int
    let isSelected: Bool
    
    var body: some View {
        Text("\(number)")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.primary)
            .frame(width: 32, height: 32)
            .background(tokenBackground)
    }
    
    @ViewBuilder
    private var tokenBackground: some View {
        Circle()
            .fill(isSelected ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}
