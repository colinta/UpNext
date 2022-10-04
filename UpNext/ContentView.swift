////
///  ContentView.swift
//

import SwiftUI

struct ContentView: View {
	@ObservedObject var controller = EventController()
	let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

	var body: some View {
		VStack {
			if controller.soonEvent != nil {
				controller.soonEvent.map { soonEvent in
					SoonEventView(soonEvent)
						.onTapGesture {
							self.controller.dismiss()
						}
				}
			}
			else if controller.isRequestingAccess {
				Text("Requesting permission")
			}
			else if controller.authorizationStatus == .denied {
				Text("Access to Events has been denied")
			}
			else if controller.authorizationStatus == .notDetermined {
				Button(action: {
					self.controller.requestAccess()
				}) {
				   Text("Request permission")
			   }
			}
			else {
				controller.events.map { events in EventsView(events: events) }
			}
		}.onReceive(timer) { _ in
			self.controller.fetchEvents()
		}
	}
}

struct SoonEventView: View {
	let soonEvent: EventController.Event
	let onTapGesture: (() -> Void)?
	
	init(_ event: EventController.Event, onTap: (() -> Void)? = nil) {
		self.soonEvent = event
		self.onTapGesture = onTap
	}
	
	func onTapGesture(_ onTap: @escaping () -> Void) -> Self {
		return SoonEventView(soonEvent, onTap: onTap)
	}

	var body: some View {
		VStack {
			Group {
				Spacer()
				Text("\(soonEvent.title) is starting soon! (\(soonEvent.remainingDesc))")
				Spacer()
			}
			.padding([.leading, .trailing], 10)
			.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
		}.background(soonEvent.isVerySoon ? (soonEvent.remaining % 2 == 0 ? Color.red : Color.blue) : Color.white )
			.onTapGesture {
				self.onTapGesture?()
			}.ignoresSafeArea()
	}
}

struct EventsView: View {
	let events: [EventController.Event]

	var body: some View {
		Group {
			if events.count == 0 {
				Text("No Events")
			}
			else {
				Text("\(events.count) Upcoming Event" + (events.count == 1 ? "" : "s")).padding([.top, .bottom], 10)
				List(events, id: \.id) { event in
					if (event.hasStarted) {
						Text("\(event.title) until \(event.endTime)")
					} else {
						Text("\(event.title) at \(event.startTime) (\(event.remainingDesc))")
					}
				}.listStyle(.plain)
					.padding([.top], 0)
			}
		}
	}
}

struct EventsView_Upcoming_Previews: PreviewProvider {
	static var previews: some View {
		let now = Date()
		let calendar = Calendar.current
		let events: [EventController.Event] = [(15, 30), (30, 60), (90, 150)].map { (startOffset, endOffset) in
			let startComponents = DateComponents(minute: startOffset)
			let endComponents = DateComponents(minute: endOffset)
			let startTime = calendar.date(byAdding: startComponents, to: now)!
			let endTime = calendar.date(byAdding: endComponents, to: now)!
			return EventController.Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime)
		}

		return VStack {
			EventsView(events: events)
		}
	}
}

struct EventsView_Current_Previews: PreviewProvider {
	static var previews: some View {
		let now = Date()
		let calendar = Calendar.current
		
		let startComponents = DateComponents(minute: -5)
		let endComponents = DateComponents(minute: 25)
		let startTime = calendar.date(byAdding: startComponents, to: now)!
		let endTime = calendar.date(byAdding: endComponents, to: now)!

		let event = EventController.Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime)

		let events: [EventController.Event] = [(15, 30), (30, 60), (90, 150)].map { (startOffset, endOffset) in
			let startComponents = DateComponents(minute: startOffset)
			let endComponents = DateComponents(minute: endOffset)
			let startTime = calendar.date(byAdding: startComponents, to: now)!
			let endTime = calendar.date(byAdding: endComponents, to: now)!
			return EventController.Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime)
		}

		return VStack {
			EventsView(events: [event] + events)
		}
	}
}

struct SoonEvent_Previews: PreviewProvider {
	static var previews: some View {
		let now = Date()
		let calendar = Calendar.current
		
		let startComponents = DateComponents(second: 29)
		let endComponents = DateComponents(minute: 31)
		let startTime = calendar.date(byAdding: startComponents, to: now)!
		let endTime = calendar.date(byAdding: endComponents, to: now)!

		let event = EventController.Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime)

		return VStack {
			SoonEventView(event)
		}
	}
}
