import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "film")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("PostSync - Final Cut Pro Git Manager")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This app runs in the menu bar")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
