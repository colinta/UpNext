////
///  ContentView.swift
//

import SwiftUI
import EventKit

typealias Event = EventController.Event

struct ContentView: View {
    @ObservedObject var controller = EventController()
    @State var selectingCalendars = false
    @State var didTick = false
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if controller.soonEvent != nil {
                controller.soonEvent.map { soonEvent in
                    SoonEventView(soonEvent)
                        .onTap {
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
                   Text("To use this app we will need access to your calendar(s).")
               }
            }
            else if selectingCalendars {
                CalendarsView(
                    controller.selectedCalendars,
                    onToggle: { calendar in
                        controller.toggle(calendar)
                    }
                )
                    .onDismiss {
                        selectingCalendars = false
                    }
            }
            else {
                controller.events.map { events in EventsView(events)
                        .onCalendarsTap { selectingCalendars = true }
                }
            }
        }.onReceive(timer) { _ in
            self.controller.fetchEvents()
        }
    }
}

struct SoonEventView: View {
    let soonEvent: Event
    let onTap: (() -> Void)?
	@Environment(\.colorScheme) var currentMode

    init(_ event: Event, onTap: (() -> Void)? = nil) {
        self.soonEvent = event
        self.onTap = onTap
    }

    func onTap(_ onTap: @escaping () -> Void) -> Self {
        return SoonEventView(soonEvent, onTap: onTap)
    }
	
	var startingText: String {
		if soonEvent.remaining > 0 {
			return "is starting soon"
		} else {
			return "just started"
		}
	}
	
	var color1: Color {
		currentMode == .dark ? Color.orange : Color.init(hue: 354/360, saturation: 77/100, brightness: 87/100)
	}
	var color2: Color {
		currentMode == .dark ? Color.purple : Color.mint
	}
	var urgentColor1: Color {
		Color.red
	}
	var urgentColor2: Color {
		Color.blue
	}
	func bgColor(altColor: Bool) -> Color {
		if soonEvent.isStarted {
			return altColor ? urgentColor1 : urgentColor2
		} else if soonEvent.isVerySoon {
			return altColor ? color1 : color2
		} else {
			return currentMode == .dark ? Color.black : Color.white
		}
	}

    var body: some View {
        VStack {
            Group {
                Spacer()
                Text("\(soonEvent.title) \(startingText) (\(soonEvent.remainingUntilStartDesc))")
                Spacer()
            }
            .padding([.leading, .trailing], 10)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        }.background(bgColor(altColor: Int(soonEvent.remaining) % 2 == 0))
            .onTapGesture {
                self.onTap?()
            }.ignoresSafeArea()
    }
}

struct CalendarsView: View {
    let calendars: [EventController.SelectedCalendar]
    let onToggle: (_: EventController.SelectedCalendar) -> Void
    let onDismiss: (() -> Void)?

    init(_ calendars: [EventController.SelectedCalendar], onToggle: @escaping (_: EventController.SelectedCalendar) -> Void, onDismiss: (() -> Void)? = nil) {
        self.calendars = calendars
        self.onToggle = onToggle
        self.onDismiss = onDismiss
    }

    func onDismiss(_ onDismiss: @escaping () -> Void) -> Self {
        return CalendarsView(calendars, onToggle: onToggle, onDismiss: onDismiss)
    }

	
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDismiss ?? {}) {
                    Text("Dismiss")
                }.padding([.trailing], 10)
            }.padding([.top], 10)

            List(calendars, id: \.id) { calendar in
                Button(action: {
                    onToggle(calendar)
                }) {
                    HStack {
                        Image(systemName: calendar.isSelected ? "checkmark.circle.fill" : "checkmark.circle")
                        Text(calendar.title)
                    }
                }
            }
        }
    }
}

struct EventsView: View {
    typealias EventAndPrev = (Event, Event?)
    let events: [Event]
    let onCalendarsTap: (() -> Void)?

    init(_ events: [Event], onCalendarsTap: (() -> Void)? = nil) {
        self.events = events
        self.onCalendarsTap = onCalendarsTap
    }

