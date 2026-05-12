//
//  EventsDashboardPanelView.swift
//  NotchMac
//
//  Ref-design right column: date header, Next Event card with countdown,
//  mini week strip, and grid of upcoming events. Matches ref1 mockup.
//

import Defaults
import SwiftUI

struct EventsDashboardPanelView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate: Date = Date()
    @State private var now: Date = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            nextEventRow
            weekStrip
            upcomingGrid
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxHeight: 120, alignment: .top)
        .onReceive(timer) { date in now = date }
        .onAppear {
            Task { await calendarManager.updateCurrentDate(Date.now) }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 6) {
            Text(now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Next event card
    private var nextEventRow: some View {
        let upcoming = sortedUpcoming
        return HStack(alignment: .center, spacing: 8) {
            if let next = upcoming.first {
                eventPill(next)
                Spacer(minLength: 0)
                countdownLabel(to: next.start)
            } else {
                Text("Sin próximos eventos")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 30)
    }

    private func eventPill(_ event: EventModel) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeRange(for: event))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.18))
        )
    }

    private func countdownLabel(to date: Date) -> some View {
        let mins = max(0, Int(date.timeIntervalSince(now) / 60))
        let h = mins / 60
        let m = mins % 60
        let text = h > 0 ? String(format: "%d:%02d", h, m) : String(format: "%d min", m)
        return VStack(alignment: .trailing, spacing: 0) {
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text("until next event")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Week strip
    private var weekStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let weekStart = cal.date(byAdding: .day, value: -3, to: today) ?? today
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { offset in
                let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? today
                let isToday = cal.isDate(day, inSameDayAs: today)
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 10, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isToday ? Color.white.opacity(0.18) : Color.clear)
                    )
            }
        }
    }

    // MARK: - Upcoming grid
    private var upcomingGrid: some View {
        let items = Array(sortedUpcoming.dropFirst().prefix(4))
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
            spacing: 4
        ) {
            ForEach(items) { ev in
                upcomingCell(ev)
            }
            if items.isEmpty {
                Color.clear.frame(height: 1)
            }
        }
    }

    private func upcomingCell(_ event: EventModel) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(event.title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(timeRange(for: event))
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Helpers
    private var sortedUpcoming: [EventModel] {
        calendarManager.events
            .filter { $0.start >= now && !$0.isAllDay && $0.type.isEvent }
            .sorted { $0.start < $1.start }
    }

    private func timeRange(for event: EventModel) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: event.start)) – \(f.string(from: event.end))"
    }
}
