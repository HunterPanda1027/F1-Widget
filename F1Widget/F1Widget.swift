import WidgetKit
import SwiftUI

// MARK: - Favourite Team support
// NOTE: This block must be visible to BOTH the app and the widget extension,
// exactly like your DriverInfo / appGroupID file. If `TeamInfo` or these keys
// don't resolve in ContentView, tick this file's app-target membership in the
// File Inspector, or move this block into your shared Driver model file.

let team1Key = "selectedTeam1"
let team2Key = "selectedTeam2"

struct TeamInfo {
    let name: String

    // Colour reuses the same source of truth as the drivers.
    var color: Color { DriverInfo.teamColors[name] ?? Color(red: 0.937, green: 0.102, blue: 0.176) }

    // Logo asset name — add an image named after each team (e.g. "Ferrari",
    // "McLaren", "Red Bull") to the widget extension's asset catalog.
    var logoName: String { name }

    // Explicit ordering so the picker is stable across launches.
    static let all: [TeamInfo] = [
        "Ferrari", "McLaren", "Mercedes", "Red Bull", "Aston Martin", "Alpine",
        "Williams", "Racing Bulls", "Haas", "Audi", "Cadillac",
    ].map { TeamInfo(name: $0) }

    static func from(name: String) -> TeamInfo {
        all.first { $0.name == name } ?? all[0]
    }

    static func fromKey(_ key: String) -> TeamInfo {
        let name = UserDefaults(suiteName: appGroupID)?.string(forKey: key) ?? "Ferrari"
        return from(name: name)
    }
}

// 1. The Timeline Entry
struct F1Entry: TimelineEntry {
    let date: Date
    let gpName: String
    let locationName: String
    let targetSessionName: String?
    let targetSessionDate: Date?
    let weekendSchedule: [F1Session]
    let imageName: String
}

