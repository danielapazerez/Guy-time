import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: FeedingStore
    @State private var showBottle = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 6) {
                            Text("עברו")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(elapsedText(at: context.date))
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("מאז ההאכלה האחרונה")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
                    }

                    HStack(spacing: 16) {
                        NursingButton(side: .right, color: .pink)
                        NursingButton(side: .left, color: .green)
                    }

                    Button {
                        showBottle = true
                    } label: {
                        Label("בקבוק", systemImage: "waterbottle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button {
                        store.toggleVitaminD()
                    } label: {
                        HStack {
                            Image(systemName: store.vitaminDTakenToday ? "checkmark.circle.fill" : "drop.fill")
                            Text("ויטמין D")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.vitaminDTakenToday ? .green : .orange)
                }
                .padding()
            }
            .navigationTitle("Guy Time")
            .sheet(isPresented: $showBottle) { BottleEntryView() }
        }
    }

    private func elapsedText(at now: Date) -> String {
        guard let last = store.lastFeedingDate else { return "—" }
        let interval = max(0, Int(now.timeIntervalSince(last)))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

private struct NursingButton: View {
    @EnvironmentObject private var store: FeedingStore
    let side: FeedingSide
    let color: Color

    var isActive: Bool { store.activeNursing?.side == side }
    var isLast: Bool { store.lastNursingSide == side }

    var body: some View {
        Button {
            store.toggleNursing(side: side)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: isActive ? "pause.fill" : "heart.fill")
                    .font(.system(size: 34))
                Text(side.rawValue)
                    .font(.title3.bold())
                if isActive {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(durationText(now: context.date))
                            .font(.headline.monospacedDigit())
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .background(color.opacity(isActive ? 0.95 : 0.17), in: RoundedRectangle(cornerRadius: 26))
            .foregroundStyle(isActive ? .white : color)
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .stroke(isLast ? color : .clear, lineWidth: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private func durationText(now: Date) -> String {
        guard let started = store.activeNursing?.startedAt else { return "00:00" }
        let seconds = max(0, Int(now.timeIntervalSince(started)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct BottleEntryView: View {
    @EnvironmentObject private var store: FeedingStore
    @Environment(\.dismiss) private var dismiss
    @State private var type: BottleType = .expressed
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("סוג", selection: $type) {
                    ForEach(BottleType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("כמות במ״ל", text: $amount)
                    .keyboardType(.numberPad)
                    .font(.title2)
            }
            .navigationTitle("בקבוק")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ביטול") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמירה") {
                        store.addBottle(type: type, milliliters: Int(amount) ?? 0)
                        dismiss()
                    }
                    .disabled((Int(amount) ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
