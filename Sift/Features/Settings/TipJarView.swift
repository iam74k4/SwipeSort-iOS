//
//  TipJarView.swift
//  Sift
//
//  Tip jar view for supporting the developer
//

import SwiftUI
import StoreKit

@available(iOS 18.0, *)
struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tipStore = TipStore()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ThemeLayout.spacingSection) {
                        // Header
                        headerView
                        
                        // Tip options
                        if tipStore.isLoading && tipStore.products.isEmpty {
                            loadingView
                        } else if tipStore.products.isEmpty {
                            emptyProductsView
                        } else {
                            tipOptionsView
                        }
                        
                        // Footer message
                        footerView
                    }
                .padding(.horizontal, ThemeLayout.spacingItem)
                .padding(.vertical, ThemeLayout.spacingSection)
                }
            }
            .navigationTitle(NSLocalizedString("Support Developer", comment: "Support developer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("Close", comment: "Close button")) { dismiss() }
                }
            }
            .alert(NSLocalizedString("Purchase Failed", comment: "Purchase failed"), isPresented: Binding(
                get: { tipStore.purchaseError != nil },
                set: { if !$0 { tipStore.purchaseError = nil } }
            )) {
                Button(NSLocalizedString("OK", comment: "OK button")) { tipStore.purchaseError = nil }
            } message: {
                Text(tipStore.purchaseError ?? "")
            }
            .alert(NSLocalizedString("Thank You!", comment: "Thank you"), isPresented: $tipStore.showThankYou) {
                Button(NSLocalizedString("Close", comment: "Close button")) { dismiss() }
            } message: {
                Text(NSLocalizedString("Thank You Message", comment: "Thank you message"))
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: ThemeLayout.spacingLarge) {
            // Heart icon with gradient
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.pink.opacity(0.4), .orange.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: ThemeLayout.iconContainerXLarge, height: ThemeLayout.iconContainerXLarge)
                
                Image(systemName: "heart.fill")
                    .font(.themeIconXLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: ThemeLayout.paddingSmall) {
                Text(NSLocalizedString("Did You Like Sift?", comment: "Did you like Sift"))
                    .font(.themeDisplayValue.weight(.bold))
                    .foregroundStyle(Color.themePrimary)
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("Tip Message", comment: "Tip message"))
                    .font(.themeBody)
                    .foregroundStyle(Color.themeSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(ThemeLayout.lineSpacingDefault)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: ThemeLayout.spacingItem) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.themePrimary))
                .scaleEffect(ThemeLayout.scaleLoading)
            
            Text(NSLocalizedString("Loading...", comment: "Loading"))
                .font(.themeButtonSmall)
                .foregroundStyle(Color.themeTertiary)
        }
        .frame(height: ThemeLayout.loadingPlaceholderHeight)
    }
    
    // MARK: - Empty Products View
    
    private var emptyProductsView: some View {
        VStack(spacing: ThemeLayout.spacingItem) {
            Image(systemName: "exclamationmark.triangle")
                .font(.themeIconLarge)
                .foregroundStyle(.yellow)
            
            Text(NSLocalizedString("Failed to Load Products", comment: "Failed to load products"))
                .font(.themeRowTitle)
                .foregroundStyle(Color.themePrimary)
            
            Button {
                Task { await tipStore.loadProducts() }
            } label: {
                Text(NSLocalizedString("Retry", comment: "Retry button"))
                    .font(.themeBody.weight(.semibold))
                    .foregroundStyle(Color.themePrimary)
                    .padding(.horizontal, ThemeLayout.paddingLarge)
                    .padding(.vertical, ThemeLayout.spacingItem)
                    .glassCard(cornerRadius: ThemeLayout.cornerRadiusChip)
            }
        }
        .frame(height: ThemeLayout.loadingPlaceholderHeight)
    }
    
    // MARK: - Tip Options
    
    private var tipOptionsView: some View {
        VStack(spacing: ThemeLayout.spacingMediumLarge) {
            ForEach(tipStore.products, id: \.id) { product in
                TipButton(
                    product: product,
                    tipProduct: tipStore.tipProduct(for: product),
                    isLoading: tipStore.isLoading
                ) {
                    Task { await tipStore.purchase(product) }
                }
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        VStack(spacing: ThemeLayout.paddingSmall) {
            Text(NSLocalizedString("Tips are Optional", comment: "Tips are optional"))
                .font(.themeCaption)
                .foregroundStyle(Color.themeTertiary)
            
            Text(NSLocalizedString("All Features Available Without Tips", comment: "All features available without tips"))
                .font(.themeCaptionSecondary)
                .foregroundStyle(Color.themeTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Tip Button

@available(iOS 18.0, *)
struct TipButton: View {
    let product: Product
    let tipProduct: TipProduct?
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ThemeLayout.spacingItem) {
                // Emoji
                Text(tipProduct?.emoji ?? "💝")
                    .font(.themeIconLarge)
                    .frame(width: ThemeLayout.emojiContainerSize)
                
                // Name and description
                VStack(alignment: .leading, spacing: ThemeLayout.spacingCompact) {
                    Text(tipProduct?.displayName ?? product.displayName)
                        .font(.themeRowTitle.weight(.semibold))
                        .foregroundStyle(Color.themePrimary)
                    
                    Text(NSLocalizedString("Show Appreciation to Developer", comment: "Show appreciation to developer"))
                        .font(.themeCaptionSecondary)
                        .foregroundStyle(Color.themeSecondary)
                }
                
                Spacer()
                
                // Price
                Text(product.displayPrice)
                    .font(.themeRowTitle.weight(.bold))
                    .foregroundStyle(Color.themePrimary)
                    .padding(.horizontal, ThemeLayout.spacingItem)
                    .padding(.vertical, ThemeLayout.spacingSmall)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
            }
            .padding(ThemeLayout.spacingItem)
            .background {
                RoundedRectangle(cornerRadius: ThemeLayout.cornerRadiusButton, style: .continuous)
                    .fill(Color.primary.opacity(ThemeLayout.opacityLight))
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1.0)
    }
}

#Preview {
    if #available(iOS 18.0, *) {
        TipJarView()
    }
}
