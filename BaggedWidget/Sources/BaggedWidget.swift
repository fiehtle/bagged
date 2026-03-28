import SwiftUI
import WidgetKit
import BaggedShared

struct BaggedEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct BaggedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BaggedEntry {
        BaggedEntry(date: .now, snapshot: WidgetSnapshot(
            nearbyEntries: [
                WidgetPlaceEntry(id: UUID(), title: "The Shota", subtitle: "SoMa, San Francisco", category: .food, distanceMeters: 900),
                WidgetPlaceEntry(id: UUID(), title: "Pinhole Coffee", subtitle: "Bernal Heights", category: .coffee, distanceMeters: 1_600),
                WidgetPlaceEntry(id: UUID(), title: "The Interval", subtitle: "Marina", category: .sights, distanceMeters: 2_300)
            ]
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (BaggedEntry) -> Void) {
        let snapshot = AppDataStore.loadWidgetSnapshotSync()
        completion(BaggedEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BaggedEntry>) -> Void) {
        let snapshot = AppDataStore.loadWidgetSnapshotSync()
        let entry = BaggedEntry(date: .now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

struct BaggedWidgetEntryView: View {
    let entry: BaggedEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved Nearby")
                .font(.headline)

            if entry.snapshot.nearbyEntries.isEmpty {
                Spacer()
                Text("Share a link or screenshot into bagged to fill this widget.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.nearbyEntries.prefix(3)) { place in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(place.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            if let distance = place.distanceMeters, distance.isFinite {
                                Text(Measurement(value: distance / 1000, unit: UnitLength.kilometers), format: .measurement(width: .abbreviated, usage: .road))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(place.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct BaggedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BaggedWidget", provider: BaggedTimelineProvider()) { entry in
            BaggedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Saved Nearby")
        .description("Your top nearby saved places from bagged.")
        .supportedFamilies([.systemMedium])
    }
}
