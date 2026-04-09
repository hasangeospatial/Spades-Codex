import XCTest
@testable import SpadesCore

final class SpadesCoreTests: XCTestCase {
    func testDeckHas52UniqueCards() {
        let deck = Deck.standard
        XCTAssertEqual(deck.count, 52)
        XCTAssertEqual(Set(deck).count, 52)
    }

    func testSpadesCannotBeLedBeforeBrokenIfOtherSuitExists() {
        var game = SpadesGameState(seed: 5)
        game = forcedState(
            currentPlayer: 0,
            trick: [],
            players: [
                .init(id: 0, hand: [.init(suit: .spades, rank: .ace), .init(suit: .clubs, rank: .two)]),
                .init(id: 1, hand: []),
                .init(id: 2, hand: []),
                .init(id: 3, hand: [])
            ],
            spadesBroken: false
        )

        XCTAssertThrowsError(try game.play(card: .init(suit: .spades, rank: .ace))) { error in
            XCTAssertEqual(error as? SpadesRuleError, .cannotLeadSpadeWhenOtherSuitAvailable)
        }
    }

    func testTrickWinnerUsesSpadesAsTrump() {
        let trick: [PlayedCard] = [
            .init(player: 0, card: .init(suit: .hearts, rank: .ace)),
            .init(player: 1, card: .init(suit: .hearts, rank: .king)),
            .init(player: 2, card: .init(suit: .spades, rank: .two)),
            .init(player: 3, card: .init(suit: .hearts, rank: .two))
        ]

        XCTAssertEqual(SpadesGameState.evaluateTrickWinner(trick), 2)
    }

    func testScoringPenaltyWhenUnderBid() {
        XCTAssertEqual(SpadesGameState.score(tricks: 4, bid: 6), -60)
    }

    private func forcedState(
        currentPlayer: Int,
        trick: [PlayedCard],
        players: [PlayerState],
        spadesBroken: Bool
    ) -> SpadesGameState {
        SpadesGameState(
            players: players,
            currentPlayer: currentPlayer,
            trick: trick,
            spadesBroken: spadesBroken
        )
    }
}
