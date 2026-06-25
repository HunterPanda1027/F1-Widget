import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var selectedDriver1: String = UserDefaults(suiteName: appGroupID)?.string(forKey: driver1Key) ?? "HAM"
    @State private var selectedDriver2: String = UserDefaults(suiteName: appGroupID)?.string(forKey: driver2Key) ?? "VER"
    @State private var selectedDriver3: String = UserDefaults(suiteName: appGroupID)?.string(forKey: driver3Key) ?? "NOR"
    @State private var selectedDriver4: String = UserDefaults(suiteName: appGroupID)?.string(forKey: driver4Key) ?? "LEC"

    let rossoCorsa = Color(red: 0.937, green: 0.102, blue: 0.176)
    let carbonBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [carbonBlack, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 4) {
                        Text("DRIVER TELEMETRY")
                            .font(.system(size: 28, weight: .black))
                            .fontWidth(.compressed)
                            .italic()
                            .foregroundColor(.white)

                        Rectangle()
                            .fill(LinearGradient(
                                colors: [rossoCorsa, rossoCorsa.opacity(0.1)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(height: 2)
                    }
                    .padding(.top, 20)

                    // Slot 1
                    DriverSlotPicker(
                        slotNumber: 1,
                        selectedCode: $selectedDriver1,
                        onSave: { save(code: selectedDriver1, key: driver1Key) }
                    )

                    // Slot 2
                    DriverSlotPicker(
                        slotNumber: 2,
                        selectedCode: $selectedDriver2,
                        onSave: { save(code: selectedDriver2, key: driver2Key) }
                    )

                    // Slot 3
                    DriverSlotPicker(
                        slotNumber: 3,
                        selectedCode: $selectedDriver3,
                        onSave: { save(code: selectedDriver3, key: driver3Key) }
                    )

                    // Slot 4
                    DriverSlotPicker(
                        slotNumber: 4,
                        selectedCode: $selectedDriver4,
                        onSave: { save(code: selectedDriver4, key: driver4Key) }
                    )

                    Text("Select your favourite drivers above,\nthen add the Driver Telemetry widgets to your home screen.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    func save(code: String, key: String) {
        let defaults = UserDefaults(suiteName: appGroupID)
        print("💾 UserDefaults suite: \(String(describing: defaults))")
        print("💾 Saving \(code) to key \(key)")
        defaults?.set(code, forKey: key)
        defaults?.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: "FavouriteDriver1Widget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavouriteDriver2Widget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavouriteDriver3Widget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FavouriteDriver4Widget")
    }
}

// MARK: - Slot Picker Component

struct DriverSlotPicker: View {
    let slotNumber: Int
    @Binding var selectedCode: String
    let onSave: () -> Void

    let rossoCorsa = Color(red: 0.937, green: 0.102, blue: 0.176)

    var selectedDriver: DriverInfo {
        DriverInfo.from(code: selectedCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Slot label
            Text("FAVOURITE \(slotNumber)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(rossoCorsa)
                .tracking(2)

            // Current selection preview
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDriver.name.uppercased())
                        .font(.system(size: 18, weight: .black))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(.white)          // ← fixed: explicit white

                    Text(selectedDriver.team.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(selectedDriver.teamColor)
                        .tracking(1.5)
                }

                Spacer()

                Text("\(selectedDriver.number)")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .fontWidth(.compressed)
                    .italic()
                    .foregroundColor(selectedDriver.teamColor)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            // Picker — colorScheme forced dark so rows render white text on dark bg
            Picker("", selection: $selectedCode) {
                ForEach(DriverInfo.all, id: \.code) { driver in
                    Text("\(driver.name) • \(driver.team)")
                        .foregroundColor(.white)          // ← fixed: explicit white on rows
                        .tag(driver.code)
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)                           // ← fixed: forces wheel to dark mode
            .frame(height: 120)
            .clipped()
            .onChange(of: selectedCode) { _, _ in
                onSave()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
    }
}

#Preview {
    ContentView()
}
