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
            height: Int(ad.height),
            width: Int(ad.width),
            totalAds: Int(ad.adPodInfo.totalAds),
            adPosition: Int(ad.adPodInfo.adPosition),
            timeOffset: ad.adPodInfo.timeOffset,
            isBumper: ad.adPodInfo.isBumper,
            podIndex: Int(ad.adPodInfo.podIndex)
        )
    }
}
