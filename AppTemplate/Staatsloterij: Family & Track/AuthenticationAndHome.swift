import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @State private var email = ""
    @State private var password = ""
    @State private var isAdult = false
    @State private var showPassword = false
    @State private var validationMessage: String?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Picker("profile.language", selection: languageBinding) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                    }

                    AssetImageView(name: "brand_logo", mode: .contain)
                        .frame(width: 150, height: 100)

                    VStack(spacing: 8) {
                        Text("auth.title")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                        Text("auth.subtitle")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .foregroundStyle(.white)

                    PremiumCard {
                        VStack(spacing: 16) {
                            GlassField(title: "auth.email") {
                                TextField("", text: $email)
                                    .textContentType(.username)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            GlassField(title: "auth.password") {
                                HStack {
                                    Group {
                                        if showPassword {
                                            TextField("", text: $password)
                                        } else {
                                            SecureField("", text: $password)
                                        }
                                    }
                                    .textContentType(.password)
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                    }
                                    .accessibilityLabel("auth.password.toggle")
                                }
                            }

                            Toggle("auth.age", isOn: $isAdult)

                            if let validationMessage {
                                Text(validationMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                validationMessage = store.signIn(
                                    email: email,
                                    password: password,
                                    isAdult: isAdult
                                )
                            } label: {
                                Label("auth.signin", systemImage: "ticket.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.goldColor)
                            .foregroundStyle(.black)

                        }
                    }
                }
                .padding()
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .keyboardDoneToolbar()
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { store.settings.language },
            set: { store.updateLanguage($0) }
        )
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: AppStore

    private var nextEvent: DrawEvent? {
        store.events.first { $0.date >= Calendar.current.startOfDay(for: Date()) }
    }

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("home.welcome")
                                .foregroundStyle(.white.opacity(0.68))
                            Text(store.profile.name)
                                .font(.system(.largeTitle, design: .serif, weight: .bold))
                        }
                        Spacer()
                        NavigationLink {
                            ProfileView()
                        } label: {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.largeTitle)
                        }
                        .accessibilityLabel("profile.title")
                    }

                    if let nextEvent {
                        CountdownCard(event: nextEvent)
                    }

                    PremiumCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("home.history.title", systemImage: "building.columns.fill")
                                .serifTitle()
                            Text("home.history.timeline")
                                .font(.system(.body, design: .serif))
                            AssetImageView(name: "history_timeline_illustration", mode: .contain)
                                .frame(height: 140)
                        }
                    }

                    PremiumCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("home.facts.title", systemImage: "info.circle.fill")
                                .serifTitle()
                            Text("home.facts.odds")
                            Text("home.facts.tax")
                            Text("home.disclaimer")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }

                    AdultNoticeView()

                    Link(destination: URL(string: "https://www.loketkansspel.nl")!) {
                        Label("home.support.link", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .navigationTitle("tab.home")
    }
}

private struct CountdownCard: View {
    let event: DrawEvent
    @State private var now = Date()

    private var remaining: TimeInterval { max(0, event.date.timeIntervalSince(now)) }
    private var isSoon: Bool { remaining < 86_400 }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let interval = max(0, event.date.timeIntervalSince(context.date))
            let days = Int(interval / 86_400)
            let hours = Int(interval.truncatingRemainder(dividingBy: 86_400) / 3_600)
            let minutes = Int(interval.truncatingRemainder(dividingBy: 3_600) / 60)

            VStack(spacing: 10) {
                Label("home.next.draw", systemImage: "clock.fill")
                    .font(.headline)
                HStack(spacing: 18) {
                    CountdownUnit(value: days, label: "home.days")
                    CountdownUnit(value: hours, label: "home.hours")
                    CountdownUnit(value: minutes, label: "home.minutes")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [AppTheme.blueColor, AppTheme.darkBlueColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppTheme.goldColor, lineWidth: isSoon ? 3 : 1)
            }
            .shadow(color: isSoon ? AppTheme.goldColor.opacity(0.5) : .clear, radius: 10)
        }
    }
}

private struct CountdownUnit: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack {
            Text(value.formatted(.number.precision(.integerLength(2))))
                .font(.title.monospacedDigit().bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
