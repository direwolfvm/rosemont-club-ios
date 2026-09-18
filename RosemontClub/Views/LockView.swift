import SwiftUI

/// Full-screen biometric gate shown when a Face ID / Touch ID protected session exists.
struct LockView: View {
    @Environment(AppModel.self) private var model
    @State private var busy = false
    @State private var attempted = false

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                BrandMark(size: 72)
                VStack(spacing: 6) {
                    Text("The Rosemont Club").font(.display(28)).foregroundStyle(Color.ink)
                    Text("Hey, neighbor. Welcome back.").foregroundStyle(Color.mutedInk)
                }
                Spacer()
                if let error = model.unlockError { NoticeText(text: error, error: true) }
                Button {
                    Task { await unlock() }
                } label: {
                    Label(busy ? "Checking…" : "Unlock with \(Biometrics.name)", systemImage: Biometrics.symbol)
                }
                .buttonStyle(.primary)
                .disabled(busy)
                Button("Use password instead") {
                    model.continueWithoutUnlocking()
                    model.authPresented = true
                }
                .buttonStyle(.secondary)
                Button("Browse without signing in") { model.continueWithoutUnlocking() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.mutedInk)
                    .padding(.bottom, 8)
            }
            .padding(24)
        }
        .task {
            guard !attempted else { return }
            attempted = true
            try? await Task.sleep(for: .milliseconds(350))
            await unlock()
        }
    }

    private func unlock() async {
        busy = true
        await model.unlockWithBiometrics()
        busy = false
    }
}
