import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var selectedDriver1 = UserDefaults(suiteName: appGroupID)?.string(forKey: driver1Key) ?? "HAM"
    @State private var selectedDriver2 = UserDefaults(suiteName: appGroupID)?.string(forKey: driver2Key) ?? "VER"
    @State private var selectedDriver3 = UserDefaults(suiteName: appGroupID)?.string(forKey: driver3Key) ?? "NOR"
    @State private var selectedDriver4 = UserDefaults(suiteName: appGroupID)?.string(forKey: driver4Key) ?? "LEC"
    @State private var selectedDriver5 = UserDefaults(suiteName: appGroupID)?.string(forKey: driver5Key) ?? "PIA"

    @State private var selectedTeam1 = UserDefaults(suiteName: appGroupID)?.string(forKey: team1Key) ?? "Ferrari"
    @State private var selectedTeam2 = UserDefaults(suiteName: appGroupID)?.string(forKey: team2Key) ?? "McLaren"

    private let rossoCorsa = Color(red: 0.937, green: 0.102, blue: 0.176)
    private let carbonBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    var body: some View {
        ZStack {
            LinearGradient(colors: [carbonBlack, .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MY GRID")
                            .font(.system(size: 36, weight: .black))
                            .fontWidth(.compressed)
                            .italic()
                            .foregroundColor(.white)
                        Text("Tap a slot to choose what it shows.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)

                    // Drivers
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("DRIVERS")
                        DriverSlotRow(slotNumber: 1, selectedCode: $selectedDriver1,
                                      onSave: { save(code: selectedDriver1, key: driver1Key) })
                        DriverSlotRow(slotNumber: 2, selectedCode: $selectedDriver2,
                                      onSave: { save(code: selectedDriver2, key: driver2Key) })
                        DriverSlotRow(slotNumber: 3, selectedCode: $selectedDriver3,
                                      onSave: { save(code: selectedDriver3, key: driver3Key) })
                        DriverSlotRow(slotNumber: 4, selectedCode: $selectedDriver4,
                                      onSave: { save(code: selectedDriver4, key: driver4Key) })
                        DriverSlotRow(slotNumber: 5, selectedCode: $selectedDriver5,
                                      onSave: { save(code: selectedDriver5, key: driver5Key) })
                    }

                    // Teams
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("TEAMS")
                        TeamSlotRow(slotNumber: 1, selectedTeam: $selectedTeam1,
                                    onSave: { saveTeam(name: selectedTeam1, key: team1Key) })
                        TeamSlotRow(slotNumber: 2, selectedTeam: $selectedTeam2,
                                    onSave: { saveTeam(name: selectedTeam2, key: team2Key) })
                    }

                    Text("Add the widgets from your home screen,\nthen pick what each one shows here.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
            }
            .task {
                do {
                    try await DriverService.shared.updateChampionshipStandings()
                    WidgetCenter.shared.reloadAllTimelines()
                } catch {
                    print("Failed to fetch standings: \(error)")
                }
            }
        }
    }

    // MARK: - Section header
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .black))
                .fontWidth(.expanded)
                .tracking(2)
                .foregroundColor(rossoCorsa)
            Rectangle()
                .fill(LinearGradient(colors: [rossoCorsa, rossoCorsa.opacity(0.05)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Saving
    func save(code: String, key: String) {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(code, forKey: key)
        defaults?.synchronize()
        for kind in ["FavouriteDriver1Widget", "FavouriteDriver2Widget", "FavouriteDriver3Widget",
                     "FavouriteDriver4Widget", "FavouriteDriver5Widget"] {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    func saveTeam(name: String, key: String) {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(name, forKey: key)
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: "FavouriteTeam1Widget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavouriteTeam2Widget")
    }
}

// MARK: - Driver slot row (tap to open a menu)

struct DriverSlotRow: View {
    let slotNumber: Int
    @Binding var selectedCode: String
    let onSave: () -> Void

    private var driver: DriverInfo { DriverInfo.from(code: selectedCode) }

    var body: some View {
        Menu {
            Picker("Driver", selection: $selectedCode) {
                ForEach(DriverInfo.all, id: \.code) { d in
                    Text("\(d.name) — \(d.team)").tag(d.code)
                }
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(driver.teamColor)
                    .frame(width: 4, height: 38)

                Text("\(driver.number)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .fontWidth(.compressed)
                    .italic()
                    .foregroundColor(driver.teamColor)
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text(driver.name.uppercased())
                        .font(.system(size: 17, weight: .black))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(driver.team.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(driver.teamColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("FAV \(slotNumber)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.gray)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(driver.teamColor.opacity(0.18), lineWidth: 1)
            )
        }
        .onChange(of: selectedCode) { _, _ in onSave() }
    }
}

// MARK: - Team slot row (tap to open a menu)

struct TeamSlotRow: View {
    let slotNumber: Int
    @Binding var selectedTeam: String
    let onSave: () -> Void

    private let rossoCorsa = Color(red: 0.937, green: 0.102, blue: 0.176)
    private var color: Color { DriverInfo.teamColors[selectedTeam] ?? rossoCorsa }

    var body: some View {
        Menu {
            Picker("Team", selection: $selectedTeam) {
                ForEach(TeamInfo.all, id: \.name) { t in
                    Text(t.name).tag(t.name)
                }
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: 38)

                RoundedRectangle(cornerRadius: 5)
                    .fill(color)
                    .frame(width: 34, height: 20)

                Text(selectedTeam.uppercased())
                    .font(.system(size: 17, weight: .black))
                    .fontWidth(.compressed)
                    .italic()
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("TEAM \(slotNumber)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.gray)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
        }
        .onChange(of: selectedTeam) { _, _ in onSave() }
    }
}

#Preview {
    ContentView()
}