// 2. The Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> F1Entry {
        F1Entry(date: Date(), gpName: "Canadian Grand Prix", locationName: "Montréal", targetSessionName: "Practice 1", targetSessionDate: Date().addingTimeInterval(86400), weekendSchedule: [], imageName: "Montréal")
    }

    func getSnapshot(in context: Context, completion: @escaping (F1Entry) -> ()) {
        let now = Date()
        let defaults = UserDefaults(suiteName: appGroupID)

        // Prefer the last cached weekend so the snapshot shows real telemetry
        // instead of an empty schedule.
        if let meetingData = defaults?.data(forKey: "backup_cached_meeting"),
           let meeting = try? JSONDecoder().decode(F1Meeting.self, from: meetingData) {

            var sessions: [F1Session] = []
            if let sessionsData = defaults?.data(forKey: "backup_cached_sessions"),
               let decoded = try? JSONDecoder().decode([F1Session].self, from: sessionsData) {
                sessions = decoded
            }

            let nextSession = sessions.first { ($0.startDate ?? .distantPast).addingTimeInterval(7200) > now }

            completion(F1Entry(
                date: now,
                gpName: meeting.meetingName ?? "F1 Grand Prix",
                locationName: meeting.circuitShortName ?? "Circuit",
                targetSessionName: nextSession?.sessionName,
                targetSessionDate: nextSession?.startDate,
                weekendSchedule: sessions,
                imageName: getMappedImageName(for: meeting.circuitShortName ?? "")
            ))
        } else {
            // No cache yet — original placeholder-style snapshot.
            completion(F1Entry(date: Date(), gpName: "F1 Grand Prix", locationName: "Circuit", targetSessionName: "Race", targetSessionDate: Date().addingTimeInterval(86400), weekendSchedule: [], imageName: "Default"))
        }
    }
    
    func getMappedImageName(for apiLocation: String) -> String {
        let mapping: [String: String] = [
            "Sakhir": "Bahrain", "Jeddah": "Jeddah", "Melbourne": "Melbourne",
            "Suzuka": "Suzuka", "Shanghai": "Shanghai", "Miami": "Miami",
            "Imola": "Imola", "Monaco": "Monaco", "Montréal": "Montreal",
            "Barcelona": "Barcelona", "Madrid": "Madrid", "Spielberg": "Spielberg",
            "Silverstone": "Silverstone", "Budapest": "Budapest", "Spa-Francorchamps": "Spa",
            "Zandvoort": "Zandvoort", "Monza": "Monza", "Baku": "Baku",
            "Singapore": "Singapore", "Austin": "Austin", "Mexico City": "MexicoCity",
            "São Paulo": "SaoPaulo", "Las Vegas": "LasVegas", "Lusail": "Lusail",
            "Yas Island": "YasMarina"
        ]
        return mapping[apiLocation] ?? "Default"
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<F1Entry>) -> ()) {
            Task {
                let appGroupDefaults = UserDefaults(suiteName: appGroupID)
                let now = Date()
                
                var nextMeeting: F1Meeting? = nil
                var weekendSessions: [F1Session] = []
                var apiIsBlocked = false
                
                do {
                    // 1. Attempt to fetch fresh data from the network
                    if let meeting = try await F1Service.shared.fetchNextMeeting(), let meetingKey = meeting.meetingKey {
                        nextMeeting = meeting
                        weekendSessions = (try? await F1Service.shared.fetchSessions(for: meetingKey)) ?? []
                        
                        // 💾 SUCCESS: Save this fresh data to the local backup cache
                        if let encodedMeeting = try? JSONEncoder().encode(meeting) {
                            appGroupDefaults?.set(encodedMeeting, forKey: "backup_cached_meeting")
                        }
                        if let encodedSessions = try? JSONEncoder().encode(weekendSessions) {
                            appGroupDefaults?.set(encodedSessions, forKey: "backup_cached_sessions")
                        }
                    }
                } catch {
                    print("🌐 API Request failed or restricted during live session. Attempting cache fallback...")
                    apiIsBlocked = true
                }
                
                // 2. FALLBACK LAYER: If network failed, look for the last known good data in the cache
                if nextMeeting == nil {
                    if let savedMeetingData = appGroupDefaults?.data(forKey: "backup_cached_meeting"),
                       let cachedMeeting = try? JSONDecoder().decode(F1Meeting.self, from: savedMeetingData) {
                        nextMeeting = cachedMeeting
                    }
                    
                    if let savedSessionsData = appGroupDefaults?.data(forKey: "backup_cached_sessions"),
                       let cachedSessions = try? JSONDecoder().decode([F1Session].self, from: savedSessionsData) {
                        weekendSessions = cachedSessions
                    }
                }
                
                // 3. CONSTRUCT TIMELINE
                if let meeting = nextMeeting {
                    
                    let liveWindowDuration: TimeInterval = apiIsBlocked ? 18000 : 7200
                    
                    let nextSession = weekendSessions.first { session in
                        let sessionStart = session.startDate ?? Date.distantPast
                        let sessionEnd = sessionStart.addingTimeInterval(liveWindowDuration)
                        return sessionEnd > now
                    }
                    
                    var entries: [F1Entry] = []
                    
                    if let targetDate = nextSession?.startDate {
                        let oneHourBefore = targetDate.addingTimeInterval(-3600)
                        var currentUpdate = now
                        
                        // Generate an entry every minute until the 1-hour mark
                        while currentUpdate < oneHourBefore && entries.count < 60 {
                            entries.append(F1Entry(
                                date: currentUpdate,
                                gpName: meeting.meetingName ?? "Unknown GP",
                                locationName: meeting.circuitShortName ?? "Unknown Location",
                                targetSessionName: nextSession?.sessionName,
                                targetSessionDate: nextSession?.startDate,
                                weekendSchedule: weekendSessions,
                                imageName: self.getMappedImageName(for: meeting.circuitShortName ?? "")
                            ))
                            currentUpdate = currentUpdate.addingTimeInterval(60)
                        }
                        
                        // Add the crucial entry for exactly 1 hour before
                        if oneHourBefore > now {
                            entries.append(F1Entry(
                                date: oneHourBefore,
                                gpName: meeting.meetingName ?? "Unknown GP",
                                locationName: meeting.circuitShortName ?? "Unknown Location",
                                targetSessionName: nextSession?.sessionName,
                                targetSessionDate: nextSession?.startDate,
                                weekendSchedule: weekendSessions,
                                imageName: self.getMappedImageName(for: meeting.circuitShortName ?? "")
                            ))
                        }
                        
                        // 🚨 CRITICAL FIX: Prevent the Empty Array Freeze 🚨
                        // If we are already within 1 hour, or already LIVE, the array will be empty.
                        // We MUST append an entry for 'now' so the widget updates to LIVE or native Timer.
                        if entries.isEmpty {
                            entries.append(F1Entry(
                                date: now,
                                gpName: meeting.meetingName ?? "Unknown GP",
                                locationName: meeting.circuitShortName ?? "Unknown Location",
                                targetSessionName: nextSession?.sessionName,
                                targetSessionDate: nextSession?.startDate,
                                weekendSchedule: weekendSessions,
                                imageName: self.getMappedImageName(for: meeting.circuitShortName ?? "")
                            ))
                        }
                        
                    } else {
                        // Fallback if no target date
                        entries.append(F1Entry(
                            date: now,
                            gpName: meeting.meetingName ?? "Unknown GP",
                            locationName: meeting.circuitShortName ?? "Unknown Location",
                            targetSessionName: nil,
                            targetSessionDate: nil,
                            weekendSchedule: weekendSessions,
                            imageName: self.getMappedImageName(for: meeting.circuitShortName ?? "")
                        ))
                    }
                    
                    let refreshDate = nextSession?.startDate?.addingTimeInterval(60) ?? now.addingTimeInterval(3600)
                    let timeline = Timeline(entries: entries, policy: .after(refreshDate))
                    completion(timeline)
                    return
                }
                
                // 4. ABSOLUTE WORST-CASE FALLBACK: Run only if there is zero internet AND zero cached data
                let absoluteFallback = F1Entry(
                    date: now,
                    gpName: "No Race Data Available",
                    locationName: "Please check internet connection",
                    targetSessionName: nil,
                    targetSessionDate: nil,
                    weekendSchedule: [],
                    imageName: "Default"
                )
                completion(Timeline(entries: [absoluteFallback], policy: .after(now.addingTimeInterval(1800))))
            }
        }
}

