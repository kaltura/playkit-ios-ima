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
            adDescription: ad.adDescription,
            adDuration: ad.duration,
            title: ad.adTitle,
            isSkippable: ad.isSkippable,
            contentType: ad.contentType,
            adId: ad.adId,
            adSystem: ad.adSystem,
            height: ad.isLinear ? ad.vastMediaHeight : Int(ad.height),
            width: ad.isLinear ? ad.vastMediaWidth : Int(ad.width),
            totalAds: Int(ad.adPodInfo.totalAds),
            adPosition: Int(ad.adPodInfo.adPosition),
            timeOffset: ad.adPodInfo.timeOffset,
            isBumper: ad.adPodInfo.isBumper,
            podIndex: Int(ad.adPodInfo.podIndex),
            mediaBitrate: ad.vastMediaBitrate)
    }
}
