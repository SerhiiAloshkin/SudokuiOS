
import SwiftUI
import StoreKit

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager()
    
    // Warning State
    @State private var showPotentialWarning = false
    @State private var pendingHighlightMode: HighlightMode?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Highlight Mode")) {
                    Toggle("Minimal Highlight", isOn: $settings.isMinimalHighlight)
                    
                    if !settings.isMinimalHighlight {
                        Picker("Detailed Mode", selection: Binding<HighlightMode>(
                            get: { settings.highlightMode },
                            set: { newValue in
                                if newValue == .potential && !settings.hasSeenPotentialWarning {
                                    pendingHighlightMode = .potential
                                    showPotentialWarning = true
                                } else {
                                    settings.highlightMode = newValue
                                }
                            }
                        )) {
                            Text("Restriction").tag(HighlightMode.restriction)
                            Text("Potential").tag(HighlightMode.potential)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    if !settings.isMinimalHighlight && settings.highlightMode == .restriction {
                        Text("Highlights cells restricted by Sudoku rules relative to the selected cell (Row, Column, Box).")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else if !settings.isMinimalHighlight {
                        Text("Highlights valid empty spots for the selected number.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                         Text("Highlight only the selected cell.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Toggle("Highlight Same Number", isOn: $settings.isHighlightSameNumberEnabled)
                    Toggle("Highlight Same Note", isOn: $settings.isHighlightSameNoteEnabled)
                }
                
                Section(header: Text("Gameplay")) {
                    Picker("Show Mistakes", selection: $settings.mistakeMode) {
                        ForEach(MistakeMode.allCases, id: \.self) { mode in
                            Text(mode.text).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $settings.appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.text).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                }
                

                
                Section(header: Text("Support")) {
                    if storeManager.isAdsRemoved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ads Removed")
                        }
                    } else {
                        Button(action: {
                            Task {
                                await storeManager.purchaseRemoveAds()
                            }
                        }) {
                            HStack {
                                Text("Remove Ads")
                                Spacer()
                                if storeManager.isPurchasing {
                                    ProgressView()
                                } else {
                                    if let product = storeManager.products.first(where: { $0.id == "com.versa.removeads" }) {
                                        Text(product.displayPrice)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("$2.99")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Button("Restore Purchases") {
                            Task {
                                await storeManager.restorePurchases()
                            }
                        }
                    }
                }
                
                #if DEBUG
                Section(header: Text("Developer Tools")) {
                    Toggle("Unlock All Levels (Dev Only)", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "devAllUnlocked") },
                        set: { UserDefaults.standard.set($0, forKey: "devAllUnlocked") }
                    ))
                }
                #endif
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Are you sure?", isPresented: $showPotentialWarning) {
                Button("Activate Anyway", role: .destructive) {
                    if let mode = pendingHighlightMode {
                        settings.highlightMode = mode
                        settings.hasSeenPotentialWarning = true
                    }
                }
                Button("Keep it Off", role: .cancel) {
                    // Do nothing, picker reverts naturally as state wasn't updated
                    pendingHighlightMode = nil
                }
            } message: {
                Text("This mode highlights all valid positions for a number, which can make the game significantly easier. You might find the puzzles less challenging or lose interest more quickly. Do you still want to activate it?")
            }
        }
    }
}
