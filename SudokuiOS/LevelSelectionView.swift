import SwiftUI

struct LevelSelectionView: View {
    @EnvironmentObject var globalViewModel: LevelViewModel // The global data source
    @StateObject private var selectionViewModel = LevelSelectionViewModel() // Local filter state
    @StateObject private var adCoordinator = AdCoordinator() // Ad Manager
    @State private var showLegend = false
    @State private var hasScrolled = false
    
    @State private var selectedLevelForPreview: SudokuLevel?
    @State private var levelToPlay: SudokuLevel?
    @State private var navigateToGame = false
    
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var hasAutoOpened = false // Prevent re-triggering on return
    @State private var showGatekeeperAlert = false
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    @Binding var navigationStack: [MainMenuView.SudokuRoute]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Sticky Top Panel
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Progress Display
                VStack(spacing: 2) {
                    Text("Select Level")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    let solvedCount = selectionViewModel.filteredLevels.filter { $0.isSolved }.count
                    let totalCount = selectionViewModel.filteredLevels.count
                    Text("Solved: \(solvedCount) / \(totalCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Info Button
                Button(action: {
                    showLegend = true
                }) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
            .zIndex(1) // Ensure it shadows scroll content if needed
            
            // MARK: - Scrollable Grid
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(selectionViewModel.filteredLevels) { level in
                            LevelItemView(level: level, action: {
                                handleLevelTap(level)
                            })
                            .id(level.id)
                            // Removed .disabled(level.isLocked) to allow interaction for ads
                            .id(level.id) // Essential for scrolling
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80) // Space for bottom panel
                    // Hidden Navigation Link for Game
                    .padding(.bottom, 80) // Space for bottom panel

                    .animation(.default, value: selectionViewModel.currentFilter) // Smooth transition
                    .onAppear {
                        scrollToFirstUnsolved(proxy: proxy)
                    }
                    .onChange(of: selectionViewModel.currentFilter) { _, _ in
                        scrollToFirstUnsolved(proxy: proxy)
                    }
                    // Retrigger when data propagates (fixes initial open issue)
                    .onChange(of: selectionViewModel.filteredLevels.map { $0.id }) { _, _ in
                        if !hasScrolled {
                            scrollToFirstUnsolved(proxy: proxy)
                        }
                    }
                }
            }
            
            // MARK: - Sticky Bottom Panel (Filter)
            VStack {
                Divider()
                Button(action: {
                    withAnimation {
                        selectionViewModel.cycleFilter()
                        // Optional: Reset hasScrolled logic if we want to scroll on filter change? 
                        // User requirement: "upon opening".
                    }
                }) {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title2)
                        Text("Filter: \(selectionViewModel.currentFilter.rawValue)")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial) // Refined Background
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground))
        }
        .background(
            ZStack {
                Color(uiColor: .systemBackground)
                
                // Watermark
                Image(systemName: "cube.transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .opacity(0.03) // 3% Opacity
                    .rotationEffect(.degrees(-15))
            }
        )
        .navigationBarHidden(true)
        .onAppear {
            // Reset scroll state to ensure we scroll to next level upon return
            hasScrolled = false
            
            // Sync data from global VM to local VM
            selectionViewModel.updateLevels(globalViewModel.levels)
        }
        .onChange(of: globalViewModel.levels) { _, _ in
            selectionViewModel.updateLevels(globalViewModel.levels)
        }
        .sheet(isPresented: $showLegend) {
            LevelIconsInfoView()
                .presentationDetents([.large])
        }
        .sheet(item: $selectedLevelForPreview, onDismiss: {
            // Sequential Navigation: Only push AFTER sheet is dismissed
            if let level = levelToPlay {
                // Determine logic based on whether we are already in a game loop or menu
                // Here we simply append to the stack
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                     navigationStack.append(MainMenuView.SudokuRoute.game(level.id))
                }
                levelToPlay = nil // Reset
            }
        }) { level in
            LevelPreviewModal(level: level, viewModel: globalViewModel, adCoordinator: adCoordinator, onPlay: {
                // 1. Set Intent
                levelToPlay = level
                // 2. Dismiss Sheet (triggers onDismiss above)
                selectedLevelForPreview = nil
            }, onCancel: {
                levelToPlay = nil
                selectedLevelForPreview = nil
            })
            // .presentationDetents([.medium, .large])
        }
        .alert("Complete 1-250", isPresented: $showGatekeeperAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Complete all previous levels (1-250) to unlock the advanced series!")
        }
    }
}

struct LevelCardView: View {
    let level: SudokuLevel
    
