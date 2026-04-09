import Foundation
import SpadesCore

#if canImport(SwiftUI)
import SwiftUI
#if canImport(GameKit)
import GameKit
#endif

@main
struct SpadesOfflineAppMain: App {
    @State private var viewModel = SpadesViewModel()

    var body: some Scene {
        WindowGroup {
            SpadesGameView(viewModel: viewModel)
        }
    }
}

enum GameMode: String, CaseIterable {
    case soloOffline = "Solo Offline"
    case onlineMultiplayer = "Online Multiplayer"
}

@Observable
final class SpadesViewModel {
    var selectedDifficulty: BotDifficulty = .medium
    var selectedMode: GameMode = .soloOffline
    var game = SpadesGameState(seed: UInt64(Date().timeIntervalSince1970), botDifficulty: .medium)
    var statusMessage = "Your turn"

    #if canImport(GameKit)
    let onlineService = OnlineMatchService()
    #endif

    init() {
        #if canImport(GameKit)
        onlineService.onRemoteAction = { [weak self] action in
            self?.applyRemoteAction(action)
        }
        #endif
    }

    func playHumanCard(_ card: Card) {
        do {
            _ = try game.play(card: card)
            publishOnlineAction(.playCard(player: 0, card: card))
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
        guard selectedMode == .soloOffline else { return }
        while game.currentPlayer != 0 && !game.handComplete {
            game.playBotTurnIfNeeded()
        }
    }

    func newHand() {
        let seed = UInt64(Date().timeIntervalSince1970)
        game = SpadesGameState(seed: seed, botDifficulty: selectedDifficulty)
        statusMessage = selectedMode == .soloOffline
            ? "New offline hand started"
            : "Online hand started"
        publishOnlineAction(.newHand(seed: seed, difficulty: selectedDifficulty))
        progressBotsIfNeeded()
    }

    func applyDifficulty(_ difficulty: BotDifficulty) {
        selectedDifficulty = difficulty
        newHand()
    }

    #if canImport(GameKit)
    func authenticateGameCenter() {
        onlineService.authenticate()
    }

    func startOnlineMatchmaking() {
        onlineService.startMatchmaking()
        statusMessage = "Opening Game Center matchmaking..."
    }

    private func publishOnlineAction(_ action: OnlineAction) {
        guard selectedMode == .onlineMultiplayer else { return }
        onlineService.send(action: action)
    }

    private func applyRemoteAction(_ action: OnlineAction) {
        switch action {
        case .newHand(let seed, let difficulty):
            game = SpadesGameState(seed: seed, botDifficulty: difficulty)
            statusMessage = "Remote player started a new hand"
        case .playCard(_, let card):
            _ = try? game.play(card: card)
            statusMessage = "Remote player made a move"
        }
    }
    #else
    func authenticateGameCenter() { }
    func startOnlineMatchmaking() {
        statusMessage = "Online multiplayer requires iOS with Game Center support"
    }
    #endif
}

struct SpadesGameView: View {
    let viewModel: SpadesViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Spades")
                .font(.title2).bold()

            Text("Offline no-ads mode + Game Center online options")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Game Mode", selection: Binding(
                get: { viewModel.selectedMode },
                set: {
                    viewModel.selectedMode = $0
                    viewModel.newHand()
                }
            )) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Difficulty", selection: Binding(
                get: { viewModel.selectedDifficulty },
                set: { viewModel.applyDifficulty($0) }
            )) {
                ForEach(BotDifficulty.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.selectedMode == .onlineMultiplayer {
                HStack {
                    Button("Game Center Login") {
                        viewModel.authenticateGameCenter()
                    }
                    .buttonStyle(.bordered)

                    Button("Find Match") {
                        viewModel.startOnlineMatchmaking()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

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
        .onAppear {
            viewModel.newHand()
            viewModel.progressBotsIfNeeded()
        }
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

#if canImport(GameKit)
enum OnlineAction: Codable {
    case newHand(seed: UInt64, difficulty: BotDifficulty)
    case playCard(player: Int, card: Card)
}

@Observable
final class OnlineMatchService: NSObject, GKMatchDelegate {
    private var match: GKMatch?
    var onRemoteAction: ((OnlineAction) -> Void)?

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { _, error in
            if let error {
                print("Game Center auth error: \(error.localizedDescription)")
            }
        }
    }

    func startMatchmaking() {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 4
        GKMatchmaker.shared().findMatch(for: request) { [weak self] match, error in
            if let error {
                print("Matchmaking error: \(error.localizedDescription)")
                return
            }
            self?.match = match
            self?.match?.delegate = self
        }
    }

    func send(action: OnlineAction) {
        guard let match else { return }
        do {
            let payload = try JSONEncoder().encode(action)
            try match.sendData(toAllPlayers: payload, with: .reliable)
        } catch {
            print("Failed to send online action: \(error.localizedDescription)")
        }
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard let action = try? JSONDecoder().decode(OnlineAction.self, from: data) else { return }
        onRemoteAction?(action)
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        print("Player connection state changed: \(player.displayName) -> \(state.rawValue)")
    }
}
#endif

#else

@main
struct SpadesOfflineAppMain {
    static func main() {
        print("SpadesOfflineApp includes a SwiftUI iOS app with online matchmaking options. Open this package in Xcode on macOS to run the UI.")
    }
}
#endif
