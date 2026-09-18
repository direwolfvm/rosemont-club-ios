import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: Tab = .home

    enum Tab: Hashable { case home, groups, events, resources, you }

    var body: some View {
        @Bindable var model = model
        TabView(selection: $tab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)
            NavigationStack { DirectoryView(kind: .groups) }
                .tabItem { Label("Groups", systemImage: "person.2") }
                .tag(Tab.groups)
            NavigationStack { DirectoryView(kind: .events) }
                .tabItem { Label("Events", systemImage: "calendar") }
                .tag(Tab.events)
            NavigationStack { DirectoryView(kind: .resources) }
                .tabItem { Label("Resources", systemImage: "safari") }
                .tag(Tab.resources)
            NavigationStack { ProfileView() }
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(Tab.you)
        }
        .tint(Color.brand)
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                NoticeBanner(text: notice)
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { model.notice = nil }
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.notice)
        .sheet(isPresented: $model.authPresented) {
            AuthView()
        }
        .fullScreenCover(isPresented: $model.isLocked) {
            LockView()
        }
    }
}

/// Shared destinations for every tab's navigation stack.
struct ClubDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Entity.self) { DetailView(item: $0) }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .about: AboutView()
                case .governance: GovernanceView()
                case .profile: ProfileView()
                case .directory(let kind): DirectoryView(kind: kind)
                }
            }
    }
}

extension View {
    func clubDestinations() -> some View { modifier(ClubDestinations()) }
}