    var body: some View {
        ZStack {
            // 1. Background Shape & Color
            if level.isLocked {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemGray6))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1) // Inner shadow simulation via drop shadow on content? No, need inner.
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.cyan]), // Slight gradient
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2) // Drop shadow for depth
            }
            
            // 2. Faint 3x3 Grid Overlay (on EVERY button per request)
            // Using a custom shape or standard lines
            LevelGridPattern()
                .stroke(gridLineColor, lineWidth: 1)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // 3. Level Number (Center)
            Text("\(level.id)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(numberColor)
                .shadow(color: level.isLocked ? .clear : .black.opacity(0.2), radius: 1, x: 0, y: 1) // Text shadow for active
            
            // 4. Corner Overlays
            VStack {
                HStack {
                    Spacer()
                    // Top-Right: Green Check (No white background)
                    if level.isSolved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green) // Pure green check
                            .font(.system(size: 16))
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.8)).padding(4)) // Added backing for visibility
                    }
                }
                Spacer()
                HStack {
                    // Bottom-Left: Variant Icons (Hybrid Support)
                    LevelIconView(level: level, iconColor: iconColor)
                    
                    Spacer()
                    
                    // Bottom-Right: Lock
                    if level.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(5)
                    }
                }
            }
        }
    }
    
    // -- Colors --
    var backgroundColor: Color {
        if level.isLocked {
            return Color(uiColor: .systemGray6) // Lighter gray like screenshot
        } else {
            return Color.blue // System Blue
        }
    }
    
    var numberColor: Color {
        // Locked: Dark Gray. Unlocked: White.
        level.isLocked ? .gray : .white
    }
    
    var iconColor: Color {
        // Based on screenshot, icons on Locked are Gray, on Unlocked are White-ish transparent
        level.isLocked ? .gray : .white.opacity(0.6)
    }
    
    var gridLineColor: Color {
        // Faint lines.
        // On Blue: White opacity. On Gray: Gray opacity.
        level.isLocked ? Color.gray.opacity(0.15) : Color.white.opacity(0.15)
    }
}

// Helper Shape for the 3x3 background grid
struct LevelGridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // 2 Vertical lines at 1/3 and 2/3
        path.move(to: CGPoint(x: w/3, y: 0))
        path.addLine(to: CGPoint(x: w/3, y: h))
        
        path.move(to: CGPoint(x: 2*w/3, y: 0))
        path.addLine(to: CGPoint(x: 2*w/3, y: h))
        
        // 2 Horizontal lines at 1/3 and 2/3
        path.move(to: CGPoint(x: 0, y: h/3))
        path.addLine(to: CGPoint(x: w, y: h/3))
        
        path.move(to: CGPoint(x: 0, y: 2*h/3))
        path.addLine(to: CGPoint(x: w, y: 2*h/3))
        
        return path
    }
}

extension LevelSelectionView {
    private func scrollToFirstUnsolved(proxy: ScrollViewProxy) {
        // Always try to find target
        if let targetID = selectionViewModel.firstUnsolvedLevelID {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(targetID, anchor: .top)
                }
            }
        } else {
            // Case: All Solved (or empty). Default to Top?
            // "If a filter has no unresolved levels, ensure the scroll logic defaults to the top"
            if let firstID = selectionViewModel.filteredLevels.first?.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                     withAnimation(.easeInOut(duration: 0.5)) {
                         proxy.scrollTo(firstID, anchor: .top)
                     }
                }
            }
        }
    }
    
    private func handleLevelTap(_ level: SudokuLevel) {
        if level.isLocked {
            if level.id == 251 {
                // Gatekeeper Interception
                showGatekeeperAlert = true
            } else if level.id <= 250 && !level.isSolved {
                // Ad Unlock Logic for 1-250
                selectedLevelForPreview = level
            } else {
                // Strictly Locked (Barrier > 250, but not 251 specifically)
                // or just default prevention, OR allow preview to see "Locked" state?
                // Logic says: if locked, show preview which handles ads/locks?
                // But specifically for > 250, we might want to allow "seeing" it but it's locked.
                // Replicating original logic:
                selectedLevelForPreview = level
            }
        } else {
            selectedLevelForPreview = level
        }
    }
}

struct LevelItemView: View {
    let level: SudokuLevel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            LevelCardView(level: level)
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

#Preview {
    LevelSelectionView(navigationStack: .constant([]))
        .environmentObject(LevelViewModel())
}

struct LevelIconView: View {
    let level: SudokuLevel
    let iconColor: Color
    
    // Compute rules outside of body to simplify ViewBuilder
    private var rules: [SudokuRuleType] {
        level.types.isEmpty ? [level.ruleType] : level.types
    }
    
    var body: some View {
        Group {
            if rules.count > 1 {
                // Multi-Icon Grid (2x2 max for now)
                HStack(spacing: 2) {
                    ForEach(Array(rules.prefix(4)), id: \.self) { rule in
                        SingleReviewIcon(rule: rule, size: 8)
                            .foregroundColor(iconColor)
                    }
                }
                .padding(4)
                .background(
                    Group {
                        if level.negative_constraint == true {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red.opacity(0.2))
                        }
                    }
                )
            } else {
                // Single Icon (Legacy Style or Single Hybrid)
                if let rule = rules.first {
                    SingleReviewIcon(rule: rule, size: 10)
                        .foregroundColor(iconColor)
                        .padding(5)
                        .background(
                            Group {
                                if level.negative_constraint == true {
                                    Circle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 20, height: 20)
                                }
                            }
                        )
                }
            }
        }
    }
}

struct SingleReviewIcon: View {
    let rule: SudokuRuleType
    let size: CGFloat
    
    var body: some View {
        Group {
            if rule == .kropki {
                HStack(spacing: size * 0.1) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: size * 0.6))
                    Image(systemName: "circle")
                        .font(.system(size: size * 0.6))
                }
            } else if rule == .knight {
                Image("knight_icon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: rule.iconName)
                    .font(.system(size: size))
            }
        }
    }
}
