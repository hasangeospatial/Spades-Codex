import Foundation

public enum Suit: String, CaseIterable, Codable {
    case clubs, diamonds, hearts, spades
}

public enum Rank: Int, CaseIterable, Comparable, Codable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13, ace = 14

    public static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct Card: Equatable, Hashable, Codable {
    public let suit: Suit
    public let rank: Rank

    public init(suit: Suit, rank: Rank) {
        self.suit = suit
        self.rank = rank
    }
}

public struct PlayerState: Codable {
    public let id: Int
    public var hand: [Card]
    public var tricksWon: Int
    public var bid: Int

    public init(id: Int, hand: [Card] = [], tricksWon: Int = 0, bid: Int = 0) {
        self.id = id
        self.hand = hand
        self.tricksWon = tricksWon
        self.bid = bid
    }
}

public struct ScoreBoard: Codable {
    public var teamA: Int
    public var teamB: Int

    public init(teamA: Int = 0, teamB: Int = 0) {
        self.teamA = teamA
        self.teamB = teamB
    }
}

public struct PlayedCard: Equatable {
    public let player: Int
    public let card: Card
}

public enum SpadesRuleError: Error, Equatable {
    case cardNotInHand
    case mustFollowSuit
    case spadesNotBroken
    case cannotLeadSpadeWhenOtherSuitAvailable
}

public struct SpadesGameState {
    public private(set) var players: [PlayerState]
    public private(set) var currentPlayer: Int
    public private(set) var trick: [PlayedCard]
    public private(set) var spadesBroken: Bool
    public private(set) var scoreboard: ScoreBoard

    public init(seed: UInt64 = 1) {
        self.players = (0..<4).map { PlayerState(id: $0) }
        self.currentPlayer = 0
        self.trick = []
        self.spadesBroken = false
        self.scoreboard = ScoreBoard()
        dealHands(seed: seed)
        assignSimpleBids()
    }

    public init(
        players: [PlayerState],
        currentPlayer: Int,
        trick: [PlayedCard],
        spadesBroken: Bool,
        scoreboard: ScoreBoard = ScoreBoard()
    ) {
        self.players = players
        self.currentPlayer = currentPlayer
        self.trick = trick
        self.spadesBroken = spadesBroken
        self.scoreboard = scoreboard
    }

    mutating func dealHands(seed: UInt64) {
        var deck = Deck.standard
        var generator = SeededRandomNumberGenerator(seed: seed)
        deck.shuffle(using: &generator)

        for playerIndex in players.indices {
            players[playerIndex].hand = Array(deck[(playerIndex * 13)..<((playerIndex + 1) * 13)]).sorted(by: Self.sortCard)
            players[playerIndex].tricksWon = 0
        }
    }

    mutating func assignSimpleBids() {
        for index in players.indices {
            players[index].bid = BotBrain.estimateBid(for: players[index].hand)
        }
    }

    public var legalCardsForCurrentPlayer: [Card] {
        legalCards(for: currentPlayer)
    }

    public func legalCards(for player: Int) -> [Card] {
        let hand = players[player].hand
        guard let leadSuit = trick.first?.card.suit else {
            if spadesBroken { return hand }
            let nonSpades = hand.filter { $0.suit != .spades }
            return nonSpades.isEmpty ? hand : nonSpades
        }

        let following = hand.filter { $0.suit == leadSuit }
        return following.isEmpty ? hand : following
    }

    @discardableResult
    public mutating func play(card: Card) throws -> Int? {
        let player = currentPlayer
        guard let cardIndex = players[player].hand.firstIndex(of: card) else {
            throw SpadesRuleError.cardNotInHand
        }

        let legal = legalCards(for: player)
        guard legal.contains(card) else {
            if let leadSuit = trick.first?.card.suit,
               players[player].hand.contains(where: { $0.suit == leadSuit }) {
                throw SpadesRuleError.mustFollowSuit
            }

            if trick.isEmpty, card.suit == .spades, !spadesBroken,
               players[player].hand.contains(where: { $0.suit != .spades }) {
                throw SpadesRuleError.cannotLeadSpadeWhenOtherSuitAvailable
            }

            throw SpadesRuleError.spadesNotBroken
        }

        players[player].hand.remove(at: cardIndex)
        if card.suit == .spades { spadesBroken = true }
        trick.append(.init(player: player, card: card))

        if trick.count == 4 {
            let winner = Self.evaluateTrickWinner(trick)
            players[winner].tricksWon += 1
            trick.removeAll(keepingCapacity: true)
            currentPlayer = winner
            return winner
        } else {
            currentPlayer = (currentPlayer + 1) % 4
            return nil
        }
    }

