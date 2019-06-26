// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license,
// unless a different license for a particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import Foundation
import GoogleInteractiveMediaAds

@objc public class IMAConfig: NSObject {
    
    @objc public let enableBackgroundPlayback = true
    // Defaults to false, because otherwise ad breaks events will not happen.
    // We need to have control on whether ad break will start playing or not, using `Loaded` event is not enough.
    // (Will also need more safety checks for loaded because loaded will happen more than once).
    @objc public let autoPlayAdBreaks = false
    @objc public var language: String = "en"

    @objc public var videoBitrate = kIMAAutodetectBitrate
    @objc public var videoMimeTypes: [String]?
    @objc public var adTagUrl: String = ""
    @objc public var ppid: String?
    @objc public var companionView: UIView?
    @objc public var webOpenerPresentingController: UIViewController?
    /// Ads request timeout interval, when ads request will take more then this time, will resume content.
    @objc public var requestTimeoutInterval: TimeInterval = IMAPlugin.defaultTimeoutInterval
    /// Enables debug mode on IMA SDK which will output detailed log information to the console.
    /// The default value is false.
    @objc public var enableDebugMode: Bool = false
    
    @objc public var playerType: String = "kaltura-vp-ios"
    @objc public var playerVersion: String?
    
    @objc public var vastLoadTimeout: NSNumber?
    
    @objc public var videoControlsOverlays: [UIView]?
    
    /// This boolean indicates whether or not to play the pre-roll when the start position is bigger then 0.
    /// Default value is false.
    @objc public var alwaysStartWithPreroll: Bool = false
    
    // Builders
    @discardableResult
    @nonobjc public func set(language: String) -> Self {
        self.language = language
        return self
    }
    
    @discardableResult
    @nonobjc public func set(videoBitrate: Int) -> Self {
        self.videoBitrate = videoBitrate
        return self
    }
    
    @discardableResult
    @nonobjc public func set(videoMimeTypes: [String]) -> Self {
        self.videoMimeTypes = videoMimeTypes
        return self
    }
    
    @discardableResult
    @nonobjc public func set(adTagUrl: String) -> Self {
        self.adTagUrl = adTagUrl
        return self
    }
    
    @discardableResult
    @nonobjc public func set(companionView: UIView) -> Self {
        self.companionView = companionView
        return self
    }
    
    @discardableResult
    @nonobjc public func set(webOpenerPresentingController: UIViewController) -> Self {
        self.webOpenerPresentingController = webOpenerPresentingController
        return self
    }
    
    @discardableResult
    @nonobjc public func set(requestTimeoutInterval: TimeInterval) -> Self {
        self.requestTimeoutInterval = requestTimeoutInterval
        return self
    }
    
    @discardableResult
    @nonobjc public func set(playerType: String) -> Self {
        self.playerType = playerType
        return self
    }
    
    @discardableResult
    @nonobjc public func set(playerVersion: String) -> Self {
        self.playerVersion = playerVersion
        return self
    }
    
    @discardableResult
    @nonobjc public func set(vastLoadTimeout: NSNumber) -> Self {
        self.vastLoadTimeout = vastLoadTimeout
        return self
    }
    
    @discardableResult
    @nonobjc public func set(videoControlsOverlays: [UIView]) -> Self {
        self.videoControlsOverlays = videoControlsOverlays
        return self
    }
}
