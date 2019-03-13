

import Foundation
import GoogleInteractiveMediaAds
import PlayKit

@objc public class PKIMAVideoDisplay: NSObject, IMAVideoDisplay, AdsDAIPlayerEngineWrapperDelegate {
   
    public var delegate: IMAVideoDisplayDelegate!
    private var adsDAIPlayerEngineWrapper: AdsDAIPlayerEngineWrapper

    private var isAdPlaying: Bool = false
    private var adCurrentTime: TimeInterval = 0
    private var adStartTime: TimeInterval = 0
    private var adDuration: TimeInterval = 0
    
    private var adTimer: Timer?
    private var adTimerInterval: TimeInterval = 0.2

    init(adsDAIPlayerEngineWrapper: AdsDAIPlayerEngineWrapper) {
        self.adsDAIPlayerEngineWrapper = adsDAIPlayerEngineWrapper
        super.init()
        
        self.adsDAIPlayerEngineWrapper.delegate = self
        delegate = self
    }
    
    // ********************************
    // MARK: - NSObject
    // ********************************
    
    public override func isEqual(_ object: Any?) -> Bool {
        
        guard let pkIMAVideoDisplay = object as? PKIMAVideoDisplay else {
            return false
        }
        
        if self === pkIMAVideoDisplay {
            return true
        }
        
        if adsDAIPlayerEngineWrapper.isEqual(pkIMAVideoDisplay.adsDAIPlayerEngineWrapper) &&
            delegate === pkIMAVideoDisplay.delegate {
            return true
        }
        
        return false
    }
    
    public override var hash: Int {
        return super.hash
    }
    
    public override var superclass: AnyClass? {
        return super.superclass
    }
    
    public override func `self`() -> Self {
        return self
    }
    
    public override func perform(_ aSelector: Selector!) -> Unmanaged<AnyObject>! {
        return super.perform(aSelector)
    }
    
    public override func perform(_ aSelector: Selector!, with object: Any!) -> Unmanaged<AnyObject>! {
        return super.perform(aSelector, with: object)
    }
    
    public override func perform(_ aSelector: Selector!, with object1: Any!, with object2: Any!) -> Unmanaged<AnyObject>! {
        return super.perform(aSelector, with: object1, with: object2)
    }
    
    public override func isProxy() -> Bool {
        return super.isProxy()
    }
    
    public override func isKind(of aClass: AnyClass) -> Bool {
        if type(of: self) == aClass {
            return true
        }
        return super.isKind(of: aClass)
    }
    
    public override func isMember(of aClass: AnyClass) -> Bool {
        if type(of: self) == aClass {
            return true
        }
        return super.isMember(of: aClass)
    }
    
    public override func conforms(to aProtocol: Protocol) -> Bool {
        return super.conforms(to: aProtocol)
    }
    
    public override func responds(to aSelector: Selector!) -> Bool {
        return super.responds(to: aSelector)
    }
    
    public override var description: String {
        return "adsDAIPlayerEngineWrapper: \(adsDAIPlayerEngineWrapper)\n"
    }
    
    // ********************************
    // MARK: - Private Methods
    // ********************************
    
    @objc private func adTimerFired() {
        guard let currentPosition = adsDAIPlayerEngineWrapper.playerEngine?.currentPosition else { return }
        adCurrentTime = currentPosition - adStartTime
        if currentPosition > adStartTime, adCurrentTime < adDuration {
            delegate.videoDisplay(self, didProgressWithMediaTime: currentPosition, totalTime: adDuration)
        } else
        
        // The adCompleted func was not called, apparently this is a PostRoll
        if currentPosition >= (adStartTime + adDuration) {
            adCompleted()
        }
    }
    
    // ********************************
    // MARK: - IMAVideoDisplay
    // ********************************
    
    public var volume: Float {
        get {
            return adsDAIPlayerEngineWrapper.volume
        }
        set {
            adsDAIPlayerEngineWrapper.volume = newValue
            delegate.videoDisplay(self, volumeChangedTo: NSNumber(value: newValue))
        }
    }
    
    public func loadStream(_ streamURL: URL!, withSubtitles subtitles: [Any]!) {
        adsDAIPlayerEngineWrapper.loadStream(streamURL)
    }
    
    public func load(_ url: URL!) {
        adsDAIPlayerEngineWrapper.loadStream(url)
    }
    
    public func play() {
        // Called to inform the VideoDisplay to play.
        adsDAIPlayerEngineWrapper.play()
    }
    
