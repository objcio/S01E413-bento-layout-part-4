import SwiftUI

extension EnvironmentValues {
    @Entry var direction: Axis = .vertical
}

struct SplitItem {
    var children: [SplitItem] = []

    var numberOfChildren: Int {
        children.isEmpty ? 1 : children.reduce(0) {
            $0 + $1.numberOfChildren
        }
    }
}

let sample = SplitItem(children: [
    .init(children: [
        .init(),
        .init(children: [
            .init(),
            .init(),
        ])
    ]),
    .init(children: [
        .init(children: [
            .init(),
            .init()
        ]),
        .init(),
    ]),
    .init(),
])

struct Bento<Content: View>: View {
    var split: SplitItem
    @ViewBuilder var content: Content

    var body: some View {
        Group(subviews: content) { collection in
            BentoHelper(split: split, collection: collection[...])
        }

    }
}

struct BentoHelper: View {
    var split: SplitItem
    var axis: Axis = .vertical
    var collection: SubviewsCollection.SubSequence

    func subviewRange(for index: Int) -> Range<Int> {
        if index == 0 {
            return collection.startIndex..<(collection.startIndex + split.children[0].numberOfChildren)
        } else {
            let previous = subviewRange(for: index - 1)
            return previous.upperBound..<(previous.upperBound + split.children[index].numberOfChildren)
        }
    }

    var body: some View {
        let layout = axis == .vertical ? AnyLayout(VStackLayout()) : .init(HStackLayout())
        layout {
            if split.children.count == 0 {
                collection.first
            } else {
                ForEach(0..<split.children.count, id: \.self) { idx in
                    BentoHelper(split: split.children[idx], axis: axis.other, collection: collection[subviewRange(for: idx)])
                }
            }
        }
    }
}

extension Axis {
    var other: Self {
        self == .horizontal ? .vertical : .horizontal
    }
}

struct Split<Content: View>: View {
    @Environment(\.direction) var axis
    @ViewBuilder var content: Content
    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        layout {
            content
        }
        .environment(\.direction, axis.other)
    }
}

func rects(item: SplitItem, proposal: ProposedViewSize, subviews: Layout.Subviews.SubSequence, axis: Axis, origin: CGPoint, spacing: CGFloat) -> [CGRect] {
    guard !subviews.isEmpty else { return [] }
    if item.children.isEmpty {
        return [.init(origin: origin, size: subviews[0].sizeThatFits(proposal))]
    }
    var result: [CGRect] = []
    let totalSpacing = spacing * .init(item.children.count - 1)
    let dividedProposal = (proposal - totalSpacing) / .init(item.children.count)
    let childProposal = axis == .vertical ? ProposedViewSize(width: proposal.width, height: dividedProposal.height) : .init(width: dividedProposal.width, height: proposal.height)
    var remainingSubviews = subviews
    var currentPosition = origin
    for child in item.children {
        let endIndex = min(remainingSubviews.endIndex, remainingSubviews.startIndex+child.numberOfChildren)
        let childSubviews = remainingSubviews[remainingSubviews.startIndex..<endIndex]
        let childRects = rects(item: child, proposal: childProposal, subviews: childSubviews, axis: axis.other, origin: currentPosition, spacing: spacing)
        result.append(contentsOf: childRects)
        remainingSubviews.removeFirst(childSubviews.count)
        if axis == .vertical {
            let actualHeight = childRects.map { $0.height }.max() ?? .zero
            currentPosition.y += actualHeight + spacing
        } else {
            let actualWidth = childRects.map { $0.width }.max() ?? .zero
            currentPosition.x += actualWidth + spacing
        }
    }
    return result
}

extension ProposedViewSize {
    static func /(lhs: Self, rhs: CGFloat) -> Self {
        .init(width: lhs.width.map { $0 / rhs }, height: lhs.height.map { $0 / rhs })
    }

    static func -(lhs: Self, rhs: CGFloat) -> Self {
        .init(width: lhs.width.map { $0 - rhs }, height: lhs.height.map { $0 - rhs })
    }
}

struct BentoLayout: Layout {
    var split: SplitItem
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let allRects = rects(item: split, proposal: proposal, subviews: subviews[...], axis: .vertical, origin: .zero, spacing: spacing)
        return allRects.reduce(CGRect.null, { $0.union($1) }).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let allRects = rects(item: split, proposal: proposal, subviews: subviews[...], axis: .vertical, origin: bounds.origin, spacing: spacing)
        for (view, rect) in zip(subviews, allRects) {
            view.place(at: rect.origin, proposal: .init(rect.size))
        }
        for view in subviews.dropFirst(split.numberOfChildren) {
            view.place(at: .zero, proposal: .init(.zero))
        }
    }
}

let sampleColors = [
    Color.blue,
    Color.green,
    Color.yellow,
    Color.teal,
    Color.black,
    Color.blue,
    Color.green,
    Color.yellow,
    Color.teal,
    Color.black,
]

struct Item: Identifiable, Equatable {
    var id = UUID()
    var color: Color
}

struct ContentView: View {
    @State var items = sampleColors.map { Item(color: $0) }

    var body: some View {
        BentoLayout(split: sample, spacing: 20) {
            ForEach(items) { item in
                item.color
                    .onTapGesture {
                        items.removeAll { $0.id == item.id }
                    }
            }
        }
        .animation(.default.speed(0.2), value: items)
    }
}

#Preview {
    ContentView()
}
