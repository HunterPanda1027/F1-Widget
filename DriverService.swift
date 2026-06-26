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
    var poles: Int = 0 // 🏎️ NEW: Added Poles!
}

// --- 2. The Service ---
class DriverService {
    static let shared = DriverService()
    
    let appGroupDefaults = UserDefaults(suiteName: "group.com.panda.f1widget")
    
    func updateChampionshipStandings() async throws {
        appGroupDefaults?.removeObject(forKey: "cachedStandings")
        appGroupDefaults?.removeObject(forKey: "lastProcessedSessionKey")
        print("🧹 Cache purged! Recalculating everything from scratch...")


        print("📡 Checking for new Quali or Race data...")
        
        // UPGRADE: We now track the exact Session instead of the whole Meeting
        let lastProcessedKey = appGroupDefaults?.integer(forKey: "lastProcessedSessionKey") ?? 0
        
        // Notice we dropped "&session_name=Race" so we get Qualifying sessions too!
        guard let sessionsUrl = URL(string: "https://api.openf1.org/v1/sessions?year=2026") else { return }
        let (sessionData, _) = try await URLSession.shared.data(from: sessionsUrl)
        let allSessions = try JSONDecoder().decode([F1Session].self, from: sessionData)
        
        let now = Date()
        
        // FILTER: Only get past Race or Qualifying sessions that are NEW
        let newSessions = allSessions.filter {
            ($0.startDate ?? Date.distantFuture) < now &&
            ($0.sessionKey ?? 0) > lastProcessedKey &&
            ($0.sessionName == "Race" || $0.sessionName == "Qualifying" || $0.sessionName == "Sprint")
        }
        
        if newSessions.isEmpty {
            print("⚡️ No new sessions found. Widget data is already up to date!")
            return
        }
        
        print("🏁 Found \(newSessions.count) new session(s)! Updating telemetry...")
        
        var statsDict: [Int: DriverStats] = [:]
        let existingStats = getCachedStandings()
        
        if existingStats.isEmpty {
            print("🆕 First time setup: Fetching driver grid...")
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
            for stat in existingStats {
                statsDict[stat.driverNumber] = stat
            }
        }
        
        var highestSessionKeyProcessed = lastProcessedKey
        
        for session in newSessions {
            guard let sessionKey = session.sessionKey,
                  let resultsUrl = URL(string: "https://api.openf1.org/v1/session_result?session_key=\(sessionKey)") else { continue }
            
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                let (resultData, _) = try await URLSession.shared.data(from: resultsUrl)
                let results = try JSONDecoder().decode([F1Result].self, from: resultData)
                
                for result in results {
                    guard let driverNum = result.driverNumber, statsDict[driverNum] != nil else { continue }
                    
                    // 1. IF IT IS A SUNDAY RACE: Add Points, Wins, Podiums, DNFs
                    if session.sessionName == "Race" {
                        statsDict[driverNum]?.points += result.points ?? 0.0
                        
                        if let pos = result.position {
                            if pos == 1 { statsDict[driverNum]?.wins += 1 }
                            if pos <= 3 { statsDict[driverNum]?.podiums += 1 }
                        }
                        if result.dnf == true || result.dns == true {
                            statsDict[driverNum]?.dnfs += 1
                        }
                    }
                    // 2. IF IT IS A SATURDAY SPRINT: Add Points and DNFs ONLY
                    else if session.sessionName == "Sprint" {
                        statsDict[driverNum]?.points += result.points ?? 0.0
                        
                        if result.dnf == true || result.dns == true {
                            statsDict[driverNum]?.dnfs += 1
                        }
                    }
                    // 3. IF IT IS QUALIFYING: Check for Pole Position
                    else if session.sessionName == "Qualifying" {
                        if let pos = result.position, pos == 1 {
                            statsDict[driverNum]?.poles += 1
                        }
                    }
                }
                
                if sessionKey > highestSessionKeyProcessed {
                    highestSessionKeyProcessed = sessionKey
                }
                
            } catch {
                print("⚠️ Failed to fetch results for session \(sessionKey)")
            }
        }
        
        let sortedStandings = statsDict.values.sorted { $0.points > $1.points }
        
        if let encodedData = try? JSONEncoder().encode(sortedStandings) {
            appGroupDefaults?.set(encodedData, forKey: "cachedStandings")
            appGroupDefaults?.set(Date(), forKey: "lastStandingsUpdate")
            appGroupDefaults?.set(highestSessionKeyProcessed, forKey: "lastProcessedSessionKey")
            print("✅ Successfully updated standings with latest session data!")
        }
    }
    
    func getCachedStandings() -> [DriverStats] {
        guard let data = appGroupDefaults?.data(forKey: "cachedStandings"),
              let standings = try? JSONDecoder().decode([DriverStats].self, from: data) else {
            return []
        }
        return standings
    }
}