    public func pause() {
        // Called to inform the VideoDisplay to pause.
        // Calling the playerEngine.pause() because IMA already sent the 'Pause' event
        adsDAIPlayerEngineWrapper.playerEngine?.pause()
    }
    
    public func reset() {
        // Called to remove all video assets from the player.
        isAdPlaying = false
        adStartTime = 0
        adDuration = 0
        adCurrentTime = 0
        adTimer?.invalidate()
        adTimer = nil
    }
    
    public func seekStream(toTime time: TimeInterval) {
        // Called to inform that the stream needs to be seeked to the given time.
        adsDAIPlayerEngineWrapper.seek(to: time)
    }
    
    // ********************************
    // MARK: - IMAAdPlaybackInfo
    // ********************************
    
    public var currentMediaTime: TimeInterval {
        // The current media time of the ad, or 0 if no ad loaded.
        return adCurrentTime
    }
    
    public var totalMediaTime: TimeInterval {
        // The total media time of the ad, or 0 if no ad loaded.
        return adDuration
    }
    
    public var bufferedMediaTime: TimeInterval {
        // The buffered media time of the ad, or 0 if no ad loaded.
        return adDuration
        // TODO: Need to return the correct buffered time
    }
    
    public var isPlaying: Bool {
        // Whether or not the ad is currently playing.
        return isAdPlaying
    }
    
    // ********************************************
    // MARK: - AdsDAIPlayerEngineWrapperDelegate
    // ********************************************
    
    public func streamStarted() {
        delegate.videoDisplayDidStart(self)
    }
    
    public func adPlaying(startTime: TimeInterval, duration: TimeInterval) {
        isAdPlaying = true
        adStartTime = startTime
        adDuration = duration
        adCurrentTime = 0
        
        delegate.videoDisplayDidLoad(self)
        delegate.videoDisplayDidStart(self)
            
        adTimer = Timer.scheduledTimer(timeInterval: adTimerInterval,
                                       target: self,
                                       selector: #selector(adTimerFired),
                                       userInfo: nil,
                                       repeats: true)
        adTimer?.fire()
    }
    
    public func adPaused() {
        delegate.videoDisplayDidPause(self)
    }
    
    public func adResumed() {
        delegate.videoDisplayDidResume(self)
    }
    
    public func adCompleted() {
        adTimer?.invalidate()
        adTimer = nil
        
        let endTime = adStartTime + adDuration
        delegate.videoDisplay(self, didProgressWithMediaTime: endTime, totalTime: adDuration)
        delegate.videoDisplayDidComplete(self)
        isAdPlaying = false
        adStartTime = 0
        adDuration = 0
        adCurrentTime = 0
    }
    
    public func receivedTimedMetadata(_ metadata: [String : String]) {
        var mediaTime: Double = 0.0
        if let time = metadata["time"] {
            mediaTime = Double(time) ?? 0.0
        }

        var duration: Double = 0.0
        if let time = metadata["duration"] {
            duration = Double(time) ?? 0.0
        }
        
        let currentPosition = adsDAIPlayerEngineWrapper.playerEngine?.currentPosition ?? mediaTime
        print("Nilit: currentPosition:\(currentPosition) duration:\(duration)")
        delegate.videoDisplay(self, didProgressWithMediaTime: currentPosition, totalTime: duration)
        
        delegate.videoDisplay(self, didReceiveTimedMetadata: metadata)
    }
}

// **********************************
// MARK: - IMAVideoDisplayDelegate
// **********************************

extension PKIMAVideoDisplay: IMAVideoDisplayDelegate {
    // We are only calling these function so that IMA can trigger their events.
    // You won't stop here. Any code writen here won't be performed.
    public func videoDisplayDidPlay(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplayDidPause(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplayDidResume(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplayDidStart(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplayDidComplete(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplayDidClick(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplay(_ videoDisplay: IMAVideoDisplay!, didReceiveError error: Error!) {
    }
    
    public func videoDisplayDidSkip(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplayDidShowSkip(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplayDidLoad(_ videoDisplay: IMAVideoDisplay!) {
    }
    
    public func videoDisplay(_ videoDisplay: IMAVideoDisplay!, volumeChangedTo volume: NSNumber!) {
    }
    
    public func videoDisplay(_ videoDisplay: IMAVideoDisplay!, didProgressWithMediaTime mediaTime: TimeInterval, totalTime duration: TimeInterval) {
    }
    
    public func videoDisplay(_ videoDisplay: IMAVideoDisplay!, didReceiveTimedMetadata metadata: [String : String]!) {
    }
}
