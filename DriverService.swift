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
            // 🚨 FORCE RESET: Bypassing the cache memory to force a full season rebuild
            let lastProcessedKey = 0
            
            guard let sessionsUrl = URL(string: "https://api.openf1.org/v1/sessions?year=2026") else { return }
            
            let (sessionData, _) = try await URLSession.shared.data(from: sessionsUrl)
            if let rawJSON = String(data: sessionData, encoding: .utf8), rawJSON.contains("restricted") {
                print("🛑 API Blocked: Live session in progress. Widget will use cached standings.")
                return
            }
            
            let allSessions = try JSONDecoder().decode([F1Session].self, from: sessionData)
            
            var statsDict: [String: DriverStats] = [:]
            var numberToAcronym: [Int: String] = [:]
            
            // Load your hardcoded 2026 grid
            let drivers = DriverInfo.all
            
            for driver in drivers {
                let acronym = driver.code
                let num = driver.number
                
                numberToAcronym[num] = acronym
                statsDict[acronym] = DriverStats(
                    driverNumber: num,
                    fullName: driver.name,
                    nameAcronym: acronym,
                    teamName: driver.team
                )
            }
            
            let newSessions = allSessions.filter {
                ($0.startDate ?? Date.distantFuture) < Date() &&
                ($0.sessionKey ?? 0) > lastProcessedKey &&
                ["Race", "Sprint"].contains($0.sessionName ?? "") // Removed Qualifying since no points are awarded
            }
            
            var highestSessionKey = lastProcessedKey
            
            for session in newSessions {
                // 🚨 INCREASED DELAY: 1 full second to guarantee we stay under the limit
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                guard let sessionKey = session.sessionKey,
                      let resultsUrl = URL(string: "https://api.openf1.org/v1/session_result?session_key=\(sessionKey)") else { continue }
                
                do {
                    let (resultData, _) = try await URLSession.shared.data(from: resultsUrl)
                    let results = try JSONDecoder().decode([F1Result].self, from: resultData)
                    
                    for result in results {
                        guard let num = result.driverNumber,
                              let acronym = numberToAcronym[num],
                              var stats = statsDict[acronym],
                              let pos = result.position else { continue }
                        
                        if session.sessionName == "Race" {
                            // Manual point calculation in case API returns nil
                            let racePoints = [1: 25.0, 2: 18.0, 3: 15.0, 4: 12.0, 5: 10.0, 6: 8.0, 7: 6.0, 8: 4.0, 9: 2.0, 10: 1.0]
                            stats.points += result.points ?? (racePoints[pos] ?? 0.0)
                            
                            if pos == 1 { stats.wins += 1 }
                            if pos <= 3 { stats.podiums += 1 }
                            if result.dnf == true || result.dns == true { stats.dnfs += 1 }
                            
                        } else if session.sessionName == "Sprint" {
                            let sprintPoints = [1: 8.0, 2: 7.0, 3: 6.0, 4: 5.0, 5: 4.0, 6: 3.0, 7: 2.0, 8: 1.0]
                            stats.points += result.points ?? (sprintPoints[pos] ?? 0.0)
                            
                            if result.dnf == true || result.dns == true { stats.dnfs += 1 }
                        }
                        
                        statsDict[acronym] = stats
                    }
                    highestSessionKey = max(highestSessionKey, sessionKey)
                    
                } catch {
                    // This will tell you if a specific session failed to decode
                    print("⚠️ Error processing session \(sessionKey): \(error)")
                }
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