    func onCalendarsTap(_ onCalendarsTap: @escaping () -> Void) -> Self {
        return EventsView(events, onCalendarsTap: onCalendarsTap)
    }

    func titleBar() -> some View {
        ZStack {
            Text("\(events.count) Upcoming Event" + (events.count == 1 ? "" : "s"))
            if let onCalendarsTap = onCalendarsTap {
                HStack {
                    Spacer()
                    Button(action: {
                        onCalendarsTap()
                    }) {
                        Text("Calendars")
                    }.padding([.trailing], 10)
                }
            }
        }.padding([.top], 10)
    }

    func listItemText(_ text: String) -> some View {
        HStack {
            VStack {
                Text(text)
            }.padding([.leading], 10)
            Spacer()
        }
    }
	@Environment(\.colorScheme) var currentMode
	var bgBar: Color {
		currentMode == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.2)
	}

	func listItem(_ event: Event) -> some View {
		ZStack {
			GeometryReader { metrics in
				if event.status == .accepted || event.status == .completed || event.status == .inProcess {
					if (event.hasStarted) {
						HStack {
							bgBar.frame(width: metrics.size.width * event.remainingPercent, height: metrics.size.height)
								.padding(0)
							Spacer()
						}
					} else {
						Color.clear
					}
				} else if event.status == .declined {
					ZStack {
						Stripes(config: StripesConfig(
							background: Color.pink.opacity(0.2),
							foreground: Color.pink.opacity(0.5),
							degrees: 30))
					}
				} else if event.status == .unknown || event.status == .pending {
					ZStack {
						Stripes(config: StripesConfig(
							background: Color.clear,
							foreground: bgBar,
							degrees: 30, barWidth: 10))
					}
				} else {
					Color.gray.opacity(0.2)
				}
			}
			
			VStack {
				if (event.hasStarted) {
					listItemText("\(event.title) until \(event.endTime) (\(event.nearestRemainingDesc))")
				} else {
					listItemText("\(event.title) at \(event.startTime) (\(event.nearestRemainingDesc))")
				}
			}.padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
		}
	}

    var eventsAndPrev: [EventAndPrev] {
        var prevEvent: Event? = nil
        return events.map { event in
            let value = (event, prevEvent)
            prevEvent = event
            return value
        }
    }

    var body: some View {
        VStack {
            if events.count == 0 {
                Text("No Events")
            }
            else {
                titleBar()

                List(eventsAndPrev, id: \EventAndPrev.0.id) { (event, prevEvent) in
					if let prevEvent = prevEvent, !event.sameDay(as: prevEvent) {
						ZStack {
							Text(event.dayMonth)
						}
					} else if prevEvent == nil {
						ZStack {
							Text(event.dayMonth)
						}
					}
					listItem(event)
						.listRowInsets(EdgeInsets())
                }.listStyle(.plain)
                    .padding([.top], 10)
            }
        }
    }
}

  // //
 // //  PREVIEWS
// //

struct EventsView_Upcoming_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let calendar = Calendar.current
        let oneDay = 1440
        let offsets: [(String, Int, Int, EKParticipantStatus)] = [
            ("Start the day off right, with a long meeting. ", -30, 30, .accepted),
            ("Something quick", 30, 60, .accepted),
            ("Meet with and discuss lots of interesting features and changes that may or may not have impact to users. ", 90, 150, .declined),
            ("Another one", oneDay, 150, .accepted),
            ("Something else", oneDay + 15, 150, .unknown),
			("Nothing!", oneDay + oneDay + 15, 150, .tentative),
        ]
        let events: [Event] = offsets.map { (title, startOffset, endOffset, status) in
            let startComponents = DateComponents(minute: startOffset)
            let endComponents = DateComponents(minute: endOffset)
            let startTime = calendar.date(byAdding: startComponents, to: now)!
            let endTime = calendar.date(byAdding: endComponents, to: now)!
            let postfix: String = ({
                switch status {
                case .accepted:
                    return " (accepted)"
                case .tentative:
                    return " (maybe)"
                case .declined:
                    return " (declined)"
				case .unknown:
                    return " (unknown)"
				default:
					return " (???)"
                }
            })()
            return Event(id: "\(startTime)-\(endComponents)", title: "\(title)\(postfix)", startDate: startTime, endDate: endTime, status: status)
        }

        return VStack {
            EventsView(events, onCalendarsTap: {})
        }
    }
}

