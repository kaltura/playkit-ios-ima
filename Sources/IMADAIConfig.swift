
import Foundation
import GoogleInteractiveMediaAds

@objc public enum PKIMADAIStreamType: Int, CustomStringConvertible {
    case vod
    case live
    
    public var description: String {
        switch self {
        case .vod: return "vod"
        case .live: return "live"
        }
    }
}

@objc public class IMADAIConfig: NSObject {
    
    // Media Data
    public var streamType: PKIMADAIStreamType = .vod
    @objc public var assetTitle: String?
    @objc public var assetKey: String? { // Needed for Live
        didSet {
            if let assetKey = assetKey, !assetKey.isEmpty {
                streamType = .live
            }
        }
    }
    @objc public var apiKey: String?
    @objc public var contentSourceId: String? { // Needed for VOD
        didSet {
            if let contentSourceId = contentSourceId, !contentSourceId.isEmpty {
                streamType = .vod
            }
        }
    }
    @objc public var videoId: String? // Needed for VOD
    @objc public var licenseUrl: String?
    @objc public var adTagParams: [String: String]?
    @objc public var streamActivityMonitorId: String?
    @objc public var authToken: String?
    
    // IMASettings
    @objc public var ppid: String?
    @objc public var language: String = "en"
    @objc public var maxRedirects: UInt = 4
    @objc public var enableBackgroundPlayback: Bool = false
    @objc public var autoPlayAdBreaks: Bool = true
    @objc public var disableNowPlayingInfo: Bool = false
    @objc public var playerType: String = "kaltura-vp-ios"
    @objc public var playerVersion: String?
    @objc public var enableDebugMode: Bool = false
    
    // IMAAdsRenderingSettings
    public var videoMimeTypes: [String]?
    public var videoBitrate = kIMAAutodetectBitrate
    public var loadVideoTimeout: TimeInterval?
    public var uiElements: [NSNumber]?
    public var disableUI: Bool = false
    public var webOpenerPresentingController: UIViewController?
    
    // Extra Data
    public var requestTimeoutInterval: TimeInterval = IMAPlugin.defaultTimeoutInterval
    public var companionView: UIView? // CompanionView is not available on tvOS, it will be ignored.
    public var videoControlsOverlays: [UIView]?
    
    /// This boolean indicates whether or not to play the pre-roll when the start position is bigger then 0.
    /// Default value is false.
    @objc public var alwaysStartWithPreroll: Bool = false
    
    @objc public var adAttribution: Bool = true
    @objc public var adCountDown: Bool = true
    @objc public var disablePersonalizedAds: Bool = true // adTagParameters.put("npa", 1);
    @objc public var enableAgeRestriction: Bool = false // adTagParameters.put("tfua", 1);
    
    public func inDebugMode() -> Bool {
        return enableDebugMode
    }
}
