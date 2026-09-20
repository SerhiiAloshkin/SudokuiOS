import SwiftUI

struct SudokuRuleTagView: View {
    let rule: SudokuRuleType
    let isCompact: Bool
    var showColor: Bool = true
    var body: some View {
        HStack(spacing: 4) {
            ruleIcon

            if !isCompact {
                // rule.shortName is a plain English catalog key (see SudokuRuleType.swift) —
                // wrapping it in LocalizedStringKey (not passing it to Text(_:) directly) makes
                // SwiftUI resolve it against the current .environment(\.locale) automatically,
                // the one mechanism confirmed to actually track the in-app language switcher.
                // .textCase(.uppercase) uppercases the rendered text instead of the raw key, so
                // it still works correctly after translation.
                Text(LocalizedStringKey(rule.shortName))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, isCompact ? 5 : 6)
        .padding(.vertical, 2)
        .background(tagColor.opacity(showColor ? 0.15 : 0.05))
        .foregroundColor(showColor ? tagColor : .primary.opacity(0.8))
        .cornerRadius(4)
    }
    
    @ViewBuilder
    private var ruleIcon: some View {
        if rule == .kropki {
            HStack(spacing: 1) {
                Image(systemName: "circle.fill").font(.system(size: isCompact ? 8 : 7))
                Image(systemName: "circle").font(.system(size: isCompact ? 8 : 7))
            }
        } else if rule == .knight {
            Image("knight_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: isCompact ? 13 : 11, height: isCompact ? 13 : 11)
        } else {
            Image(systemName: rule.iconName)
                .font(.system(size: isCompact ? 13 : 10, weight: .bold))
        }
    }
    
    private var tagColor: Color {
        switch rule {
        case .classic: return .blue
        case .nonConsecutive: return .orange
        case .king: return .purple
        case .knight: return .green
        case .thermo: return .gray
        case .arrow: return .blue
        case .killer: return .red
        case .kropki: return .primary
        case .sandwich: return .yellow
        case .oddEven: return .cyan
        }
    }
}
