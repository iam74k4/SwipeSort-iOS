//
//  TipJarView.swift
//  SwipeSort
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
                    VStack(spacing: 32) {
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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 32)
                }
            }
            .navigationTitle("開発者をサポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { tipStore.purchaseError != nil },
                set: { if !$0 { tipStore.purchaseError = nil } }
            )) {
                Button("OK") { tipStore.purchaseError = nil }
            } message: {
                Text(tipStore.purchaseError ?? "")
            }
            .alert("ありがとうございます！ 🎉", isPresented: $tipStore.showThankYou) {
                Button("閉じる") { dismiss() }
            } message: {
                Text("あなたのサポートに心から感謝します！\n開発のモチベーションになります。")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 20) {
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
                    .frame(width: 160, height: 160)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("SwipeSortを気に入っていただけましたか？")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("チップで開発者を応援できます。\nいただいたサポートは今後の開発に活用されます。")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("読み込み中...")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(height: 200)
    }
    
    // MARK: - Empty Products View
    
    private var emptyProductsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            
            Text("商品を読み込めませんでした")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            
            Button {
                Task { await tipStore.loadProducts() }
            } label: {
                Text("再試行")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 12)
            }
        }
        .frame(height: 200)
    }
    
    // MARK: - Tip Options
    
    private var tipOptionsView: some View {
        VStack(spacing: 12) {
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
        VStack(spacing: 8) {
            Text("チップは任意です")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            
            Text("チップなしでもすべての機能を\nご利用いただけます。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
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
            HStack(spacing: 16) {
                // Emoji
                Text(tipProduct?.emoji ?? "💝")
                    .font(.system(size: 32))
                    .frame(width: 48)
                
                // Name and description
                VStack(alignment: .leading, spacing: 4) {
                    Text(tipProduct?.displayName ?? product.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("開発者に感謝を伝える")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Price
                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
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
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
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
