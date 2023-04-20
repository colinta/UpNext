////
///  AppState.swift
//


import Foundation
import EventKit
import SwiftUI

private let calendar = Calendar.current
private let dayMonthYearComponents: Set<Foundation.Calendar.Component> = [.day, .month, .year]
private let ONE_DAY: TimeInterval = 24 * 60 * 60

private extension Date {
	func isSameDay(as date: Date) -> Bool {
		let startComponents = calendar.dateComponents(dayMonthYearComponents, from: self)
		let dateComponents = calendar.dateComponents(dayMonthYearComponents, from: date)
		return startComponents.day == dateComponents.day && startComponents.month == dateComponents.month && startComponents.year == dateComponents.year
	}
}

class EventController: ObservableObject {
    struct SelectedCalendar {
        let isSelected: Bool
        let title: String
        let id: String
    }
	
    struct Event {
        static let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()

		static let dateFormatter: DateFormatter = {
			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			formatter.timeStyle = .none
			return formatter
		}()

        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let status: EKParticipantStatus
        var hasStarted: Bool {
            remaining < 0
        }

        var startTime: String {
            Event.timeFormatter.string(from: startDate)
        }
        var endTime: String {
            Event.timeFormatter.string(from: endDate)
        }
        var remaining: TimeInterval {
			startDate.timeIntervalSinceNow.rounded()
        }
		var remainingPercent: TimeInterval {
			Date().timeIntervalSince(startDate) / (endDate.timeIntervalSinceNow - startDate.timeIntervalSinceNow)
		}

        var isSoon: Bool {
            remaining < 300
        }
        var isVerySoon: Bool {
            remaining < 60
        }
		var dayMonth: String {
			let formatted = Event.dateFormatter.string(from: startDate)
			let today = Date()
			if startDate.isSameDay(as: today) {
				return "Today – \(formatted)"
			}
			
			let tomorrow = Date(timeIntervalSinceNow: ONE_DAY)
			if startDate.isSameDay(as: tomorrow) {
				return "Tomorrow – \(formatted)"
			}

			return formatted
		}
        var nearestRemainingDesc: String {
            var prefix: String, suffix: String
            let interval: TimeInterval
            if (hasStarted) {
				prefix = ""
				suffix = " remaining"
				interval = endDate.timeIntervalSinceNow
            } else {
				prefix = "in "
				suffix = ""
				interval = startDate.timeIntervalSinceNow
            }

            return remainingDesc(interval: interval, prefix: prefix, suffix: suffix)
        }

        var remainingUntilStartDesc: String {
            let interval = startDate.timeIntervalSince1970 - Date().timeIntervalSince1970

            if interval < 0 {
                return remainingDesc(interval: -interval, prefix: "", suffix: " ago")
            } else {
                return remainingDesc(interval: interval, prefix: "in ", suffix: "")
            }
        }

        private func remainingDesc(interval: TimeInterval, prefix: String, suffix: String) -> String {
            let remaining = Double(interval.rounded())

            if remaining < 60 && remaining > -60 {
                return "\(prefix)\(Int(remaining.rounded()))s\(suffix)"
            }
            if remaining <= 300 {
                let minutes = Int(remaining) / 60
                let seconds = Int((remaining - Double(minutes) * 60).rounded(.up))
                return "\(prefix)\(minutes)m \(seconds < 10 ? "0" : "")\(seconds)s\(suffix)"
            }
            let remainingMinutes = remaining / 60
            if remainingMinutes < 60 {
                return "\(prefix)\(Int(remainingMinutes.rounded()))m\(suffix)"
            }
            if remainingMinutes < 240 {
                let hours = Int(remainingMinutes) / 60
                let minutes = Int((remainingMinutes - Double(hours) * 60).rounded(.up))
                return "\(prefix)\(hours)h \(minutes)m\(suffix)"
            }
            let remainingHours = remainingMinutes / 60
            if remainingHours < 24 {
                return "\(prefix)\(Int(remainingHours.rounded()))h\(suffix)"
            }
            let remainingDays = remainingHours / 24
            return "\(prefix)\(Int(remainingDays.rounded()))d\(suffix)"
        }

        func sameDay(as date: Event) -> Bool {
			startDate.isSameDay(as: date.startDate)
        }
    }
    
    let eventStore = EKEventStore()
    var dismissedEvents: [Event] = []

    @Published var selectedCalendars: [SelectedCalendar] = []
    private var calendars: [EKCalendar] = []
    private var ignoredIds: [String]

    @Published var isRequestingAccess = false
    @Published var events: [Event]? = nil
    @Published var lastFetched: Date? = nil
    @Published var soonEvent: Event?

