// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license,
// unless a different license for a particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import GoogleInteractiveMediaAds

extension IMADAIPlugin {
    static func createAdDisplayContainer(forView view: UIView, withCompanionView companionView: UIView? = nil) -> IMAAdDisplayContainer {
        // tvOS doesn't support companionView.
        return IMAAdDisplayContainer(adContainer: view)
    }
}
