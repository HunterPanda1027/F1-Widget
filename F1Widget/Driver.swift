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
        "Alpine":        Color(red: 1.0, green: 0.53, blue: 0.820),
        "Williams":      Color(red: 0.0,   green: 0.459, blue: 0.843),
        "Racing Bulls":  Color(red: 0.38,  green: 0.0,   blue: 0.82),
        "Haas":          Color(red: 0.9,   green: 0.15,  blue: 0.15),
        "Audi":          Color(red: 0.961, green: 0.020, blue: 0.216),
        "Cadillac":      Color(red: 1.0,   green: 1.0, blue: 1.0),
    ]

    static let all: [DriverInfo] = [
        DriverInfo(code: "HAM", name: "Lewis Hamilton",    team: "Ferrari",      number: 44,  teamColor: teamColors["Ferrari"]!),
        DriverInfo(code: "LEC", name: "Charles Leclerc",   team: "Ferrari",      number: 16,  teamColor: teamColors["Ferrari"]!),
        DriverInfo(code: "NOR", name: "Lando Norris",      team: "McLaren",      number: 1,   teamColor: teamColors["McLaren"]!),
        DriverInfo(code: "PIA", name: "Oscar Piastri",     team: "McLaren",      number: 81,  teamColor: teamColors["McLaren"]!),
        DriverInfo(code: "RUS", name: "George Russell",    team: "Mercedes",     number: 63,  teamColor: teamColors["Mercedes"]!),
        DriverInfo(code: "ANT", name: "Kimi Antonelli",    team: "Mercedes",     number: 12,  teamColor: teamColors["Mercedes"]!),
        DriverInfo(code: "VER", name: "Max Verstappen",    team: "Red Bull",     number: 3,   teamColor: teamColors["Red Bull"]!),
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

// MARK: - Timeline Entry
struct DriverEntry: TimelineEntry {
    let date: Date
    let driver: DriverInfo
    let stats: DriverStats?
}

// MARK: - Helper to fetch stats
func getStatsFor(driver: DriverInfo) -> DriverStats? {
    let allStats = DriverService.shared.getCachedStandings()
    return allStats.first { $0.nameAcronym.uppercased() == driver.code }
}

// MARK: - Providers

struct Driver1Provider: TimelineProvider {
    func placeholder(in context: Context) -> DriverEntry {
        DriverEntry(date: Date(), driver: DriverInfo.from(code: "HAM"), stats: DriverStats(driverNumber: 44, fullName: "Lewis Hamilton", nameAcronym: "HAM", teamName: "Ferrari", points: 150, wins: 2, podiums: 5, dnfs: 0))
    }
    func getSnapshot(in context: Context, completion: @escaping (DriverEntry) -> Void) {
        let driver = DriverInfo.fromKey(driver1Key)
        completion(DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DriverEntry>) -> Void) {
        let driver = DriverInfo.fromKey(driver1Key)
        let entry = DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct Driver2Provider: TimelineProvider {
    func placeholder(in context: Context) -> DriverEntry {
        DriverEntry(date: Date(), driver: DriverInfo.from(code: "VER"), stats: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (DriverEntry) -> Void) {
        let driver = DriverInfo.fromKey(driver2Key)
        completion(DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DriverEntry>) -> Void) {
        let driver = DriverInfo.fromKey(driver2Key)
        let entry = DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct Driver3Provider: TimelineProvider {
    func placeholder(in context: Context) -> DriverEntry {
        DriverEntry(date: Date(), driver: DriverInfo.from(code: "NOR"), stats: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (DriverEntry) -> Void) {
        let driver = DriverInfo.fromKey(driver3Key)
        completion(DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DriverEntry>) -> Void) {
        let driver = DriverInfo.fromKey(driver3Key)
        let entry = DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct Driver4Provider: TimelineProvider {
    func placeholder(in context: Context) -> DriverEntry {
        DriverEntry(date: Date(), driver: DriverInfo.from(code: "LEC"), stats: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (DriverEntry) -> Void) {
        let driver = DriverInfo.fromKey(driver4Key)
        completion(DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DriverEntry>) -> Void) {
        let driver = DriverInfo.fromKey(driver4Key)
        let entry = DriverEntry(date: Date(), driver: driver, stats: getStatsFor(driver: driver))
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Shared View

struct DriverWidgetView: View {
    let driver: DriverInfo
    let stats: DriverStats?
    let slotLabel: String

    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.widgetContentMargins) private var widgetMargins

    private let carbonBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    var body: some View {
        Group {
            if widgetFamily == .systemSmall {
                smallWidgetLayout
            } else {
                mediumWidgetLayout
            }
        }
        .containerBackground(for: .widget) {
            if widgetFamily == .systemSmall {
                // Background art lives here so it fills edge-to-edge and is
                // clipped to the widget bounds.
                ZStack {
                    carbonBlack

                    // Driver photo — fills the whole widget, clearer than before
                    Image(driver.code)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.70)

                    // Legibility gradient: a touch of team colour up top, mostly
                    // clear through the middle (so the photo shows), deep black at
                    // the bottom where the stats sit.
                    LinearGradient(
                        stops: [
                            .init(color: driver.teamColor.opacity(0.30), location: 0.0),
                            .init(color: .black.opacity(0.25),           location: 0.40),
                            .init(color: .black.opacity(0.92),           location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Ghost race number — fixed size so every driver looks the same
                    Text("\(driver.number)")
                        .font(.system(size: 100, weight: .black))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(driver.teamColor.opacity(0.30))
                        .fixedSize()                       // never shrink → consistent glyphs
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: 8, y: 6)
                        .clipped()
                }
            } else {
                ZStack {
                    carbonBlack

                    RadialGradient(
                        gradient: Gradient(colors: [driver.teamColor.opacity(0.25), .clear]),
                        center: .trailing,
                        startRadius: 10,
                        endRadius: 180
                    )
                }
            }
        }
    }

    // MARK: - SMALL LAYOUT
    // Foreground content only — the image and gradient are in the
    // containerBackground above.
    var smallWidgetLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(driver.name.uppercased())
                .font(.system(size: 22, weight: .black))
                .fontWidth(.compressed)
                .italic()
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(driver.team.uppercased())
                .font(.system(size: 11, weight: .black))
                .tracking(1)
                .foregroundColor(driver.teamColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Team accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(driver.teamColor)
                .frame(width: 42, height: 3.5)
                .padding(.top, 6)

            Spacer(minLength: 4)

            // Stats
            if let stats = stats {
                // Hero: points on its own line
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%g", stats.points))
                        .font(.system(size: 56, weight: .black))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("PTS")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.gray)
                }

                // Secondary stats below — bigger pills
                HStack(spacing: 7) {
                    StatBlock(title: "WIN", value: stats.wins, teamColor: driver.teamColor,
                              titleSize: 12, valueSize: 16, minWidth: 30, vPadding: 7)
                    StatBlock(title: "POD", value: stats.podiums, teamColor: driver.teamColor,
                              titleSize: 12, valueSize: 16, minWidth: 30, vPadding: 7)
                    StatBlock(title: "POLE", value: stats.poles, teamColor: driver.teamColor,
                              titleSize: 12, valueSize: 16, minWidth: 30, vPadding: 7)
                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
            }
        }
        .padding(widgetMargins)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - MEDIUM LAYOUT
    var mediumWidgetLayout: some View {
        HStack(alignment: .bottom, spacing: 0) {
            
            // LEFT COLUMN
            VStack(alignment: .leading, spacing: 0) {
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(driver.name.uppercased())
                        .font(.system(size: 28, weight: .black, design: .default))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(driver.team.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(driver.teamColor)
                        .tracking(1.5)
                        .lineLimit(1)
                }
                
                // POINTS (replaces the driver number)
                Spacer(minLength: 5)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(stats.map { String(format: "%g", $0.points) } ?? "–")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(.white)
                    Text("PTS")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.gray)
                }

                Spacer(minLength: 5)

                // BOTTOM: just the stats (divider removed)
                if let stats = stats {
                    HStack(spacing: 6) {
                        StatBlock(title: "WIN", value: stats.wins, teamColor: driver.teamColor)
                        StatBlock(title: "POD", value: stats.podiums, teamColor: driver.teamColor)
                        StatBlock(title: "POLE", value: stats.poles, teamColor: driver.teamColor)
                        StatBlock(title: "DNF", value: stats.dnfs, teamColor: driver.teamColor)
                        Spacer(minLength: 0)
                    }
                } else {
                    Text("\(slotLabel) • AWAITING...")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(widgetMargins)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .center) {
                // Faint team-coloured logo behind the left-side content.
                // Replace "f1_logo" with your actual asset name.
                Image(driver.team)
                    .resizable()
                    .renderingMode(.template)          // lets us tint it
                    .scaledToFit()
                    .foregroundColor(driver.teamColor)
                    .opacity(0.3)                     // faint
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(widgetMargins)           // inset to match the text margins
            }
            .padding(.trailing, 4)

            // RIGHT COLUMN — driver photo with the race number faint behind it
            ZStack(alignment: .topTrailing) {
                // Ghost race number — top-right, above the photo so it reads clearly
                HStack(spacing: 0) {
                    Text("\(driver.number)")
                        .font(.system(size: 90, weight: .black))
                        .fontWidth(.compressed)
                        .italic()
                        .foregroundColor(driver.teamColor.opacity(0.30))

                    // Single-digit numbers get an invisible second digit so the
                    // visible digit sits in the "tens" slot instead of the edge.
                    if driver.number < 10 {
                        Text("0")
                            .font(.system(size: 90, weight: .black))
                            .fontWidth(.compressed)
                            .italic()
                            .hidden()
                    }
                }
                .fixedSize()
                .offset(x: 8, y: -4)

                Image(driver.code)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 160, maxHeight: .infinity, alignment: .bottom)
                    .padding(.top, 12)
                    .padding(.bottom, 0)
                    .offset(x: -16)
            }
            .frame(maxWidth: 160, maxHeight: .infinity, alignment: .bottom)
        }
    }}

// MARK: - Redesigned Telemetry Stat Block
struct StatBlock: View {
    let title: String
    let value: Int
    let teamColor: Color // Added to support styling

    // Sizing knobs — defaults keep the medium layout exactly as before.
    var titleSize: CGFloat = 9
    var valueSize: CGFloat = 16
    var minWidth: CGFloat = 27
    var vPadding: CGFloat = 4
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.system(size: titleSize, weight: .black))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text("\(value)")
                .font(.system(size: valueSize, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.vertical, vPadding)
        .frame(minWidth: minWidth)
        .background(Color.white.opacity(0.05)) // Subtle glass pill background
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(teamColor.opacity(0.3), lineWidth: 1) // Dynamic subtle border
        )
    }
}

// MARK: - Four Separate Widgets

struct FavouriteDriver1Widget: Widget {
    let kind: String = "FavouriteDriver1Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver1Provider()) { entry in
            DriverWidgetView(driver: entry.driver, stats: entry.stats, slotLabel: "FAV 1")
        }
        .configurationDisplayName("Favourite Driver 1")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct FavouriteDriver2Widget: Widget {
    let kind: String = "FavouriteDriver2Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver2Provider()) { entry in
            DriverWidgetView(driver: entry.driver, stats: entry.stats, slotLabel: "FAV 2")
        }
        .configurationDisplayName("Favourite Driver 2")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct FavouriteDriver3Widget: Widget {
    let kind: String = "FavouriteDriver3Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver3Provider()) { entry in
            DriverWidgetView(driver: entry.driver, stats: entry.stats, slotLabel: "FAV 3")
        }
        .configurationDisplayName("Favourite Driver 3")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct FavouriteDriver4Widget: Widget {
    let kind: String = "FavouriteDriver4Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Driver4Provider()) { entry in
            DriverWidgetView(driver: entry.driver, stats: entry.stats, slotLabel: "FAV 4")
        }
        .configurationDisplayName("Favourite Driver 4")
        .description("Set your favourite driver in the F1 Widget app.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
