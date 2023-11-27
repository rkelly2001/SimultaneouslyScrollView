#if os(iOS) || os(tvOS)
import Combine
import UIKit

internal class DefaultSimultaneouslyScrollViewHandler: NSObject, SimultaneouslyScrollViewHandler {
    private var scrollViewsStore: [ScrollViewDecorator] = []
    private weak var lastScrollingScrollView: UIScrollView?
    private var lastContentOffset: CGPoint = .zero

    private let scrolledToBottomSubject = PassthroughSubject<Bool, Never>()

    var scrolledToBottomPublisher: AnyPublisher<Bool, Never> {
        scrolledToBottomSubject.eraseToAnyPublisher()
    }

    func register(scrollView: UIScrollView) {
        register(scrollView: scrollView, scrollDirections: nil)
    }

    func register(scrollView: UIScrollView, scrollDirections: SimultaneouslyScrollViewDirection?) {
        guard !scrollViewsStore.contains(where: { $0.scrollView == scrollView }) else {
            // just because the scroll view exist doesn't gaurentee its offset is synced
            scrollView.contentOffset = lastContentOffset
            return
        }

        scrollView.delegate = self
        scrollView.contentOffset = lastContentOffset
        scrollViewsStore.append(
            ScrollViewDecorator(
                scrollView: scrollView,
                directions: scrollDirections
            )
        )

        checkIsContentOffsetAtBottom()
    }

    func scrollAllToBottom(animated: Bool) {
        guard !scrollViewsStore.isEmpty,
              let scrollView = scrollViewsStore.first?.scrollView,
              scrollView.hasContentToFillScrollView
        else {
            return
        }

        let bottomContentOffset = CGPoint(
            x: 0,
            y: scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
        )

        scrollViewsStore
            .compactMap { $0.scrollView }
            .forEach { $0.setContentOffset(bottomContentOffset, animated: animated) }
    }

    private func checkIsContentOffsetAtBottom() {
        guard !scrollViewsStore.isEmpty,
              let scrollView = scrollViewsStore.first?.scrollView,
              scrollView.hasContentToFillScrollView
        else {
            scrolledToBottomSubject.send(true)
            return
        }

        if scrollView.isAtBottom {
            scrolledToBottomSubject.send(true)
        } else {
            scrolledToBottomSubject.send(false)
        }
    }

    private func sync(scrollView: UIScrollView, with decorator: ScrollViewDecorator) {
        guard let registeredScrollView = decorator.scrollView else {
            return
        }

        switch decorator.directions {
        case [.horizontal]:
            let offset = CGPoint(x: scrollView.contentOffset.x, y: registeredScrollView.contentOffset.y)
            registeredScrollView.setContentOffset(offset, animated: false)
        case [.vertical]:
            let offset = CGPoint(x: registeredScrollView.contentOffset.x, y: scrollView.contentOffset.y)
            registeredScrollView.setContentOffset(offset, animated: false)
        default:
            registeredScrollView.setContentOffset(scrollView.contentOffset, animated: false)
        }
    }
}

extension DefaultSimultaneouslyScrollViewHandler: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastScrollingScrollView = scrollView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        lastContentOffset = scrollView.contentOffset
        checkIsContentOffsetAtBottom()

        guard lastScrollingScrollView == scrollView else {
            return
        }

        scrollViewsStore
            .filter { $0.scrollView != lastScrollingScrollView }
            .forEach { sync(scrollView: scrollView, with: $0) }
    }
}
#endif
