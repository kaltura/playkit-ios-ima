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
    static func createAdDisplayContainer(forView view: UIView, viewController: UIViewController?, withCompanionView companionView: UIView? = nil) -> IMAAdDisplayContainer {
        // Setup ad display container and companion if exists, needs to create a new ad container for each request.
        if let cv = companionView {
            let companionAdSlot = IMACompanionAdSlot(view: cv,
                                                     width: Int(cv.frame.size.width),
                                                     height: Int(cv.frame.size.height))
            return IMAAdDisplayContainer(adContainer: view,
                                         viewController: viewController,
                                         companionSlots: [companionAdSlot])
        } else {
            return IMAAdDisplayContainer(adContainer: view,
                                         viewController: viewController,
                                         companionSlots: [])
        }
    }
}
