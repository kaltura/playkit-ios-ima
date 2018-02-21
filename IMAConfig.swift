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
import SwiftyJSON

@objc public class IMAConfig: NSObject, PKPluginConfigMerge {
    
    @objc public var enableBackgroundPlayback = true
    // defaulted to false, because otherwise ad breaks events will not happen.
    // we need to have control on whether ad break will start playing or not using `Loaded` event is not enough. 
    // (will also need more safety checks for loaded because loaded will happen more than once).
    @objc public var autoPlayAdBreaks = false
    @objc public var language: String = "en"

    @objc public var videoBitrate = kIMAAutodetectBitrate
    @objc public var videoMimeTypes: [Any]?
    @objc public var adTagUrl: String = ""
    @objc public weak var companionView: UIView?
    @objc public weak var webOpenerPresentingController: UIViewController?
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
    
    @discardableResult
    @nonobjc public func set(autoPlayAdBreaks: Bool) -> Self {
        self.autoPlayAdBreaks = autoPlayAdBreaks
        return self
    }
    
    @discardableResult
    @nonobjc public func set(enableBackgroundPlayback: Bool) -> Self {
        self.enableBackgroundPlayback = enableBackgroundPlayback
        return self
    }
    
    @discardableResult
    @nonobjc public func set(enableDebugMode: Bool) -> Self {
        self.enableDebugMode = enableDebugMode
        return self
    }
    
    public func merge(config: PKPluginConfigMerge) -> PKPluginConfigMerge {
        if let config = config as? IMAConfig {
            let defaultValues = IMAConfig()
            
            if config.adTagUrl != defaultValues.adTagUrl {
                set(adTagUrl: config.adTagUrl)
            }
            if config.videoBitrate != defaultValues.videoBitrate {
                set(videoBitrate: config.videoBitrate)
            }
            if let videoMimeTypes = config.videoMimeTypes {
                set(videoMimeTypes: videoMimeTypes)
            }
            if config.language != defaultValues.language {
                set(language: config.language)
            }
            if let companionView = config.companionView {
                set(companionView: companionView)
            }
            if let webOpenerPresentingController = config.webOpenerPresentingController {
                set(webOpenerPresentingController: webOpenerPresentingController)
            }
            if config.requestTimeoutInterval != defaultValues.requestTimeoutInterval {
                set(requestTimeoutInterval: config.requestTimeoutInterval)
            }
            if config.autoPlayAdBreaks != defaultValues.autoPlayAdBreaks {
                set(autoPlayAdBreaks: config.autoPlayAdBreaks)
            }
            if config.enableBackgroundPlayback != defaultValues.enableBackgroundPlayback {
                set(enableBackgroundPlayback: config.enableBackgroundPlayback)
            }
            if config.enableDebugMode != defaultValues.enableDebugMode {
                set(enableDebugMode: config.enableDebugMode)
            }
        }
        return self
    }
    
    public static func parse(json: JSON) -> IMAConfig? {
        if let dictionary = json.dictionary {
            let config = IMAConfig()
            
            if let adsRenderingSettings = dictionary["adsRenderingSettings"]?.dictionary {
                if let loadVideoTimeout = adsRenderingSettings["loadVideoTimeout"]?.double {
                    config.set(requestTimeoutInterval: loadVideoTimeout)
                }
                if let types = adsRenderingSettings["mimeTypes"]?.array {
                    config.set(videoMimeTypes: types.map { $0.object })
                }
                if let bitrate = adsRenderingSettings["bitrate"]?.int32 {
                    config.set(videoBitrate: bitrate)
                }
            }
            
            if let sdkSettings = dictionary["sdkSettings"]?.dictionary {
                if let language = sdkSettings["language"]?.string {
                    config.set(language: language)
                }
                if let autoPlayAdBreaks = sdkSettings["autoPlayAdBreaks"]?.bool {
                    config.set(autoPlayAdBreaks: autoPlayAdBreaks)
                }
                if let debugMode = sdkSettings["debugMode"]?.bool {
                    config.set(enableDebugMode: debugMode)
                }
                if let enableBackgroundPlayback = sdkSettings["enableBackgroundPlayback"]?.bool {
                    config.set(enableBackgroundPlayback: enableBackgroundPlayback)
                }
            }
            
            if let adTagUrl = dictionary["adTagUrl"]?.string {
                config.set(adTagUrl: adTagUrl)
            }
            
            return config
        }
        
        return nil
    }
}
