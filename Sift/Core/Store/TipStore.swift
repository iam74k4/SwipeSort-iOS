//
//  TipStore.swift
//  Sift
//
//  StoreKit 2 based tip jar for supporting the developer
//

import Foundation
import StoreKit
import os

/// Tip product identifiers
enum TipProduct: String, CaseIterable {
    case small = "com.sift.tip.small"
    case medium = "com.sift.tip.medium"
    case large = "com.sift.tip.large"
    
    var displayName: String {
        switch self {
        case .small: return NSLocalizedString("Tip Small", comment: "Small tip name")
        case .medium: return NSLocalizedString("Tip Medium", comment: "Medium tip name")
        case .large: return NSLocalizedString("Tip Large", comment: "Large tip name")
        }
    }
    
    var emoji: String {
        switch self {
        case .small: return "☕"
        case .medium: return "🍰"
        case .large: return "🍽️"
        }
    }
}

/// StoreKit 2 tip store
@MainActor
@Observable
final class TipStore {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.sift", category: "TipStore")
    
    // MARK: - State
    
    var products: [Product] = []
    var isLoading = false
    var purchaseError: String?
    var showThankYou = false
    
    // MARK: - Private
    
    private var loadTask: Task<Void, Never>?
    private var transactionListenerTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        loadTask = Task {
            await loadProducts()
        }
        
        // Listen for transaction updates (Ask to Buy, interrupted purchases, etc.)
        transactionListenerTask = Task {
            await listenForTransactions()
        }
    }
    
    /// Cancel ongoing tasks
    func cleanup() {
        loadTask?.cancel()
        transactionListenerTask?.cancel()
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates from App Store
    /// Handles Ask to Buy approvals, interrupted purchases, and other async transactions
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await transaction.finish()
                showThankYou = true
                logger.info("Transaction update verified: \(transaction.productID)")
            case .unverified(let transaction, let error):
                logger.error("Transaction update unverified: \(transaction.productID), error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        
        do {
            let productIDs = TipProduct.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort by price
            products = storeProducts.sorted { $0.price < $1.price }
            
            logger.info("Loaded \(storeProducts.count) tip products")
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            purchaseError = NSLocalizedString("Failed to Load Products", comment: "Failed to load products")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async {
        // Prevent double purchases
        guard !isLoading else { return }
        
        isLoading = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                switch verification {
                case .verified(let transaction):
                    // Transaction is verified, finish it
                    await transaction.finish()
                    showThankYou = true
                    logger.info("Tip purchased successfully: \(product.id)")
                    
                case .unverified(_, let error):
                    logger.error("Transaction unverified: \(error.localizedDescription)")
                    purchaseError = NSLocalizedString("Purchase Verification Failed", comment: "Purchase verification failed")
                }
                
            case .userCancelled:
                logger.info("User cancelled purchase")
                
            case .pending:
                logger.info("Purchase pending")
                purchaseError = NSLocalizedString("Purchase Pending", comment: "Purchase pending")
                
            @unknown default:
                logger.warning("Unknown purchase result")
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            purchaseError = String(format: NSLocalizedString("Purchase Failed: %@", comment: "Purchase failed with error"), error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    func tipProduct(for product: Product) -> TipProduct? {
        TipProduct(rawValue: product.id)
    }
}
