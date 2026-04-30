import SwiftUI

struct ContentView: View {
    @StateObject private var settings = SettingsStore()
    @StateObject private var vm: ChatGPTViewModel

    init() {
        let s = SettingsStore()
        _settings = StateObject(wrappedValue: s)
        _vm       = StateObject(wrappedValue: ChatGPTViewModel(settings: s))
    }

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            GlassesPreviewView()
                .tabItem { Label("Glasses", systemImage: "eyeglasses") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environmentObject(vm)
        .environmentObject(settings)
        .tint(.green)
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
