import WidgetKit
import SwiftUI
@testable import F1WidgetExtension

@main
struct F1WidgetBundle: WidgetBundle {
    var body: some Widget {
        F1Widget()               // Countdown widget (Ferrari red)
        FavouriteTeam1Widget()   // Countdown — Favourite Team 1 theme
        FavouriteTeam2Widget()   // Countdown — Favourite Team 2 theme
        FavouriteDriver1Widget() // Favourite Driver 1
        FavouriteDriver2Widget() // Favourite Driver 2
        FavouriteDriver3Widget() // Favourite Driver 3
        FavouriteDriver4Widget() // Favourite Driver 4
    }
}
