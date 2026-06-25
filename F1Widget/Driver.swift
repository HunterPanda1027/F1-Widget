import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Shared Constants

let appGroupID = "group.com.panda.f1widget"
let driver1Key = "selectedDriver1"
let driver2Key = "selectedDriver2"
let driver3Key = "selectedDriver3"
let driver4Key = "selectedDriver4"

// MARK: - Data Model

struct DriverInfo {
    let code: String
    let name: String
    let team: String
    let number: Int
    let teamColor: Color

    static let teamColors: [String: Color] = [
        "Ferrari":       Color(red: 0.937, green: 0.102, blue: 0.176),
        "McLaren":       Color(red: 1.0,   green: 0.478, blue: 0.0),
        "Mercedes":      Color(red: 0.0,   green: 0.765, blue: 0.659),
        "Red Bull":      Color(red: 0.12,  green: 0.24,  blue: 0.71),
        "Aston Martin":  Color(red: 0.0,   green: 0.467, blue: 0.376),
        "Alpine":        Color(red: 0.0,   green: 0.408, blue: 0.831),
        "Williams":      Color(red: 0.0,   green: 0.459, blue: 0.843),
        "Racing Bulls":  Color(red: 0.38,  green: 0.0,   blue: 0.82),
        "Haas":          Color(red: 0.9,   green: 0.15,  blue: 0.15),
        "Audi":          Color(red: 0.87,  green: 0.71,  blue: 0.0),
        "Cadillac":      Color(red: 0.0,   green: 0.545, blue: 0.918),
    ]

    static let all: [DriverInfo] = [
        DriverInfo(code: "HAM", name: "Lewis Hamilton",    team: "Ferrari",      number: 44,  teamColor: teamColors["Ferrari"]!),
        DriverInfo(code: "LEC", name: "Charles Leclerc",   team: "Ferrari",      number: 16,  teamColor: teamColors["Ferrari"]!),
        DriverInfo(code: "NOR", name: "Lando Norris",      team: "McLaren",      number: 4,   teamColor: teamColors["McLaren"]!),
        DriverInfo(code: "PIA", name: "Oscar Piastri",     team: "McLaren",      number: 81,  teamColor: teamColors["McLaren"]!),
        DriverInfo(code: "RUS", name: "George Russell",    team: "Mercedes",     number: 63,  teamColor: teamColors["Mercedes"]!),
        DriverInfo(code: "ANT", name: "Kimi Antonelli",    team: "Mercedes",     number: 12,  teamColor: teamColors["Mercedes"]!),
        DriverInfo(code: "VER", name: "Max Verstappen",    team: "Red Bull",     number: 1,   teamColor: teamColors["Red Bull"]!),
        DriverInfo(code: "HAD", name: "Isack Hadjar",      team: "Red Bull",     number: 6,   teamColor: teamColors["Red Bull"]!),
        DriverInfo(code: "ALO", name: "Fernando Alonso",   team: "Aston Martin", number: 14,  teamColor: teamColors["Aston Martin"]!),
        DriverInfo(code: "STR", name: "Lance Stroll",      team: "Aston Martin", number: 18,  teamColor: teamColors["Aston Martin"]!),
        DriverInfo(code: "GAS", name: "Pierre Gasly",      team: "Alpine",       number: 10,  teamColor: teamColors["Alpine"]!),
        DriverInfo(code: "COL", name: "Franco Colapinto",  team: "Alpine",       number: 43,  teamColor: teamColors["Alpine"]!),
        DriverInfo(code: "SAI", name: "Carlos Sainz",      team: "Williams",     number: 55,  teamColor: teamColors["Williams"]!),
        DriverInfo(code: "ALB", name: "Alex Albon",        team: "Williams",     number: 23,  teamColor: teamColors["Williams"]!),
        DriverInfo(code: "LAW", name: "Liam Lawson",       team: "Racing Bulls", number: 30,  teamColor: teamColors["Racing Bulls"]!),
        DriverInfo(code: "LIN", name: "Arvid Lindblad",    team: "Racing Bulls", number: 41,  teamColor: teamColors["Racing Bulls"]!),
        DriverInfo(code: "OCO", name: "Esteban Ocon",      team: "Haas",         number: 31,  teamColor: teamColors["Haas"]!),
        DriverInfo(code: "BEA", name: "Oliver Bearman",    team: "Haas",         number: 87,  teamColor: teamColors["Haas"]!),
        DriverInfo(code: "HUL", name: "Nico Hülkenberg",   team: "Audi",         number: 27,  teamColor: teamColors["Audi"]!),
        DriverInfo(code: "BOR", name: "Gabriel Bortoleto", team: "Audi",         number: 5,   teamColor: teamColors["Audi"]!),
        DriverInfo(code: "BOT", name: "Valtteri Bottas",   team: "Cadillac",     number: 77,  teamColor: teamColors["Cadillac"]!),
        DriverInfo(code: "PER", name: "Sergio Pérez",      team: "Cadillac",     number: 11,  teamColor: teamColors["Cadillac"]!),
    ]

