import SwiftUI

struct GovernanceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(
                    eyebrow: "Many neighbors. Shared responsibility.",
                    title: "A voice in our neighborhood.",
                    text: "Help with the small things. Weigh in on the big ones. Participate in a way that fits your life."
                )
                if let g = model.content("governance") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(g.name).font(.sectionTitle).foregroundStyle(Color.ink)
                        Paragraphs(text: g.description)
                    }
                }
                FeedbackPanel()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Community questions").font(.sectionTitle).foregroundStyle(Color.ink)
                    CommunityQuestions()
                }
            }
            .pageGutter()
            .padding(.vertical, 12)
        }
        .background(Color.paper)
        .navigationTitle("Governance")
        .navigationBarTitleDisplayMode(.inline)
        .clubDestinations()
    }
}

struct AboutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    private let sections = ["about-club", "about-neighborhood", "about-history", "about-participation", "about-principles"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(
                    eyebrow: "Rooted here. Open to everyone.",
                    title: "A little more neighborly.",
                    text: "A shared home for the connections that make Rosemont feel like Rosemont."
                )
                VStack(alignment: .leading, spacing: 8) {
                    BoundaryMap().frame(height: 260)
                    Text("The Club's community-provided residency boundary. Address checks use this outline.")
                        .font(.footnote).foregroundStyle(Color.mutedInk)
                    NavigationLink(value: Route.profile) {
                        Label("Verify your residency", systemImage: "arrow.right").labelStyle(TrailingIconLabelStyle()).font(.system(size: 14, weight: .semibold))
                    }
                }
                ForEach(sections, id: \.self) { slug in
                    if let s = model.content(slug) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(s.name).font(.sectionTitle).foregroundStyle(Color.ink)
                            Paragraphs(text: s.description)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Explore the history").font(.cardTitle).foregroundStyle(Color.ink)
                    historyLink("Rosemont Citizens Association history archive", ExternalLinks.rcaHistory)
                    historyLink("City of Alexandria: Colored Rosemont Community History Initiative", ExternalLinks.coloredRosemont)
                    historyLink("Rosemont Historic District nomination", ExternalLinks.historicNomination)
                    Text("The Club's organization and participation model are described here separately from the historical Rosemont Citizens Association.")
                        .font(.footnote).foregroundStyle(Color.mutedInk)
                }
                .card()
                .background(Color.mist.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }
            .pageGutter()
            .padding(.vertical, 12)
        }
        .background(Color.paper)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .clubDestinations()
    }

    private func historyLink(_ title: String, _ url: URL) -> some View {
        Button { openURL(url) } label: {
            HStack(alignment: .top, spacing: 6) {
                Text(title).multilineTextAlignment(.leading)
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).padding(.top, 4)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.brand)
        }
    }
}
