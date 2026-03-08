
import SwiftUI
import StoreKit
import MessageUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager()
    
    // Warning State
    @State private var showPotentialWarning = false
    @State private var pendingHighlightMode: HighlightMode?
    
    // Mail State
    @State private var showingMail = false
    @State private var mailResult: Result<MFMailComposeResult, Error>?
    @State private var showMailFallbackAlert = false
    
    @AppStorage("hintAppliesToSelectedCell") private var hintAppliesToSelectedCell: Bool = false
    
    private let supportEmail = "help.sudokuversa@gmail.com"
    
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
                    
                    Toggle("Disable Completed Digits", isOn: $settings.isDisableCompletedDigitsEnabled)
                    Toggle("Show Combination Helpers", isOn: $settings.isCombinationHelperEnabled)
                    Toggle("Auto-Filter Combinations", isOn: $settings.isAutoFilterCombinationsEnabled)
                    
                    Picker("Hint Target", selection: $hintAppliesToSelectedCell) {
                        Text("Random Cell").tag(false)
                        Text("Selected Cell").tag(true)
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
                    Button(action: {
                        if MFMailComposeViewController.canSendMail() {
                            showingMail = true
                        } else {
                            showMailFallbackAlert = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("Contact Us")
                                .foregroundColor(.primary)
                        }
                    }
                    
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
            .sheet(isPresented: $showingMail) {
                MailView(
                    result: $mailResult,
                    recipients: [supportEmail],
                    subject: "Sudoku Versa Feedback",
                    messageBody: supportEmailBody
                )
            }
            .alert("Cannot Send Email", isPresented: $showMailFallbackAlert) {
                Button("Copy Support Email") {
                    UIPasteboard.general.string = supportEmail
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your device is not configured to send emails. Please contact us at \(supportEmail).")
            }
        }
    }
    
    // MARK: - Email Support Help
    private var supportEmailBody: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.modelIdentifier
        
        return """
        
        
        
        ---------------------------------
        Technical details for support:
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(iosVersion)
        Device Model: \(deviceModel)
        """
    }
}

extension UIDevice {
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
