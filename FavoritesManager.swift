import Foundation
import WidgetKit
import Combine // <--- THIS IS THE MISSING PIECE

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favorites: [String] {
        didSet {
            UserDefaults(suiteName: "group.com.hunter.f1tracker")?.set(favorites, forKey: "fav_drivers")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    init() {
        self.favorites = UserDefaults(suiteName: "group.com.hunter.f1tracker")?.stringArray(forKey: "fav_drivers") ?? ["HAM"]
    }
}