    public mutating func playBotTurnIfNeeded() {
        guard currentPlayer != 0 else { return }
        let botCard = BotBrain.chooseCard(for: players[currentPlayer].hand, trick: trick, legalCards: legalCardsForCurrentPlayer)
        _ = try? play(card: botCard)
    }

    public var handComplete: Bool {
        players.allSatisfy { $0.hand.isEmpty }
    }

    public mutating func finalizeHand() {
        let teamATricks = players[0].tricksWon + players[2].tricksWon
        let teamABid = players[0].bid + players[2].bid
        let teamBTricks = players[1].tricksWon + players[3].tricksWon
        let teamBBid = players[1].bid + players[3].bid

        scoreboard.teamA += Self.score(tricks: teamATricks, bid: teamABid)
        scoreboard.teamB += Self.score(tricks: teamBTricks, bid: teamBBid)
    }

    static func score(tricks: Int, bid: Int) -> Int {
        if tricks < bid { return -10 * bid }
        return (10 * bid) + (tricks - bid)
    }

    static func evaluateTrickWinner(_ trick: [PlayedCard]) -> Int {
        let leadSuit = trick[0].card.suit
        let winning = trick.max { lhs, rhs in
            let lhsTrump = lhs.card.suit == .spades
            let rhsTrump = rhs.card.suit == .spades
            if lhsTrump != rhsTrump { return !lhsTrump && rhsTrump }
            if lhs.card.suit != rhs.card.suit {
                if lhs.card.suit == leadSuit { return false }
                if rhs.card.suit == leadSuit { return true }
            }
            return lhs.card.rank < rhs.card.rank
        }!
        return winning.player
    }

    static func sortCard(_ lhs: Card, _ rhs: Card) -> Bool {
        if lhs.suit == rhs.suit { return lhs.rank.rawValue < rhs.rank.rawValue }
        let order: [Suit: Int] = [.clubs: 0, .diamonds: 1, .hearts: 2, .spades: 3]
        return order[lhs.suit, default: 0] < order[rhs.suit, default: 0]
    }
}

public struct BotBrain {
    public static func estimateBid(for hand: [Card]) -> Int {
        let highSpades = hand.filter { $0.suit == .spades && $0.rank.rawValue >= Rank.jack.rawValue }.count
        let aces = hand.filter { $0.rank == .ace }.count
        let kings = hand.filter { $0.rank == .king }.count
        let estimated = max(1, min(6, highSpades + aces + max(0, kings - 1) / 2))
        return estimated
    }

    public static func chooseCard(for hand: [Card], trick: [PlayedCard], legalCards: [Card]) -> Card {
        guard !trick.isEmpty else {
            return legalCards.min { $0.rank.rawValue < $1.rank.rawValue }!
        }

        let leadSuit = trick[0].card.suit
        let currentlyWinning = SpadesGameState.evaluateTrickWinner(trick)
        if trick.count == 3, currentlyWinning % 2 == 1 {
            if let winningCard = legalCards
                .filter({ $0.suit == leadSuit || $0.suit == .spades })
                .max(by: { $0.rank.rawValue < $1.rank.rawValue }) {
                return winningCard
            }
        }

        return legalCards.min { $0.rank.rawValue < $1.rank.rawValue }!
    }
}

public enum Deck {
    public static var standard: [Card] {
        Suit.allCases.flatMap { suit in
            Rank.allCases.map { rank in Card(suit: suit, rank: rank) }
        }
    }
}

public struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    public mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
