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
