import Foundation

// --- 1. Data Models ---
struct F1Driver: Codable, Identifiable {
    var id: Int { driverNumber ?? 0 }
    let driverNumber: Int?
    let fullName: String?
    let nameAcronym: String?
    let teamName: String?
    
    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case fullName = "full_name"
        case nameAcronym = "name_acronym"
        case teamName = "team_name"
    }
}

struct F1Result: Codable {
    let driverNumber: Int?
    let position: Int?
    let points: Double? // Points can be half-points in F1 (e.g., 12.5)
    let dnf: Bool?
    let dns: Bool?
    
    enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case position
        case points
        case dnf
        case dns
    }
}

// The final object that gets saved to the Widget
struct DriverStats: Codable, Identifiable {
    var id: Int { driverNumber }
    let driverNumber: Int
    let fullName: String
    let nameAcronym: String
    let teamName: String
    var points: Double = 0.0
    var wins: Int = 0
    var podiums: Int = 0
    var dnfs: Int = 0
}

// --- 2. The Service ---
class DriverService {
    static let shared = DriverService()
    
    let appGroupDefaults = UserDefaults(suiteName: "group.com.panda.f1widget")
    
    func updateChampionshipStandings() async throws {
        print("📡 Checking for new 2026 race data...")
        
        // 1. Get our "bookmark" (the ID of the last race we calculated)
        let lastProcessedKey = appGroupDefaults?.integer(forKey: "lastProcessedMeetingKey") ?? 0
        
        // 2. Fetch the 2026 Schedule
        guard let sessionsUrl = URL(string: "https://api.openf1.org/v1/sessions?year=2026&session_name=Race") else { return }
        let (sessionData, _) = try await URLSession.shared.data(from: sessionsUrl)
        let raceSessions = try JSONDecoder().decode([F1Session].self, from: sessionData)
        
        let now = Date()
        
        // 3. FILTER: Only get races that have happened AND that are newer than our bookmark
        let newRaces = raceSessions.filter {
            ($0.startDate ?? Date.distantFuture) < now &&
            ($0.meetingKey ?? 0) > lastProcessedKey
        }
        
        if newRaces.isEmpty {
            print("⚡️ No new races found. Widget data is already up to date!")
            return // EXIT EARLY! This saves battery and prevents API rate limits!
        }
        
        print("🏁 Found \(newRaces.count) new race(s)! Updating telemetry...")
        
        // 4. Load the existing scoreboard from the cache, or create a blank one if it's our first time
        var statsDict: [Int: DriverStats] = [:]
        let existingStats = getCachedStandings()
        
        if existingStats.isEmpty {
            // First time running: Fetch the 2026 grid to initialize the dictionary
            print("🆕 First time setup: Fetching 2026 driver grid...")
            guard let driversUrl = URL(string: "https://api.openf1.org/v1/drivers?session_key=latest") else { return }
            let (driverData, _) = try await URLSession.shared.data(from: driversUrl)
            let drivers = try JSONDecoder().decode([F1Driver].self, from: driverData)
            
            for driver in drivers {
                guard let number = driver.driverNumber else { continue }
                statsDict[number] = DriverStats(
                    driverNumber: number,
                    fullName: driver.fullName ?? "Unknown",
                    nameAcronym: driver.nameAcronym ?? "UNK",
                    teamName: driver.teamName ?? "Unknown Team"
                )
            }
        } else {
            // Not our first time: Load the old points into our dictionary so we can add to them
            for stat in existingStats {
                statsDict[stat.driverNumber] = stat
            }
        }
        
        // 5. Fetch ONLY the results for the new races
        var highestMeetingKeyProcessed = lastProcessedKey
        
        for race in newRaces {
            guard let meetingKey = race.meetingKey,
                  let resultsUrl = URL(string: "https://api.openf1.org/v1/session_result?meeting_key=\(meetingKey)") else { continue }
            
            do {
                try await Task.sleep(nanoseconds: 400_000_000) // Respect rate limits
                let (resultData, _) = try await URLSession.shared.data(from: resultsUrl)
                let results = try JSONDecoder().decode([F1Result].self, from: resultData)
                
                for result in results {
                    guard let driverNum = result.driverNumber, statsDict[driverNum] != nil else { continue }
                    
                    // Add new points to existing points!
                    statsDict[driverNum]?.points += result.points ?? 0.0
                    
                    if let pos = result.position {
                        if pos == 1 { statsDict[driverNum]?.wins += 1 }
                        if pos <= 3 { statsDict[driverNum]?.podiums += 1 }
                    }
                    if result.dnf == true || result.dns == true {
                        statsDict[driverNum]?.dnfs += 1
                    }
                }
                
                // Keep track of the highest meeting key we successfully processed
                if meetingKey > highestMeetingKeyProcessed {
                    highestMeetingKeyProcessed = meetingKey
                }
                
            } catch {
                print("⚠️ Failed to fetch results for new meeting \(meetingKey)")
            }
        }
        
        // 6. Sort and Save
        let sortedStandings = statsDict.values.sorted { $0.points > $1.points }
        
        if let encodedData = try? JSONEncoder().encode(sortedStandings) {
            appGroupDefaults?.set(encodedData, forKey: "cachedStandings")
            appGroupDefaults?.set(Date(), forKey: "lastStandingsUpdate")
            
            // SAVE THE BOOKMARK! So we don't calculate these races again tomorrow.
            appGroupDefaults?.set(highestMeetingKeyProcessed, forKey: "lastProcessedMeetingKey")
            
            print("✅ Successfully updated standings with new race data!")
        }
    }
    
    // 7. Helper function for the Widget
    func getCachedStandings() -> [DriverStats] {
        guard let data = appGroupDefaults?.data(forKey: "cachedStandings"),
              let standings = try? JSONDecoder().decode([DriverStats].self, from: data) else {
            return []
        }
        return standings
    }
}
