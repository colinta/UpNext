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
            else if controller.authorizationStatus == .authorized && controller.events == nil {
                Text("Fetching Events")
            }
            else if controller.authorizationStatus == .notDetermined {
                Button(action: {
                    self.controller.requestAccess()
                }) {
                   Text("Request permission")
               }
            }
            else {
				controller.events.map { events in
					EventsView(events, currentEvent: controller.currentEvent)
				}
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
			.onTapGesture {
				self.onTapGesture?()
			}
		}.background(soonEvent.isVerySoon ? (soonEvent.remaining % 2 == 0 ? Color.red : Color.blue) : Color.white )

	}
}

struct EventsView: View {
	let events: [EventController.Event]
	let currentEvent: EventController.Event?
	
	init(_ events: [EventController.Event], currentEvent: EventController.Event?) {
		self.events = events
		self.currentEvent = currentEvent
	}
	
	var body: some View {
		Group {
			if events.isEmpty {
				Text("No Events")
			}
			else {
				Text("\(events.count) Upcoming Event" + (events.count == 1 ? "" : "s")).padding([.top, .bottom], 10)
				currentEvent.map { currentEvent in
					Text("\(currentEvent.title) until \(currentEvent.endTime)")
				}
				List(events, id: \.id) { event in
					Text("\(event.title) at \(event.startTime) (\(event.remainingDesc))")
				}.listStyle(.plain)
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
			EventsView(events, currentEvent: nil)
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
			EventsView(events, currentEvent: event)
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
