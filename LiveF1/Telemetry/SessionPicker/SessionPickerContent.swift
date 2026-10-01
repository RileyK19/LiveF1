//
//  SessionPickerContent.swift
//  Redline
//
//  Created by Riley Koo on 9/30/26.
//

import SwiftUI

// MARK: - Protocol

/// Anything that can appear as a row in the session picker.
protocol PickableSession: Identifiable {
    var pickerTitle: String { get }          // e.g. "Japan"
    var pickerSubtitle: String { get }       // e.g. "Suzuka"
    var pickerTypeName: String { get }       // e.g. "Race", "Qualifying"
    var pickerDate: Date? { get }
    var pickerSearchStrings: [String] { get }
    /// nil = row is tappable. Non-nil = row is dimmed, disabled, and shows this as a badge
    /// (e.g. "In future", "Cancelled", "Unavailable").
    var pickerDisabledReason: String? { get }
}

extension PickableSession {
    var pickerDisabledReason: String? { nil }
}

// MARK: - Shared content

struct SessionPickerContent<Item: PickableSession>: View {
    let title: String
    let items: [Item]
    let isLoading: Bool
    let error: String?
    var errorFootnote: String? = nil
    var searchPrompt: String = "Search country or circuit"
    let onRetry: () -> Void
    let onSelect: (Item) -> Void

    @State private var searchText = ""
    @State private var selectedTypes: Set<String> = []   // empty = all

    private var availableTypes: [String] {
        Array(Set(items.map(\.pickerTypeName))).sorted()
    }

    private var filteredItems: [Item] {
        items
            .filter { selectedTypes.isEmpty || selectedTypes.contains($0.pickerTypeName) }
            .filter { item in
                searchText.isEmpty ||
                item.pickerSearchStrings.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading sessions...")
            } else if let error {
                VStack(spacing: 12) {
                    Text("Failed to load sessions").font(.headline)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    if let errorFootnote {
                        Text(errorFootnote).font(.caption2).foregroundStyle(.secondary)
                    }
                    Button("Retry", action: onRetry)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    if availableTypes.count > 1 { chipBar }

                    List(filteredItems) { item in
                        let isDisabled = item.pickerDisabledReason != nil
                        Button {
                            if !isDisabled { onSelect(item) }
                        } label: {
                            SessionRowContent(item: item)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: searchPrompt)
    }

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isSelected: selectedTypes.isEmpty) { selectedTypes = [] }
                ForEach(availableTypes, id: \.self) { type in
                    chip(type, isSelected: selectedTypes.contains(type)) {
                        if selectedTypes.contains(type) {
                            selectedTypes.remove(type)
                        } else {
                            selectedTypes.insert(type)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

struct SessionRowContent<Item: PickableSession>: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.pickerTitle).font(.headline)
                Spacer()
                Text(item.pickerTypeName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(sessionColor.opacity(0.15))
                    .foregroundStyle(sessionColor)
                    .clipShape(Capsule())
            }
            HStack {
                Text(item.pickerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let reason = item.pickerDisabledReason {
                    Spacer()
                    Text(reason)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
            }
            if let date = item.pickerDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .opacity(item.pickerDisabledReason == nil ? 1 : 0.4)
    }

    private var sessionColor: Color {
        switch item.pickerTypeName {
        case "Race": return .red
        case "Qualifying": return .blue
        case "Sprint": return .orange
        case "Sprint Qualifying", "Sprint Shootout": return .purple
        default: return .secondary // Practice 1/2/3, etc.
        }
    }
}
