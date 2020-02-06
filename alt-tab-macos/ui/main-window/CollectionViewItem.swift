import Cocoa
import WebKit

typealias MouseDownCallback = (Window) -> Void
typealias MouseMovedCallback = (CollectionViewItem) -> Void

class CollectionViewItem: NSCollectionViewItem {
    var thumbnail = NSImageView()
    var appIcon = NSImageView()
    var label = CellTitle(Preferences.fontHeight)
    var minimizedIcon = FontIcon(FontIcon.sfSymbolCircledMinusSign, Preferences.fontIconSize, .white)
    var hiddenIcon = FontIcon(FontIcon.sfSymbolCircledDotSign, Preferences.fontIconSize, .white)
    var spaceIcon = FontIcon(FontIcon.sfSymbolCircledNumber0, Preferences.fontIconSize, .white)
    var window: Window?
    var mouseDownCallback: MouseDownCallback?
    var mouseMovedCallback: MouseMovedCallback?

    override func loadView() {
        let hStackView = makeHStackView()
        let vStackView = makeVStackView(hStackView)
        let shadow = CollectionViewItem.makeShadow(.gray)
        thumbnail.shadow = shadow
        appIcon.shadow = shadow
        view = vStackView
    }

    override func mouseMoved(with event: NSEvent) {
        mouseMovedCallback!(self)
    }

    override func mouseDown(with theEvent: NSEvent) {
        mouseDownCallback!(window!)
    }

    override var isSelected: Bool {
        didSet {
            view.layer!.backgroundColor = isSelected ? Preferences.highlightBackgroundColor.cgColor : .clear
            view.layer!.borderColor = isSelected ? Preferences.highlightBorderColor.cgColor : .clear
        }
    }

    func updateRecycledCellWithNewContent(_ element: Window, _ mouseDownCallback: @escaping MouseDownCallback, _ mouseMovedCallback: @escaping MouseMovedCallback, _ screen: NSScreen) {
        window = element
        thumbnail.image = element.thumbnail
        let (thumbnailWidth, thumbnailHeight) = CollectionViewItem.thumbnailSize(element.thumbnail, screen)
        let thumbnailSize = NSSize(width: thumbnailWidth.rounded(), height: thumbnailHeight.rounded())
        thumbnail.image?.size = thumbnailSize
        thumbnail.frame.size = thumbnailSize
        appIcon.image = element.icon
        let appIconSize = NSSize(width: Preferences.iconSize, height: Preferences.iconSize)
        appIcon.image?.size = appIconSize
        appIcon.frame.size = appIconSize
        label.string = element.title
        // workaround: setting string on NSTextView change the font (most likely a Cocoa bug)
        label.font = Preferences.font
        hiddenIcon.isHidden = !window!.isHidden
        minimizedIcon.isHidden = !window!.isMinimized
        spaceIcon.isHidden = element.spaceIndex == nil || Spaces.isSingleSpace || Preferences.hideSpaceNumberLabels
        if !spaceIcon.isHidden {
            if element.isOnAllSpaces {
                spaceIcon.setStar()
            } else {
                spaceIcon.setNumber(UInt32(element.spaceIndex!))
            }
        }
        let fontIconWidth = CGFloat([minimizedIcon, hiddenIcon, spaceIcon].filter { !$0.isHidden }.count) * (Preferences.fontIconSize + Preferences.intraCellPadding)
        label.textContainer!.size.width = view.frame.width - Preferences.iconSize - Preferences.intraCellPadding * 3 - fontIconWidth
        view.subviews.first!.frame.size = view.frame.size
        self.mouseDownCallback = mouseDownCallback
        self.mouseMovedCallback = mouseMovedCallback
        if view.trackingAreas.count > 0 {
            view.removeTrackingArea(view.trackingAreas[0])
        }
        view.addTrackingArea(NSTrackingArea(rect: view.bounds, options: [.mouseMoved, .activeAlways], owner: self, userInfo: nil))
    }

    static func makeShadow(_ color: NSColor) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 1
        return shadow
    }

    private func makeHStackView() -> NSStackView {
        let hStackView = NSStackView()
        hStackView.spacing = Preferences.intraCellPadding
        hStackView.setViews([appIcon, label, hiddenIcon, minimizedIcon, spaceIcon], in: .leading)
        return hStackView
    }

    private func makeVStackView(_ hStackView: NSStackView) -> NSStackView {
        let vStackView = NSStackView()
        vStackView.wantsLayer = true
        vStackView.layer!.backgroundColor = .clear
        vStackView.layer!.cornerRadius = Preferences.cellCornerRadius
        vStackView.layer!.borderWidth = Preferences.cellBorderWidth
        vStackView.layer!.borderColor = .clear
        vStackView.edgeInsets = NSEdgeInsets(top: Preferences.intraCellPadding, left: Preferences.intraCellPadding, bottom: Preferences.intraCellPadding, right: Preferences.intraCellPadding)
        vStackView.orientation = .vertical
        vStackView.spacing = Preferences.intraCellPadding
        vStackView.setViews([hStackView, thumbnail], in: .leading)
        return vStackView
    }

    static func downscaleFactor() -> CGFloat {
        let nCellsBeforePotentialOverflow = Preferences.minRows * Preferences.minCellsPerRow
        guard CGFloat(Windows.list.count) > nCellsBeforePotentialOverflow else { return 1 }
        // TODO: replace this buggy heuristic with a correct implementation of downscaling
        return nCellsBeforePotentialOverflow / (nCellsBeforePotentialOverflow + (sqrt(CGFloat(Windows.list.count) - nCellsBeforePotentialOverflow) * 2))
    }

    static func widthMax(_ screen: NSScreen) -> CGFloat {
        return (ThumbnailsPanel.widthMax(screen) / Preferences.minCellsPerRow - Preferences.interCellPadding) * CollectionViewItem.downscaleFactor()
    }

    static func widthMin(_ screen: NSScreen) -> CGFloat {
        return (ThumbnailsPanel.widthMax(screen) / Preferences.maxCellsPerRow - Preferences.interCellPadding) * CollectionViewItem.downscaleFactor()
    }

    static func height(_ screen: NSScreen) -> CGFloat {
        return (ThumbnailsPanel.heightMax(screen) / Preferences.minRows - Preferences.interCellPadding) * CollectionViewItem.downscaleFactor()
    }

    static func width(_ image: NSImage?, _ screen: NSScreen) -> CGFloat {
        return max(thumbnailSize(image, screen).0 + Preferences.intraCellPadding * 2, CollectionViewItem.widthMin(screen))
    }

    static func thumbnailSize(_ image: NSImage?, _ screen: NSScreen) -> (CGFloat, CGFloat) {
        guard let image = image else { return (0, 0) }
        let thumbnailHeightMax = CollectionViewItem.height(screen) - Preferences.intraCellPadding * 3 - Preferences.iconSize
        let thumbnailWidthMax = CollectionViewItem.widthMax(screen) - Preferences.intraCellPadding * 2
        let thumbnailHeight = min(image.size.height, thumbnailHeightMax)
        let thumbnailWidth = min(image.size.width, thumbnailWidthMax)
        let imageRatio = image.size.width / image.size.height
        let thumbnailRatio = thumbnailWidth / thumbnailHeight
        if thumbnailRatio > imageRatio {
            return (image.size.width * thumbnailHeight / image.size.height, thumbnailHeight)
        }
        return (thumbnailWidth, image.size.height * thumbnailWidth / image.size.width)
    }
}