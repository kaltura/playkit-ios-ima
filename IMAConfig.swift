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
import PlayKit

@objc public class IMAConfig: NSObject, PKPluginConfig {
    
    @objc public let enableBackgroundPlayback = true
    // defaulted to false, because otherwise ad breaks events will not happen.
    // we need to have control on whether ad break will start playing or not using `Loaded` event is not enough. 
    // (will also need more safety checks for loaded because loaded will happen more than once).
    @objc public let autoPlayAdBreaks = false
    @objc public var language: String = "en"

    @objc public var videoBitrate = kIMAAutodetectBitrate
    @objc public var videoMimeTypes: [Any]?
    @objc public var adTagUrl: String = ""
    @objc public var companionView: UIView?
    @objc public var webOpenerPresentingController: UIViewController?
    /// ads request timeout interval, when ads request will take more then this time will resume content.
    @objc public var requestTimeoutInterval: TimeInterval = IMAPlugin.defaultTimeoutInterval
    /// enables debug mode on IMA SDK which will output detailed log information to the console. 
    /// The default value is false.
    @objc public var enableDebugMode: Bool = false
    
    // Builders
    @discardableResult
    @nonobjc public func set(language: String) -> Self {
        self.language = language
        return self
    }
    
    @discardableResult
    @nonobjc public func set(videoBitrate: Int32) -> Self {
        self.videoBitrate = videoBitrate
        return self
    }
    
    @discardableResult
    @nonobjc public func set(videoMimeTypes: [Any]) -> Self {
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
    
    public func merge(config: Any?) -> Any {
        if let imaConfig = config as? IMAConfig {
            let defaultValues = IMAConfig()
            
            if imaConfig.adTagUrl != defaultValues.adTagUrl {
                set(adTagUrl: imaConfig.adTagUrl)
            }
            if imaConfig.videoBitrate != defaultValues.videoBitrate {
                set(videoBitrate: imaConfig.videoBitrate)
            }
            if let videoMimeTypes = imaConfig.videoMimeTypes {
                set(videoMimeTypes: videoMimeTypes)
            }
            if imaConfig.language != defaultValues.language {
                set(language: imaConfig.language)
            }
            if let companionView = imaConfig.companionView {
                set(companionView: companionView)
            }
            if let webOpenerPresentingController = imaConfig.webOpenerPresentingController {
                set(webOpenerPresentingController: webOpenerPresentingController)
            }
            if imaConfig.requestTimeoutInterval != defaultValues.requestTimeoutInterval {
                set(requestTimeoutInterval: imaConfig.requestTimeoutInterval)
            }
        }
        return self
    }
}
