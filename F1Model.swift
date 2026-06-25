import Foundation

// --- 1. Session Data ---
struct F1Session: Codable, Identifiable {
    var id: String { "\(meetingKey ?? 0)-\(sessionName ?? UUID().uuidString)" }
    
    let sessionName: String?
    let dateStart: String?
    let circuitShortName: String?
    let meetingKey: Int?
    
    enum CodingKeys: String, CodingKey {
        case sessionName = "session_name"
        case dateStart = "date_start"
        case circuitShortName = "circuit_short_name"
        case meetingKey = "meeting_key"
    }

    var startDate: Date? {
        guard let ds = dateStart, ds.count >= 19 else { return nil }
        let cleanDateString = String(ds.prefix(19))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.date(from: cleanDateString)
    }
}

// --- 2. Meeting Data ---
struct F1Meeting: Codable {
    let meetingKey: Int?
    let meetingName: String?
    let circuitShortName: String?
    let dateStart: String? // Added to check the date
    
    enum CodingKeys: String, CodingKey {
        case meetingKey = "meeting_key"
        case meetingName = "meeting_name"
        case circuitShortName = "circuit_short_name"
        case dateStart = "date_start"
    }
    
    // Convert the string to a Date object
    var startDate: Date? {
        guard let ds = dateStart, ds.count >= 19 else { return nil }
        let cleanDateString = String(ds.prefix(19))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.date(from: cleanDateString)
    }
}

// --- 3. Network Service ---
class F1Service {
    static let shared = F1Service()
    
    func fetchNextMeeting() async throws -> F1Meeting? {
        let urlString = "https://api.openf1.org/v1/meetings?year=2026"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let meetings = try JSONDecoder().decode([F1Meeting].self, from: data)
        
        let now = Date()
        // Find the first meeting where the weekend hasn't completely ended yet
        // We add 3 days (259,200 seconds) to the start date to account for the whole weekend
        return meetings.first { meeting in
            if let startDate = meeting.startDate {
                let endOfWeekend = startDate.addingTimeInterval(259200)
                return endOfWeekend > now
            }
            return false
        }
    }
    
    func fetchSessions(for meetingKey: Int) async throws -> [F1Session] {
        let urlString = "https://api.openf1.org/v1/sessions?meeting_key=\(meetingKey)"
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([F1Session].self, from: data)
    }
}
