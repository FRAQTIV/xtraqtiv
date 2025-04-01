import SwiftUI

@main
struct ExtraqtivApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Add app-specific commands here as needed
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, Extraqtiv!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your Evernote data extraction companion")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
                .frame(height: 40)
            
            Image(systemName: "square.and.arrow.up.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("Ready to extract your notes")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

