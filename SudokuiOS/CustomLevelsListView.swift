import SwiftUI
import SwiftData

struct CustomLevelsListView: View {
    @Binding var navigationStack: [MainMenuView.SudokuRoute]
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomSudokuLevel.createdAt, order: .reverse) private var levels: [CustomSudokuLevel]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { navigationStack.removeLast() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("My Levels").font(.headline)
                Spacer()
                // Spacer to balance
                Color.clear.frame(width: 28, height: 28)
            }
            .padding()
            
            if levels.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No custom levels yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Create one with the Level Builder!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(levels) { level in
                        customLevelRow(level)
                    }
                    .onDelete(perform: deleteLevels)
                }
                .listStyle(.plain)
            }
        }
        .navigationBarHidden(true)
    }
    
    @ViewBuilder
    private func customLevelRow(_ level: CustomSudokuLevel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(level.levelName)
                    .font(.headline)
                
                HStack(spacing: 6) {
                    // Rule badges
                    Text(level.ruleType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(4)
                    
                    if level.isNonConsecutive {
                        Text("Non-Consec")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    if level.isKing {
                        Text("King")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    if level.isKnight {
                        Text("Knight")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                
                Text(level.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if level.isSolved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            // Edit button
            Button(action: {
                navigationStack.append(.levelBuilderEdit(level))
            }) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            navigationStack.append(.customGame(level))
        }
        .padding(.vertical, 4)
    }
    
    private func deleteLevels(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(levels[index])
        }
        try? modelContext.save()
    }
}