// 3. The View (Polished Telemetry Typography)
struct F1WidgetEntryView : View {
    var entry: F1Entry
    var teamKey: String? = nil   // nil → original Ferrari-red countdown widget

    let rossoCorsa = Color(red: 0.937, green: 0.102, blue: 0.176)
    let carbonBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    // Team theming — only resolved when a teamKey is supplied.
    private var team: TeamInfo? { teamKey.map { TeamInfo.fromKey($0) } }
    private var themeColor: Color { team?.color ?? rossoCorsa }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            
            // RIGHT SIDE: Large Background Track, Large Telemetry Overlay
            ZStack(alignment: .bottomLeading) {
                
                // 1. BACKGROUND TRACK (Pushed up slightly)
                Image(entry.imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(themeColor.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding(.bottom, 25) // Pushes the track map up
                    .padding(.trailing, 5)
                
                // TELEMETRY BAR (Expanded to fill the space)
                if let targetDate = entry.targetSessionDate, let targetName = entry.targetSessionName {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // 1. THE BIG TIMER
                        if targetDate > entry.date {
                            let timeRemaining = targetDate.timeIntervalSince(entry.date)
                            
                            if timeRemaining > 3600 {
                                // 🟢 MORE THAN 1 HOUR: Manual HH:mm format
                                let hours = Int(timeRemaining) / 3600
                                let minutes = (Int(timeRemaining) % 3600) / 60
                                
                                Text("\(hours):\(String(format: "%02d", minutes))")
                                    .font(.system(size: 46, weight: .black, design: .monospaced))
                                    .fontWidth(.compressed)
                                    .italic()
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 0.1, x: 1, y: 0)
                                    .shadow(color: .black, radius: 0.1, x: -1, y: 0)
                                    .shadow(color: .black, radius: 0.1, x: 0, y: 1)
                                    .shadow(color: .black, radius: 0.1, x: 0, y: -1)
                            } else {
                                // 🔴 LESS THAN 1 HOUR: Native Timer (MM:ss)
                                Text(targetDate, style: .timer)
                                    .font(.system(size: 46, weight: .black, design: .monospaced))
                                    .fontWidth(.compressed)
                                    .italic()
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 0.1, x: 1, y: 0)
                                    .shadow(color: .black, radius: 0.1, x: -1, y: 0)
                                    .shadow(color: .black, radius: 0.1, x: 0, y: 1)
                                    .shadow(color: .black, radius: 0.1, x: 0, y: -1)
                            }
                        } else {
                            Text("LIVE")
                                .font(.system(size: 46, weight: .black, design: .monospaced))
                                .fontWidth(.compressed)
                                .italic()
                                .foregroundColor(.white)
                        }
                        
                        // 2. THE "UNTIL" LABEL
                        if targetDate > entry.date {
                            HStack(spacing: 0) {
                                Spacer()
                                Text("UNTIL \(shortName(for: targetName))".uppercased())
                                    .font(.system(size: 11, weight: .black, design: .default))
                                    .fontWidth(.expanded)
                                    .italic()
                                    .foregroundColor(themeColor)
                                    .padding(.trailing, 4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 2)
                    .padding(.bottom, 2)
                } else {
                    // STANDBY STATE
                    VStack(alignment: .leading, spacing: 0) {
                        Text("STANDBY")
                            .font(.system(size: 46, weight: .black, design: .monospaced))
                            .fontWidth(.compressed)
                            .italic()
                            .foregroundColor(.gray.opacity(0.3))
                        
                        HStack(spacing: 0) {
                            Spacer()
                            Text("AWAITING NEXT EVENT")
                                .font(.system(size: 11, weight: .black, design: .default))
                                .fontWidth(.expanded)
                                .italic()
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.trailing, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.leading, 2)
                    .padding(.bottom, 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer(minLength: 0)

            // LEFT SIDE: Text and Schedule
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.gpName.uppercased())
                    .font(.system(size: 20, weight: .black, design: .default))
                    .fontWidth(.compressed)
                    .italic()
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(entry.locationName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(1.5)
                    .lineLimit(1)
                
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [themeColor, themeColor.opacity(0.1)]), startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                    .padding(.vertical, 4)
                
                if entry.weekendSchedule.isEmpty {
                    Text("AWAITING TELEMETRY...")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    VStack(spacing: 5) {
                        ForEach(entry.weekendSchedule.prefix(5)) { session in
                            HStack {
                                let isTargetSession = session.sessionName == entry.targetSessionName
                                
                                Text(shortName(for: session.sessionName ?? "Session").uppercased())
                                    .font(.system(size: 10, weight: isTargetSession ? .black : .heavy))
                                    .italic(isTargetSession)
                                    .foregroundColor(isTargetSession ? themeColor : .white)
                                Spacer()
                                Text(formatLocalTime(for: session.startDate))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(isTargetSession ? .white : .gray)
                            }
                        }
                    }
                }
            }
            .background(alignment: .center) {
                // Faint, team-coloured logo behind the left-side schedule —
                // mirrors the driver widgets. Only shown on the team widgets.
                if let team {
                    Image(team.logoName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(themeColor)
                        .opacity(0.3)
                        .padding(8)
                }
            }
        }
        .containerBackground(for: .widget) {
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [carbonBlack, .black]), startPoint: .topLeading, endPoint: .bottomTrailing)
         
                        // Team-coloured wash. Always present (no conditional view in
                        // the container background), fully transparent when there's
                        // no team so the default widget looks like the original.
                        LinearGradient(
                            gradient: Gradient(colors: [themeColor.opacity(team == nil ? 0.0 : 0.2), .clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
    }
    
    // --- Helpers ---
    // (Removed formatCountdown since SwiftUI handles it natively now!)
    
    func formatLocalTime(for date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date).uppercased()
    }
    
    func shortName(for name: String) -> String {
        switch name {
        case "Practice 1": return "FP1"
        case "Practice 2": return "FP2"
        case "Practice 3": return "FP3"
        case "Qualifying": return "QUALI"
        case "Sprint Qualifying": return "SQ"
        case "Race": return "RACE"
        default: return name.uppercased()
        }
    }
}

// 4. Widget Config
struct F1Widget: Widget {
    let kind: String = "F1Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            F1WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Scuderia Tracker")
        .description("Live telemetry and schedules for the Grand Prix.")
        .supportedFamilies([.systemMedium])
    }
}

// 5. Team-themed countdown widgets — same race data, your team's colours + logo.
struct FavouriteTeam1Widget: Widget {
    let kind: String = "FavouriteTeam1Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            F1WidgetEntryView(entry: entry, teamKey: team1Key)
        }
        .configurationDisplayName("Team Tracker 1")
        .description("Grand Prix countdown in your favourite team's colours.")
        .supportedFamilies([.systemMedium])
    }
}

struct FavouriteTeam2Widget: Widget {
    let kind: String = "FavouriteTeam2Widget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            F1WidgetEntryView(entry: entry, teamKey: team2Key)
        }
        .configurationDisplayName("Team Tracker 2")
        .description("Grand Prix countdown in your favourite team's colours.")
        .supportedFamilies([.systemMedium])
    }
}
