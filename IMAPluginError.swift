// ===================================================================================================
//                           _  __     _ _
//                          | |/ /__ _| | |_ _  _ _ _ __ _
//                          | ' </ _` | |  _| || | '_/ _` |
//                          |_|\_\__,_|_|\__|\_,_|_| \__,_|
//
// This file is part of the Kaltura Collaborative Media Suite which allows users
// to do with audio, video, and animation what Wiki platfroms allow them to do with
// text.
//
// Copyright (C) 2016  Kaltura Inc.
// ===================================================================================================

import Foundation
import GoogleInteractiveMediaAds
import PlayKit

/// `IMAPluginError` used to wrap an `IMAAdError` and provide converation to `NSError`
struct IMAPluginError: PKError {
    
    var adError: IMAAdError
    
    static let domain = "com.kaltura.playkit.error.ima"
    
    var code: Int {
        return adError.code.rawValue
    }
    
    var errorDescription: String {
        return adError.message
    }
    
    var userInfo: [String: Any] {
        return [
            PKErrorKeys.errorTypeKey: adError.type.rawValue
        ]
    }
}

// IMA plugin error userInfo keys.
extension PKErrorKeys {
    static let errorTypeKey = "errorType"
}

extension PKErrorDomain {
    @objc(IMA) public static let ima = IMAPluginError.domain
}
