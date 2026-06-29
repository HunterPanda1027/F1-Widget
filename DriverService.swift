import Foundation
import WidgetKit

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
    let nameAcronym: String?
    let driverNumber: Int?
    let position: Int?
    let points: Double?
    let dnf: Bool?
    let dns: Bool?
    
    enum CodingKeys: String, CodingKey {
        case nameAcronym = "name_acronym"
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

        // 🚨 Fetch the last processed session key so we don't recalculate the whole season!
        //
        // RESET SWITCH: if this is 0, we treat it as a full reset — the cache is
        // cleared and the entire season is rebuilt from scratch. To force a reset,
        // temporarily change this line to: let lastProcessedKey = 0
        let lastProcessedKey = appGroupDefaults?.integer(forKey: "lastProcessedSessionKey") ?? 0 //appGroupDefaults?.integer(forKey: "lastProcessedSessionKey") ?? 

        // When the key is 0 we do a clean rebuild; otherwise we accumulate normally
        // and NEVER clear the cache.
        let isReset = (lastProcessedKey == 0)
        
        guard let sessionsUrl = URL(string: "https://api.openf1.org/v1/sessions?year=2026") else { return }
        
        // 1. Fetch Schedule
        let (sessionData, response) = try await URLSession.shared.data(from: sessionsUrl)
        
        // 2. Dual-Layer Protection (Rate Limit & Paywall)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            print("⚠️ Rate limit exceeded (429). Keeping existing cache.")
            return
        }
        if let rawJSON = String(data: sessionData, encoding: .utf8), rawJSON.contains("restricted") {
            print("🛑 API Blocked: Live session in progress. Widget will use cached standings.")
            return
        }
        
        let allSessions = try JSONDecoder().decode([F1Session].self, from: sessionData)
        
        var statsDict: [String: DriverStats] = [:]
        var numberToAcronym: [Int: String] = [:]
        
        // 3. Load your hardcoded 2026 grid (all tallies start at zero)
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
        
        // 4. Filter for only unprocessed point-scoring sessions.
        //    On a reset (lastProcessedKey == 0) this naturally includes EVERY past
        //    session, so the whole season is recomputed from scratch.
        let newSessions = allSessions.filter {
            ($0.startDate ?? Date.distantFuture) < Date() &&
            ($0.sessionKey ?? 0) > lastProcessedKey &&
            ["Race", "Sprint", "Qualifying"].contains($0.sessionName ?? "")
        }
        
        // 🏁 If there are no new races to process, stop here and leave the cache alone!
        guard !newSessions.isEmpty else {
            print("✨ No new sessions to process. Cache is pristine.")
            return
        }
        
        if isReset {
            // 🧹 RESET: wipe the cache and rebuild from zero. We deliberately do NOT
            // seed from the old cache here, so the freshly recomputed totals replace
            // everything cleanly with no risk of double-counting.
            print("♻️ lastProcessedKey == 0 → clearing cache and rebuilding the full season.")
            appGroupDefaults?.removeObject(forKey: "cachedStandings")
        } else {
            // ➕ NORMAL: seed from the previously accumulated standings so we ADD the
            // new sessions on top instead of resetting. Never clears the cache.
            for cached in getCachedStandings() {
                let key = cached.nameAcronym.uppercased()
                if var base = statsDict[key] {
                    base.points = cached.points
                    base.wins = cached.wins
                    base.podiums = cached.podiums
                    base.dnfs = cached.dnfs
                    base.poles = cached.poles
                    statsDict[key] = base
                } else {
                    // Driver in the cache but not in the current grid — keep them as-is.
                    statsDict[key] = cached
                }
            }
        }
        
        var highestSessionKey = lastProcessedKey
        
        // 5. Calculate Points
        for session in newSessions {
            // 🚨 DELAY: 1 full second to guarantee we stay under the API limit
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            guard let sessionKey = session.sessionKey,
                  let resultsUrl = URL(string: "https://api.openf1.org/v1/session_result?session_key=\(sessionKey)") else { continue }
            
            do {
                // 🚨 CHANGED: Saved the 'response' here to check HTTP status codes
                let (resultData, response) = try await URLSession.shared.data(from: resultsUrl)
                
                // 🚨 NEW: Check if the API returned a 200 OK status. If not, skip decoding.
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode != 200 {
                    print("ℹ️ Session \(sessionKey) results not available yet (HTTP \(httpRes.statusCode)).")
                    continue
                }
                
                // 🚨 NEW: Peek at the JSON payload. If it's a Dictionary (starts with '{'), skip it!
                if let jsonDict = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] {
                    print("ℹ️ API returned a message structure instead of results for session \(sessionKey): \(jsonDict)")
                    continue
                }
                
                // Safe to decode as an Array now that the structural checks passed!
                let results = try JSONDecoder().decode([F1Result].self, from: resultData)
                
                for result in results {
                    // 1. Get the number reported by the API
                    guard let apiNum = result.driverNumber else { continue }
                    
                    // 2. Map the API number to the correct driver in your hardcoded list
                    // This is the bridge between the API's number and your acronym-based logic
                    guard let driver = DriverInfo.all.first(where: { $0.number == apiNum }) else {
                        continue
                    }
                    
                    // 3. Use the ACRONYM as the key for your dictionary
                    let acronym = driver.code.uppercased()
                    
                    // 4. Ensure we have an initialized stats object for this acronym
                    if statsDict[acronym] == nil {
                        statsDict[acronym] = DriverStats(
                            driverNumber: driver.number,
                            fullName: driver.name,
                            nameAcronym: acronym,
                            teamName: driver.team
                        )
                    }
                    
                    // 5. Safely unwrap the stats object to update it
                    guard var stats = statsDict[acronym] else { continue }
                    
                    // 6. Process logic based on session name
                    if session.sessionName == "Race" {
                        // DNF/DNS check
                        if result.dnf == true || result.dns == true {
                            stats.dnfs += 1
                        }
                        
                        // Points & Podium/Win logic
                        if let pos = result.position {
                            let racePoints = [1: 25.0, 2: 18.0, 3: 15.0, 4: 12.0, 5: 10.0, 6: 8.0, 7: 6.0, 8: 4.0, 9: 2.0, 10: 1.0]
                            let apiPoints = result.points ?? 0.0
                            stats.points += apiPoints > 0 ? apiPoints : (racePoints[pos] ?? 0.0)
                            
                            if pos == 1 { stats.wins += 1 }
                            if pos <= 3 { stats.podiums += 1 }
                        }
                        
                    } else if session.sessionName == "Sprint" {
                        if let pos = result.position {
                            let sprintPoints = [1: 8.0, 2: 7.0, 3: 6.0, 4: 5.0, 5: 4.0, 6: 3.0, 7: 2.0, 8: 1.0]
                            let apiPoints = result.points ?? 0.0
                            stats.points += apiPoints > 0 ? apiPoints : (sprintPoints[pos] ?? 0.0)
                        }
                        
                    } else if session.sessionName == "Qualifying" {
                        if let pos = result.position, pos == 1 {
                            stats.poles += 1
                        }
                    }
                    
                    // 7. Write the updated stats back into the dictionary
                    statsDict[acronym] = stats
                }
                highestSessionKey = max(highestSessionKey, sessionKey)
                
            } catch {
                print("⚠️ Error processing session \(sessionKey): \(error)")
            }
        }
        
        // 6. Save valid data back to the cache
        let sorted = statsDict.values.sorted { $0.points > $1.points }
        if let encoded = try? JSONEncoder().encode(sorted) {
            appGroupDefaults?.set(encoded, forKey: "cachedStandings")
            appGroupDefaults?.set(highestSessionKey, forKey: "lastProcessedSessionKey")
        }
        
        // 7. Redraw the widgets with the freshly computed standings. This matters
        //    especially on a reset, so the cleared/rebuilt data shows immediately.
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 8. Retrieve from cache for the Widget View
    func getCachedStandings() -> [DriverStats] {
        guard let data = appGroupDefaults?.data(forKey: "cachedStandings"),
              let standings = try? JSONDecoder().decode([DriverStats].self, from: data) else { return [] }
        return standings
    }
}