    var lastFetchedAgo: Int? {
        lastFetched.map { Int(Date().timeIntervalSince1970 - $0.timeIntervalSince1970) }
    }
    
    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: EKEntityType.event)
    }
    
    var nextEvents: [Event] {
        guard let events = events else { return [] }
        return events.filter { $0.startDate > Date() }
    }

    var currentEvents: [Event] {
        guard let events = events else { return [] }
        return events.filter { $0.endDate > Date() && $0.startDate < Date() }
    }
	
	let nowOffset: TimeInterval

	init(nowOffset: TimeInterval = 0) {
		self.nowOffset = nowOffset

        if let ignoredIds = UserDefaults.standard.array(forKey: "EKCalendar.ignoredIds") as? [String] {
            self.ignoredIds = ignoredIds
        } else {
            self.ignoredIds = []
        }

        if authorizationStatus == .authorized {
            fetchEvents()
        }
    }

    func requestAccess() {
        isRequestingAccess = true
        eventStore.requestAccess(to: EKEntityType.event, completion: _requestAccessCompletion)
    }

    private func _requestAccessCompletion(accessGranted: Bool, error: Error?) {
        DispatchQueue.main.async {
            self.isRequestingAccess = false

            if accessGranted {
                self.fetchEvents()
            }
        }
    }
    
    func dismiss() {
        guard let event = soonEvent else { return }
        self.soonEvent = nil
        dismissedEvents.append(event)
    }

    func isDismissed(_ event: Event) -> Bool {
        dismissedEvents.contains(where: { $0.id == event.id })
    }

    func toggle(_ selectedCalendar: SelectedCalendar) {
        guard
            let calendar = calendars.first(where: { $0.calendarIdentifier == selectedCalendar.id })
        else {
            return
        }

        if ignoredIds.contains(calendar.calendarIdentifier) {
            ignoredIds = ignoredIds.filter { $0 != calendar.calendarIdentifier }
        }
        else {
            ignoredIds = ignoredIds + [calendar.calendarIdentifier]
        }
        UserDefaults.standard.set(ignoredIds, forKey: "EKCalendar.ignoredIds")

        selectedCalendars = calendars.map { calendar in
            SelectedCalendar(
                isSelected: !ignoredIds.contains(calendar.calendarIdentifier),
                title: calendar.title,
                id: calendar.calendarIdentifier
            )
        }
    }
    
    func fetchEvents() {
        guard authorizationStatus == .authorized else { return }

        calendars = eventStore.calendars(for: .event)
        selectedCalendars = calendars.map { calendar in
            SelectedCalendar(
                isSelected: !ignoredIds.contains(calendar.calendarIdentifier),
                title: calendar.title,
                id: calendar.calendarIdentifier
            )
        }

        let includedCalendars = calendars.filter { calendar in
            !ignoredIds.contains(calendar.calendarIdentifier)
        }

		let now = Date(timeIntervalSinceNow: self.nowOffset)
        self.dismissedEvents = self.dismissedEvents.filter { $0.endDate > now }

        let isStale = lastFetched.map({ now.timeIntervalSince1970 - $0.timeIntervalSince1970 > 60 }) ?? true
        if isStale {
            eventStore.refreshSourcesIfNecessary()
            lastFetched = now
        }

        let laterComponents = DateComponents(day: 2)
		let today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now)
        guard
            let later = calendar.date(byAdding: laterComponents, to: now),
			let today = today
            else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: today, end: later, calendars: includedCalendars)
        let allEvents: [Event] = eventStore.events(matching: predicate).compactMap { event in
            guard event.availability != .free, let startDate = event.startDate, let endDate = event.endDate else { return nil }

            let defaultStatus: EKParticipantStatus
            if event.attendees?.count ?? 0 == 0 {
                defaultStatus = .accepted
            } else {
                defaultStatus = .unknown
            }
            let newEvent = Event(
                id: event.eventIdentifier,
                title: event.title,
                startDate: startDate,
                endDate: endDate,
                status: event.attendees?.first(where: { participant in
                    participant.isCurrentUser
                })?.participantStatus ?? defaultStatus
            )

            guard endDate > now, !event.isAllDay else { return nil }
			guard newEvent.status == .accepted || event.startDate > now else { return nil }
			
			if let notes = event.notes, notes.contains("focus time") || notes.contains("#ignore") {
				return nil
			}
            return newEvent
        }

        self.events = allEvents

        if self.soonEvent == nil {
            self.soonEvent = allEvents.first {
                $0.startDate > now
                && $0.isSoon
                && !isDismissed($0)
				&& $0.status == .accepted
            }
        }
    }
}
