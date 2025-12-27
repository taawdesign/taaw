import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var counter = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Hello, SwiftIDE!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Counter: \(counter)")
                .font(.title2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button(action: { counter -= 1 }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                
                Button(action: { counter += 1 }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
            }
            .foregroundColor(.blue)
        }
        .padding()
    }
}