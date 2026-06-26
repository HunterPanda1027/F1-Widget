import Foundation

// --- 1. Data Models (These were missing!) ---
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
    let points: Double?
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
    var poles: Int = 0
}


// --- 2. The Service ---
class DriverService {
    static let shared = DriverService()
    let appGroupDefaults = UserDefaults(suiteName: "group.com.panda.f1widget")
    
    func updateChampionshipStandings() async throws {
        // Purge cache
        appGroupDefaults?.removeObject(forKey: "cachedStandings")
        appGroupDefaults?.removeObject(forKey: "lastProcessedSessionKey")

        let lastProcessedKey = appGroupDefaults?.integer(forKey: "lastProcessedSessionKey") ?? 0
        
        guard let sessionsUrl = URL(string: "https://api.openf1.org/v1/sessions?year=2026"),
              let driversUrl = URL(string: "https://api.openf1.org/v1/drivers?session_key=latest") else { return }
        
        let (sessionData, _) = try await URLSession.shared.data(from: sessionsUrl)
        let (driverData, _) = try await URLSession.shared.data(from: driversUrl)
        
        let allSessions = try JSONDecoder().decode([F1Session].self, from: sessionData)
        let drivers = try JSONDecoder().decode([F1Driver].self, from: driverData)
        
        var statsDict: [String: DriverStats] = [:]
        var numberToAcronym: [Int: String] = [:]
        
        for driver in drivers {
            guard let acronym = driver.nameAcronym, let num = driver.driverNumber else { continue }
            numberToAcronym[num] = acronym
            statsDict[acronym] = DriverStats(
                driverNumber: num,
                fullName: driver.fullName ?? "Unknown",
                nameAcronym: acronym,
                teamName: driver.teamName ?? "Unknown Team"
            )
        }
        
        let newSessions = allSessions.filter {
            ($0.startDate ?? Date.distantFuture) < Date() &&
            ($0.sessionKey ?? 0) > lastProcessedKey &&
            ["Race", "Qualifying", "Sprint"].contains($0.sessionName ?? "")
        }
        
        var highestSessionKey = lastProcessedKey
        
        for session in newSessions {
            guard let sessionKey = session.sessionKey,
                  let resultsUrl = URL(string: "https://api.openf1.org/v1/session_result?session_key=\(sessionKey)") else { continue }
            
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                let (resultData, _) = try await URLSession.shared.data(from: resultsUrl)
                let results = try JSONDecoder().decode([F1Result].self, from: resultData)
                
                for result in results {
                    guard let num = result.driverNumber,
                          let acronym = numberToAcronym[num],
                          var stats = statsDict[acronym] else { continue }
                    
                    if session.sessionName == "Race" {
                        stats.points += result.points ?? 0.0
                        if let pos = result.position {
                            if pos == 1 { stats.wins += 1 }
                            if pos <= 3 { stats.podiums += 1 }
                        }
                        if result.dnf == true || result.dns == true { stats.dnfs += 1 }
                    } else if session.sessionName == "Sprint" {
                        stats.points += result.points ?? 0.0
                        if result.dnf == true || result.dns == true { stats.dnfs += 1 }
                    } else if session.sessionName == "Qualifying" {
                        if result.position == 1 { stats.poles += 1 }
                    }
                    statsDict[acronym] = stats
                }
                highestSessionKey = max(highestSessionKey, sessionKey)
            } catch { print("⚠️ Error: \(error)") }
        }
        
        let sorted = statsDict.values.sorted { $0.points > $1.points }
        if let encoded = try? JSONEncoder().encode(sorted) {
            appGroupDefaults?.set(encoded, forKey: "cachedStandings")
            appGroupDefaults?.set(highestSessionKey, forKey: "lastProcessedSessionKey")
        }
    }
    
    func getCachedStandings() -> [DriverStats] {
        guard let data = appGroupDefaults?.data(forKey: "cachedStandings"),
              let standings = try? JSONDecoder().decode([DriverStats].self, from: data) else { return [] }
        return standings
    }
}
