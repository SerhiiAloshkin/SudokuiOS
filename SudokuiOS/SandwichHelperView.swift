import SwiftUI

struct SandwichHelperView: View {
    let sum: Int
    let marked: Set<[Int]>
    let onToggle: ([Int]) -> Void
    let onDismiss: () -> Void
    
    // We compute combinations once on init or via computed property
    var combinations: [[Int]] {
        SandwichMath.getSandwichCombinations(for: sum)
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
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Number Tokens
                ForEach(combination, id: \.self) { num in
                    CombinationTokenView(number: num, isSelected: isSelected)
                }
                
                Spacer()
                
                // Checkbox
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

struct CombinationTokenView: View {
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