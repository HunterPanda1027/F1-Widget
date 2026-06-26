import WidgetKit
import SwiftUI

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
        completion(F1Entry(date: Date(), gpName: "F1 Grand Prix", locationName: "Circuit", targetSessionName: "Race", targetSessionDate: Date().addingTimeInterval(86400), weekendSchedule: [], imageName: "Default"))
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
                
                // 3. CONSTRUCT TIMELINE (Whether it came from network or cache)
                if let meeting = nextMeeting {
                    let nextSession = weekendSessions.first { ($0.startDate ?? Date.distantPast) > now }
                    
                    let entry = F1Entry(
                        date: now,
                        gpName: meeting.meetingName ?? "Unknown GP",
                        locationName: meeting.circuitShortName ?? "Unknown Location",
                        targetSessionName: nextSession?.sessionName,
                        targetSessionDate: nextSession?.startDate,
                        weekendSchedule: weekendSessions,
                        imageName: self.getMappedImageName(for: meeting.circuitShortName ?? "")
                    )
                    
                    // Refresh 1 minute after this session starts to transition cleanly
                    let refreshDate = nextSession?.startDate?.addingTimeInterval(60) ?? now.addingTimeInterval(3600)
                    let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
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

    let rossoCorsa = Color(red: 0.937, green: 0.102, blue: 0.176)
    let carbonBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            
            // LEFT SIDE: Text and Schedule
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.gpName.uppercased())
                    .font(.system(size: 13, weight: .black, design: .default))
                    .fontWidth(.compressed)
                    .italic()
                    .foregroundColor(rossoCorsa)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(entry.locationName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(1.5)
                    .lineLimit(1)
                
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [rossoCorsa, rossoCorsa.opacity(0.1)]), startPoint: .leading, endPoint: .trailing))
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
                                    .foregroundColor(isTargetSession ? rossoCorsa : .white)
                                Spacer()
                                Text(formatLocalTime(for: session.startDate))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(isTargetSession ? .white : .gray)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // RIGHT SIDE: High-Speed Countdown & Track Image
            VStack(alignment: .trailing, spacing: 8) {
                
                // DYNAMIC RACING COUNTDOWN
                if let targetDate = entry.targetSessionDate, let targetName = entry.targetSessionName {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("UNTIL \(shortName(for: targetName))")
                            .font(.system(size: 11, weight: .black, design: .default))
                            .fontWidth(.expanded)
                            .italic()
                            .foregroundColor(rossoCorsa)
                            .tracking(0.5)
                        
                        if targetDate > Date() {
                            Text(targetDate, style: .timer)
                                .font(.system(size: 30, weight: .black, design: .default))
                                .fontWidth(.compressed)
                                .italic()
                                .monospacedDigit()
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                // 🛠️ ADD THESE TWO LINES:
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text("LIVE")
                                .font(.system(size: 34, weight: .black, design: .default))
                                .fontWidth(.compressed)
                                .italic()
                                .foregroundColor(rossoCorsa)
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                // THE TRACK
                Image(entry.imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 100, maxHeight: 80)
                    .foregroundColor(rossoCorsa.opacity(0.8))
                    .shadow(color: rossoCorsa.opacity(0.4), radius: 3, x: 0, y: 0)
            }
            .padding(.trailing, 0)
            .padding(.vertical, 2)
        }
        .containerBackground(for: .widget) {
            LinearGradient(gradient: Gradient(colors: [carbonBlack, .black]), startPoint: .topLeading, endPoint: .bottomTrailing)
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