struct EventsView_Status_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let calendar = Calendar.current
        let offsets: [(Int, Int, EKParticipantStatus)] = [
            (-15, 15, .accepted),
			(15, 30, .accepted),
            (30, 60, .tentative),
            (90, 150, .declined),
            (180, 150, .unknown)
        ]
        let events: [Event] = offsets.map { (startOffset, endOffset, status) in
            let startComponents = DateComponents(minute: startOffset)
            let endComponents = DateComponents(minute: endOffset)
            let startTime = calendar.date(byAdding: startComponents, to: now)!
            let endTime = calendar.date(byAdding: endComponents, to: now)!
            let title: String = ({
                switch status {
                case .accepted:
                    return "Working, confirmed"
                case .tentative:
                    return "Working, maybe"
                case .declined:
                    return "Working, no way"
                default:
                    return "Working, unknown"
                }
            })()
            return Event(id: "\(startTime)-\(endComponents)", title: title, startDate: startTime, endDate: endTime, status: status)
        }

        return VStack {
            EventsView(events, onCalendarsTap: {})
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

        let event = Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime, status: .accepted)

        let events: [Event] = [(15, 30), (30, 60), (90, 150)].map { (startOffset, endOffset) in
            let startComponents = DateComponents(minute: startOffset)
            let endComponents = DateComponents(minute: endOffset)
            let startTime = calendar.date(byAdding: startComponents, to: now)!
            let endTime = calendar.date(byAdding: endComponents, to: now)!
            return Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime, status: .accepted)
        }

        return VStack {
            EventsView([event] + events)
        }
    }
}

struct SoonEvent_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let now = calendar.date(byAdding: DateComponents(second: 0), to: Date())!

        let startComponents = DateComponents(minute: 5)
        let endComponents = DateComponents(minute: 31)
        let startTime = calendar.date(byAdding: startComponents, to: now)!
        let endTime = calendar.date(byAdding: endComponents, to: now)!

        let event = Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime, status: .accepted)

        VStack {
            SoonEventView(event)
        }
    }
}

struct VerySoonEvent_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let now = calendar.date(byAdding: DateComponents(second: 0), to: Date())!

        let eventSoon: () -> Event = {
            let startComponents = DateComponents(second: 30)
            let endComponents = DateComponents(minute: 31)
            let startTime = calendar.date(byAdding: startComponents, to: now)!
            let endTime = calendar.date(byAdding: endComponents, to: now)!
            
            return Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime, status: .accepted)
        }
        
        let eventStarted: () -> Event = {
            let startComponents = DateComponents(second: -31)
            let endComponents = DateComponents(minute: 31)
            let startTime = calendar.date(byAdding: startComponents, to: now)!
            let endTime = calendar.date(byAdding: endComponents, to: now)!
            
            return Event(id: "\(startTime)-\(endComponents)", title: "Do some work", startDate: startTime, endDate: endTime, status: .accepted)
        }

        Group {
            SoonEventView(eventSoon()).previewDisplayName("Very Soon")
            SoonEventView(eventStarted()).previewDisplayName("Just Started")
        }
    }
}

struct Calendars_Previews: PreviewProvider {
    static var previews: some View {
        CalendarsView([
            EventController.SelectedCalendar(
                isSelected: true,
                title: "Selected Calendar",
                id: "0"
            ),
            EventController.SelectedCalendar(
                isSelected: false,
                title: "Ignored Calendar",
                id: "1"
            )
        ], onToggle: { _ in })
    }
}
