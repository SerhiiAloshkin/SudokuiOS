import SwiftUI

struct SandwichHelperView: View {
    let sum: Int
    let rules: [SudokuRuleType]
    let marked: Set<[Int]>
    let onToggle: ([Int]) -> Void
    let onDismiss: () -> Void
    
    // We compute combinations once on init or via computed property
    private var combinations: [[Int]] {
        let base = SandwichMath.getSandwichCombinations(for: sum, rules: rules)
        return base.sorted { c1, c2 in
            let s1 = marked.contains(c1)
            let s2 = marked.contains(c2)
            if s1 != s2 { return s1 } // Selected first
            
            // Following SandwichMath's original sorting logic for the rest:
            // 1. Length Descending
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
                    // Layer A: Static Background with Shadow
                    // We separate this so it doesn't redraw when 'marked' changes
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemBackground)) // Use system background for dark mode support
                        .shadow(radius: 20)
                    
                    // Layer B: Dynamic Content
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Combinations for \(sum)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: onDismiss) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1)) // Slightly lighter
                        
                        Divider()
                        
                        if combinations.isEmpty && sum != 0 {
                            Text("No combinations found.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(40)
                        } else if sum == 0 {
                             Text("Adjacent 1 and 9 (Empty)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(40)
                        } else {
                            // Scrollable List with Max Height
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(combinations, id: \.self) { combo in
                                        CombinationRowView(combination: combo, isSelected: marked.contains(combo)) {
                                            onToggle(combo)
                                        }
                                    }
                                }
                                .padding()
                            }
                            // Limit height to 70% of screen
                            .frame(maxHeight: geometry.size.height * 0.7)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16)) // Clip content to match background
                }
                .frame(width: 300) // Fixed width
                .fixedSize(horizontal: false, vertical: true)
                .padding()
            }
        }
    }
}

struct CombinationRowView: View {
    let combination: [Int]
    let isSelected: Bool
    let action: () -> Void
    
    // Dynamic Sizing Logic
    private var tokenSize: CGFloat {
        let count = combination.count
        if count <= 6 { return 32 }
        if count == 7 { return 28 }
        if count == 8 { return 24 }
        return 22 // 9 digits
    }
    
    private var fontSize: CGFloat {
        let count = combination.count
        if count <= 6 { return 16 }
        if count == 7 { return 14 }
        if count == 8 { return 12 }
        return 11 // 9 digits
    }
    
    private var tokenSpacing: CGFloat {
        return combination.count > 7 ? 4 : 8
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: tokenSpacing) {
                // Number Tokens
                ForEach(combination, id: \.self) { num in
                    CombinationTokenView(number: num, isSelected: isSelected, size: tokenSize, fontSize: fontSize)
                }
                
                Spacer()
                
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray.opacity(0.4))
                    .font(.title2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
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

struct CombinationTokenView: View {
    let number: Int
    let isSelected: Bool
    let size: CGFloat
    let fontSize: CGFloat
    
    var body: some View {
        Text("\(number)")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.primary)
            .frame(width: size, height: size)
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