    static func from(code: String) -> DriverInfo {
        return all.first { $0.code == code } ?? all[0]
    }

    static func fromKey(_ key: String) -> DriverInfo {
        let code = UserDefaults(suiteName: appGroupID)?.string(forKey: key) ?? "HAM"
        return from(code: code)
    }
}

// MARK: - Timeline Entries

struct Driver1Entry: TimelineEntry {
    let date: Date
    let driver: DriverInfo
}

struct Driver2Entry: TimelineEntry {
    let date: Date
    let driver: DriverInfo
}

struct Driver3Entry: TimelineEntry {
    let date: Date
    let driver: DriverInfo
}

struct Driver4Entry: TimelineEntry {
    let date: Date
    let driver: DriverInfo
}

// MARK: - Providers

struct Driver1Provider: TimelineProvider {
    func placeholder(in context: Context) -> Driver1Entry {
        Driver1Entry(date: Date(), driver: DriverInfo.from(code: "HAM"))
    }
    func getSnapshot(in context: Context, completion: @escaping (Driver1Entry) -> Void) {
        completion(Driver1Entry(date: Date(), driver: DriverInfo.fromKey(driver1Key)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Driver1Entry>) -> Void) {
        let defaults = UserDefaults(suiteName: appGroupID)
        print("📦 Widget reading from suite: \(String(describing: defaults))")
        print("📦 driver1Key value: \(String(describing: defaults?.string(forKey: driver1Key)))")
        let entry = Driver1Entry(date: Date(), driver: DriverInfo.fromKey(driver1Key))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct Driver2Provider: TimelineProvider {
    func placeholder(in context: Context) -> Driver2Entry {
        Driver2Entry(date: Date(), driver: DriverInfo.from(code: "VER"))
    }
    func getSnapshot(in context: Context, completion: @escaping (Driver2Entry) -> Void) {
        completion(Driver2Entry(date: Date(), driver: DriverInfo.fromKey(driver2Key)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Driver2Entry>) -> Void) {
        let entry = Driver2Entry(date: Date(), driver: DriverInfo.fromKey(driver2Key))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct Driver3Provider: TimelineProvider {
    func placeholder(in context: Context) -> Driver3Entry {
        Driver3Entry(date: Date(), driver: DriverInfo.from(code: "NOR"))
    }
    func getSnapshot(in context: Context, completion: @escaping (Driver3Entry) -> Void) {
        completion(Driver3Entry(date: Date(), driver: DriverInfo.fromKey(driver3Key)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Driver3Entry>) -> Void) {
        let entry = Driver3Entry(date: Date(), driver: DriverInfo.fromKey(driver3Key))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct Driver4Provider: TimelineProvider {
    func placeholder(in context: Context) -> Driver4Entry {
        Driver4Entry(date: Date(), driver: DriverInfo.from(code: "LEC"))
    }
    func getSnapshot(in context: Context, completion: @escaping (Driver4Entry) -> Void) {
        completion(Driver4Entry(date: Date(), driver: DriverInfo.fromKey(driver4Key)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Driver4Entry>) -> Void) {
        let entry = Driver4Entry(date: Date(), driver: DriverInfo.fromKey(driver4Key))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Shared View

struct DriverWidgetView: View {
    let driver: DriverInfo
    let slotLabel: String

    private let carbonBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(driver.name.uppercased())
                        .font(.system(size: 20, weight: .black, design: .default))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(driver.team.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(driver.teamColor)
                        .tracking(1.5)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(driver.number)")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .fontWidth(.compressed)
                    .italic()
                    .foregroundColor(driver.teamColor)
            }

            Spacer()

            Rectangle()
                .fill(LinearGradient(
                    colors: [driver.teamColor, driver.teamColor.opacity(0.1)],
                    startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .padding(.vertical, 4)

            Text("\(slotLabel) • AWAITING TELEMETRY...")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [carbonBlack, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Four Separate Widgets

struct FavouriteDriver1Widget: Widget {
    let kind: String = "FavouriteDriver1Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver1Provider()) { entry in
            DriverWidgetView(driver: entry.driver, slotLabel: "FAV 1")
        }
        .configurationDisplayName("Favourite Driver 1")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FavouriteDriver2Widget: Widget {
    let kind: String = "FavouriteDriver2Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver2Provider()) { entry in
            DriverWidgetView(driver: entry.driver, slotLabel: "FAV 2")
        }
        .configurationDisplayName("Favourite Driver 2")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FavouriteDriver3Widget: Widget {
    let kind: String = "FavouriteDriver3Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver3Provider()) { entry in
            DriverWidgetView(driver: entry.driver, slotLabel: "FAV 3")
        }
        .configurationDisplayName("Favourite Driver 3")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FavouriteDriver4Widget: Widget {
    let kind: String = "FavouriteDriver4Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver4Provider()) { entry in
            DriverWidgetView(driver: entry.driver, slotLabel: "FAV 4")
        }
        .configurationDisplayName("Favourite Driver 4")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
