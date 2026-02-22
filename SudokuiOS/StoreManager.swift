import SwiftUI
import StoreKit
import Combine

@MainActor
class StoreManager: ObservableObject {
    @AppStorage("isAdsRemoved") var isAdsRemoved: Bool = false
    
    @Published var products: [Product] = []
    @Published var isPurchasing: Bool = false
    @Published var purchaseError: String?
    
    private let productIds = ["com.versa.removeads"]
    private var updates: Task<Void, Never>? = nil
    
    init() {
        updates = newTransactionListenerTask()
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    func requestProducts() async {
        do {
            let products = try await Product.products(for: productIds)
            self.products = products
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    func purchaseRemoveAds() async {
        guard let product = products.first(where: { $0.id == "com.versa.removeads" }) else {
            purchaseError = "Product not found"
            return
        }
        
        isPurchasing = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isAdsRemoved = true
                isPurchasing = false
            case .userCancelled:
                isPurchasing = false
            case .pending:
                isPurchasing = false
            @unknown default:
                isPurchasing = false
            }
        } catch {
            isPurchasing = false
            purchaseError = error.localizedDescription
        }
    }
    
    func restorePurchases() async {
        isPurchasing = true
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
            isPurchasing = false
        } catch {
            isPurchasing = false
            purchaseError = error.localizedDescription
        }
    }
    
    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == "com.versa.removeads" {
                    isAdsRemoved = true
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
    }
    
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    if transaction.productID == "com.versa.removeads" {
                        await MainActor.run {
                            self.isAdsRemoved = true
                        }
                    }
                } catch {
                    print("Transaction verification failed")
                }
            }
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
