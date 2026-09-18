import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var tab: Tab = .home
    @State private var homePath = NavigationPath()

    enum Tab: Hashable { case home, groups, events, resources, you }

    var body: some View {
        @Bindable var model = model
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) { HomeView() }
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
        .onOpenURL { model.open(url: $0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { model.open(url: url) }
        }
        .onChange(of: model.pendingLink) { _, _ in followPendingLink() }
        .onChange(of: model.loading) { _, _ in followPendingLink() }
        .overlay(alignment: .top) {
            if model.config.updateRequired {
                Button {
                    openURL(ExternalLinks.website)
                } label: {
                    Label("This version of the app is out of date. Please update to keep using it.", systemImage: "arrow.down.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.clay, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                }
            }
        }
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

extension RootView {
    /// Universal links land on the Home tab's stack so the back button returns to the neighborhood.
    private func followPendingLink() {
        guard let link = model.pendingLink else { return }
        switch link {
        case .route(let route):
            tab = .home
            homePath = NavigationPath([route])
            model.pendingLink = nil
        case .entity(let kind, let slug):
            guard !model.loading else { return }
            if let entity = model.entity(kind: kind, slug: slug) {
                tab = .home
                homePath = NavigationPath([entity])
            } else if !model.records.isEmpty {
                model.notify("We couldn't find that page. It may be unpublished or no longer available.")
            }
            model.pendingLink = nil
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
