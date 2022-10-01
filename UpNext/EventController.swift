////
///  AppState.swift
//


import Foundation
import EventKit
import SwiftUI

class EventController: ObservableObject {
    struct Event {
        static let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()

        let id: String
        let title: String
        let startDate: Date
        let endDate: Date

        var startTime: String {
            Event.formatter.string(from: startDate)
        }
        var endTime: String {
            Event.formatter.string(from: endDate)
        }
        var remaining: Int {
            Int(startDate.timeIntervalSince1970 - Date().timeIntervalSince1970)
        }
        var isSoon: Bool {
            remaining < 300
        }
        var isVerySoon: Bool {
            remaining < 60
        }
        var remainingDesc: String {
            var remaining = Double(self.remaining)
            let isNegative = self.remaining < 0
            let sign = isNegative ? "-" : ""
            if isNegative {
                remaining = -remaining
            }
            if remaining < 60 && remaining > -60 {
                return "\(sign)\(Int(remaining.rounded())) seconds"
            }
            if remaining < 300 {
                let minutes = Int(remaining) / 60
                let seconds = Int((remaining - Double(minutes) * 60).rounded(.up))
                return "\(sign)\(minutes):\(seconds < 10 ? "0" : "")\(seconds) \(minutes == 1 ? "minute" : "minutes")"
            }
            remaining /= 60
            if remaining < 60 {
                return "\(sign)\(Int(remaining.rounded())) minutes"
            }
            if remaining < 240 {
                let hours = Int(remaining) / 60
                let minutes = Int((remaining - Double(hours) * 60).rounded(.up))
                return "\(sign)\(hours):\(minutes < 10 ? "0" : "")\(minutes) hours"
            }
            remaining /= 60
            if remaining < 24 {
                return "\(sign)\(Int(remaining.rounded())) hours"
            }
            remaining /= 24
            return "\(sign)\(Int(remaining.rounded())) days"
        }
    }
    
    let eventStore = EKEventStore()
    let calendar = Calendar.current

    @Published var isRequestingAccess = false
    @Published var events: [Event]? = nil
    @Published var lastFetched: Date? = nil
    @Published var now = Date()
    @Published var soonEvent: Event?

    var dismissedEvents: [Event] = []

    var lastFetchedAgo: Int? {
        lastFetched.map { Int(Date().timeIntervalSince1970 - $0.timeIntervalSince1970) }
    }
    
    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: EKEntityType.event)
    }
    
    var currentEvent: Event? = nil
    
    init() {
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
    
    func fetchEvents() {
        guard authorizationStatus == .authorized else { return }

        let now = Date()
        self.now = now
		self.dismissedEvents = self.dismissedEvents.filter { $0.endDate > now }

		let isStale = lastFetched.map({ now.timeIntervalSince1970 - $0.timeIntervalSince1970 > 60 }) ?? true
        if isStale {
            eventStore.refreshSourcesIfNecessary()
            lastFetched = now
        }

        let laterComponents = DateComponents(day: 2)
        guard
            let later = calendar.date(byAdding: laterComponents, to: now)
            else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: now, end: later, calendars: nil)
        let newEvents: [Event] = eventStore.events(matching: predicate).compactMap { event in
            guard event.availability != .free, let startDate = event.startDate, let endDate = event.endDate else { return nil }
            
            if startDate <= now && endDate > now {
                currentEvent = Event(
                    id: event.eventIdentifier,
                    title: event.title,
                    startDate: startDate,
                    endDate: endDate
                )
                return nil
            }
            
            guard startDate > now, !event.isAllDay else { return nil }
            guard !dismissedEvents.contains(where: { $0.id == event.eventIdentifier }) else { return nil }
            return Event(
                id: event.eventIdentifier,
                title: event.title,
                startDate: startDate,
                endDate: endDate
            )
        }

        self.events = newEvents
        if self.soonEvent == nil, let nextEvent = newEvents.first(where: { $0.isSoon }) {
            self.soonEvent = nextEvent
        }
    }
}
