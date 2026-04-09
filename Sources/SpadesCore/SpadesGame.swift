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

public enum BotDifficulty: String, CaseIterable, Codable {
    case easy
    case medium
    case hard
}

public enum SpadesRuleError: Error, Equatable {
    case cardNotInHand
    case notPlayersTurn
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
    public private(set) var botDifficulty: BotDifficulty

    public init(seed: UInt64 = 1, botDifficulty: BotDifficulty = .medium) {
        self.players = (0..<4).map { PlayerState(id: $0) }
        self.currentPlayer = 0
        self.trick = []
        self.spadesBroken = false
        self.scoreboard = ScoreBoard()
        self.botDifficulty = botDifficulty
        dealHands(seed: seed)
        assignSimpleBids()
    }

    public init(
        players: [PlayerState],
        currentPlayer: Int,
        trick: [PlayedCard],
        spadesBroken: Bool,
        scoreboard: ScoreBoard = ScoreBoard(),
        botDifficulty: BotDifficulty = .medium
    ) {
        self.players = players
        self.currentPlayer = currentPlayer
        self.trick = trick
        self.spadesBroken = spadesBroken
        self.scoreboard = scoreboard
        self.botDifficulty = botDifficulty
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
            players[index].bid = BotBrain.estimateBid(for: players[index].hand, difficulty: botDifficulty)
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
        try play(card: card, for: currentPlayer)
    }

    @discardableResult
    public mutating func play(card: Card, for player: Int) throws -> Int? {
        guard player == currentPlayer else {
            throw SpadesRuleError.notPlayersTurn
        }

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
        let botCard = BotBrain.chooseCard(
            for: players[currentPlayer].hand,
            trick: trick,
            legalCards: legalCardsForCurrentPlayer,
            difficulty: botDifficulty
        )
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
    public static func estimateBid(for hand: [Card], difficulty: BotDifficulty) -> Int {
        let highSpades = hand.filter { $0.suit == .spades && $0.rank.rawValue >= Rank.jack.rawValue }.count
        let aces = hand.filter { $0.rank == .ace }.count
        let kings = hand.filter { $0.rank == .king }.count
        switch difficulty {
        case .easy:
            return max(1, min(4, highSpades + (aces / 2)))
        case .medium:
            return max(1, min(6, highSpades + aces + max(0, kings - 1) / 2))
        case .hard:
            let voidBonus = Suit.allCases.reduce(0) { partial, suit in
                partial + (hand.contains(where: { $0.suit == suit }) ? 0 : 1)
            }
            return max(2, min(8, highSpades + aces + kings / 2 + voidBonus))
        }
    }

    public static func chooseCard(
        for hand: [Card],
        trick: [PlayedCard],
        legalCards: [Card],
        difficulty: BotDifficulty
    ) -> Card {
        switch difficulty {
        case .easy:
            return legalCards.min { $0.rank.rawValue < $1.rank.rawValue }!
        case .medium:
            return mediumCardChoice(trick: trick, legalCards: legalCards)
        case .hard:
            return hardCardChoice(trick: trick, legalCards: legalCards)
        }
    }

    static func mediumCardChoice(trick: [PlayedCard], legalCards: [Card]) -> Card {
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

    static func hardCardChoice(trick: [PlayedCard], legalCards: [Card]) -> Card {
        guard !trick.isEmpty else {
            let center = legalCards.count / 2
            return legalCards.sorted(by: SpadesGameState.sortCard)[center]
        }

        let leadSuit = trick[0].card.suit
        let winningPlay = winningPlayedCard(in: trick)
        if winningPlay.player % 2 == 1 {
            let winningCandidates = legalCards
                .filter { canBeat(candidate: $0, winning: winningPlay.card, leadSuit: leadSuit) }
                .sorted(by: SpadesGameState.sortCard)
            if let lowestWinning = winningCandidates.first {
                return lowestWinning
            }
        }
        return legalCards.sorted(by: SpadesGameState.sortCard).first!
    }

    static func winningPlayedCard(in trick: [PlayedCard]) -> PlayedCard {
        let winner = SpadesGameState.evaluateTrickWinner(trick)
        return trick.first(where: { $0.player == winner }) ?? trick[0]
    }

    static func canBeat(candidate: Card, winning: Card, leadSuit: Suit) -> Bool {
        if candidate.suit == winning.suit {
            return candidate.rank.rawValue > winning.rank.rawValue
        }
        if candidate.suit == .spades && winning.suit != .spades {
            return true
        }
        if candidate.suit == leadSuit && winning.suit != .spades && winning.suit != leadSuit {
            return true
        }
        return false
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
