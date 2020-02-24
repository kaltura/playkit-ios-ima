
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
    public var assetTitle: String?
    public var assetKey: String? // Needed for Live
    public var apiKey: String?
    public var contentSourceId: String? // Needed for VOD
    public var videoId: String? // Needed for VOD
    public var licenseUrl: String?
    
    // IMASettings
    public var ppid: String?
    public var language: String = "en"
    public var maxRedirects: UInt = 4
    public var enableBackgroundPlayback: Bool = false
    public var autoPlayAdBreaks: Bool = true
    public var disableNowPlayingInfo: Bool = false
    public var playerType: String = "kaltura-vp-ios"
    public var playerVersion: String?
    public var enableDebugMode: Bool = false
    
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
    public var alwaysStartWithPreroll: Bool = false
    
    public var adAttribution: Bool = true
    public var adCountDown: Bool = true
    public var disablePersonalizedAds: Bool = true // adTagParameters.put("npa", 1);
    public var enableAgeRestriction: Bool = false // adTagParameters.put("tfua", 1);
    
    public func inDebugMode() -> Bool {
        return enableDebugMode
    }
}
