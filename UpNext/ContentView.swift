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
                    Group {
                        Spacer()
                        Text("\(soonEvent.title) is starting soon! (\(soonEvent.remainingDesc))")
                        Spacer()
                    }
                    .padding([.leading, .trailing], 10)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                    .background(soonEvent.isVerySoon ? (soonEvent.remaining % 2 == 0 ? Color.red : Color.blue) : Color.white )
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
                    Group {
                        if events.isEmpty {
                            Text("No Events")
                        }
                        else {
                            Text("\(events.count) Upcoming Event" + (events.count == 1 ? "" : "s"))
                            List(events, id: \.id) { event in
                                Text("\(event.title) at \(event.time) (\(event.remainingDesc))")
                            }
                        }
                    }
                }
            }
        }.onReceive(timer) { _ in
            self.controller.fetchEvents()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
