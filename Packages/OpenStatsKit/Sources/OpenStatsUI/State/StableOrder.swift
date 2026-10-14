import Foundation

/// 排行榜的固定名次：上次显示的条目只要还在本次前 N 名里就留在原来的位置，只更新数值；
/// 只有掉出前 N 名的条目空出的位置才由新上榜的条目补上。
/// 按瞬时值每次重排时，数值接近的几项会不停互换位置，面板一直在跳，看不清
enum StableOrder {
    static func arrange<Item, ID: Hashable>(_ ranked: [Item], previous: [ID], limit: Int, id: (Item) -> ID) -> [Item] {
        let top = Array(ranked.prefix(limit))
        let byID = Dictionary(top.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
        var slots: [Item?] = previous.prefix(limit).map { byID[$0] }
        let kept = Set(previous.prefix(limit).filter { byID[$0] != nil })
        var newcomers = top.filter { !kept.contains(id($0)) }[...]
        for index in slots.indices where slots[index] == nil {
            guard let next = newcomers.popFirst() else { break }
            slots[index] = next
        }
        return slots.compactMap { $0 } + newcomers
    }
}

/// 视图里记住上次显示的顺序。普通类、不参与观察：在 body 里更新它不会引起额外的重绘
final class StableOrderMemory<ID: Hashable> {
    private var previous: [ID] = []

    func arrange<Item>(_ ranked: [Item], limit: Int, id: (Item) -> ID) -> [Item] {
        let shown = StableOrder.arrange(ranked, previous: previous, limit: limit, id: id)
        previous = shown.map(id)
        return shown
    }
}
