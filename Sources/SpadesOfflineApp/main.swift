import Foundation
import SpadesCore

#if canImport(SwiftUI)
import SwiftUI

@main
struct SpadesOfflineAppMain: App {
    @State private var viewModel = SpadesViewModel()

    var body: some Scene {
        WindowGroup {
            SpadesGameView(viewModel: viewModel)
        }
    }
}

@Observable
final class SpadesViewModel {
    var game = SpadesGameState(seed: UInt64(Date().timeIntervalSince1970))
    var statusMessage = "Your turn"

    func playHumanCard(_ card: Card) {
        do {
            _ = try game.play(card: card)
            progressBotsIfNeeded()
            if game.handComplete {
                game.finalizeHand()
                statusMessage = "Hand complete! Team A: \(game.scoreboard.teamA), Team B: \(game.scoreboard.teamB)"
            } else {
                statusMessage = game.currentPlayer == 0 ? "Your turn" : "Bots are thinking..."
            }
        } catch {
            statusMessage = "Illegal move"
        }
    }

    func progressBotsIfNeeded() {
        while game.currentPlayer != 0 && !game.handComplete {
            game.playBotTurnIfNeeded()
        }
    }

    func newHand() {
        let seed = UInt64(Date().timeIntervalSince1970)
        game = SpadesGameState(seed: seed)
        statusMessage = "New offline hand started"
    }
}

struct SpadesGameView: View {
    let viewModel: SpadesViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Spades (Offline, No Ads)")
                .font(.title2).bold()

            Text(viewModel.statusMessage)
                .foregroundStyle(.secondary)

            HStack {
                Text("Team A: \(viewModel.game.scoreboard.teamA)")
                Text("Team B: \(viewModel.game.scoreboard.teamB)")
            }.font(.headline)

            GroupBox("Current Trick") {
                VStack(alignment: .leading) {
                    if viewModel.game.trick.isEmpty {
                        Text("No cards yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.game.trick.enumerated()), id: \.offset) { _, played in
                            Text("P\(played.player + 1): \(label(for: played.card))")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Your Hand") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(viewModel.game.players[0].hand, id: \.self) { card in
                        let legal = viewModel.game.legalCardsForCurrentPlayer.contains(card) && viewModel.game.currentPlayer == 0
                        Button(label(for: card)) {
                            viewModel.playHumanCard(card)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!legal)
                        .opacity(legal ? 1.0 : 0.45)
                    }
                }
            }

            Button("New Hand") {
                viewModel.newHand()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onAppear { viewModel.progressBotsIfNeeded() }
    }

    private func label(for card: Card) -> String {
        "\(symbol(for: card.rank))\(suitGlyph(card.suit))"
    }

    private func symbol(for rank: Rank) -> String {
        switch rank {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rank.rawValue)"
        }
    }

    private func suitGlyph(_ suit: Suit) -> String {
        switch suit {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }
}
#else

@main
struct SpadesOfflineAppMain {
    static func main() {
        print("SpadesOfflineApp includes a SwiftUI iOS app. Open this package in Xcode on macOS to run the UI.")
    }
}
#endif
