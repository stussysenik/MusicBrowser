import Foundation

struct RandomPlaybackPlan<ID: Hashable> {
    let startingID: ID
    let orderedIDs: [ID]
}

enum RandomPlaybackPlanner {
    static func makePlan<ID: Hashable>(
        ids: [ID],
        current: ID?,
        recent: [ID],
        shuffledIDs: [ID]? = nil
    ) -> RandomPlaybackPlan<ID>? {
        guard !ids.isEmpty else { return nil }

        let queue = shuffledIDs ?? ids.shuffled()
        let recentSet = Set(recent)

        let startingID =
            queue.first(where: { $0 != current && !recentSet.contains($0) }) ??
            queue.first(where: { $0 != current }) ??
            queue.first!

        let orderedIDs = [startingID] + queue.filter { $0 != startingID }
        return RandomPlaybackPlan(startingID: startingID, orderedIDs: orderedIDs)
    }
}
