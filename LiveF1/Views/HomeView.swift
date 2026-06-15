//
//  HomeView.swift
//  LiveF1
//
//  Created by Riley Koo on 6/14/26.
//

import SwiftUI
import NotificationLog

// MARK: - Reusable Card Components

struct FeaturedCard: View {
    let icon: String
    let title: String
    let badge: String?
    let color: Color
    let height: CGFloat

    init(icon: String, title: String, badge: String? = nil, color: Color, height: CGFloat = 200) {
        self.icon = icon
        self.title = title
        self.badge = badge
        self.color = color
        self.height = height
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(color.opacity(0.09))
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(color.opacity(0.12), lineWidth: 1)
                )
            VStack(spacing: 12) {
                IconBadge(icon: icon, color: color, size: 64, iconSize: 26, cornerRadius: 18)

                Text(title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                if let badge {
                    LiveBadge(label: badge, color: color)
                }
            }
        }
    }
}

struct SquircleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(color.opacity(0.09))
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(color.opacity(0.12), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 0) {
                IconBadge(icon: icon, color: color, size: 52, iconSize: 22, cornerRadius: 14)
                    .padding(16)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(height: 140)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RowCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            IconBadge(icon: icon, color: color, size: 52, iconSize: 20, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(color.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Primitive Components

struct IconBadge: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let iconSize: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

struct LiveBadge: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .tracking(2)
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @StateObject private var store = F1SessionStore()
    @AppStorage("isDark") var isDark = false
    @State private var showingSettings = false
    @State private var mode: ContentView.AppMode = .live

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 4) {
                        Text("LiveF1")
                            .font(.system(size: 32, weight: .black, design: .serif))
                        Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1.5)
                    }
                    .padding(.top, 20)

                    // Featured Live card
                    NavigationLink { LiveConnectView(store: store) } label: {
                        FeaturedCard(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Live Timing",
                            badge: "ON AIR",
                            color: .red
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    // Two column grid
                    HStack(spacing: 14) {
                        NavigationLink { ReplayPickerView(store: store) } label: {
                            SquircleCard(icon: "arrow.counterclockwise.circle.fill", title: "Replay", subtitle: "Past sessions", color: .orange)
                        }
                        .buttonStyle(.plain)

                        NavigationLink { FIADocumentsView() } label: {
                            SquircleCard(icon: "doc.text.fill", title: "Documents", subtitle: "FIA bulletins", color: .blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    // Predictor row
                    NavigationLink { SessionPickerView() } label: {
                        RowCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Predictor",
                            subtitle: "Lap time & strategy forecasts",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Text("LiveF1 · Race Control")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    FeedbackButton()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(mode: $mode, store: store)
            }
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }
}

#Preview {
    HomeView()
}
