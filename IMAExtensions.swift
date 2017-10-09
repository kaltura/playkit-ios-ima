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

extension IMAAdsManager {
    func getAdCuePoints() -> PKAdCuePoints {
        return PKAdCuePoints(cuePoints: self.adCuePoints as? [TimeInterval] ?? [])
    }
}

extension PKAdInfo {
    convenience init(ad: IMAAd) {
        self.init(
            description: ad.adDescription,
            duration: ad.duration,
            title: ad.adTitle,
            skipOffset: ad.isSkippable ? -1 : nil,
            adId: ad.adId,
            adSystem: ad.adSystem,
            totalAds: Int(ad.adPodInfo.totalAds),
            position: Int(ad.adPodInfo.adPosition),
            timeOffset: ad.adPodInfo.timeOffset
        )
    }
}

extension PKAdBreakInfo {
    convenience init(ad: IMAAd, totalAdBreaks: Int) {
        self.init(
            id: "",
            position: Int(ad.adPodInfo.podIndex),
            totalAdBreaks: totalAdBreaks,
            timeOffset: ad.adPodInfo.timeOffset,
            totalAds: NSNumber(value: ad.adPodInfo.totalAds)
        )
    }
}
