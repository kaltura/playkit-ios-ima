

import Foundation
import GoogleInteractiveMediaAds
import PlayKit

@objc public class PKIMAVideoDisplay: NSObject, IMAVideoDisplay, AdsDAIPlayerEngineWrapperDelegate {
   
    public var delegate: IMAVideoDisplayDelegate!
    private var adsDAIPlayerEngineWrapper: AdsDAIPlayerEngineWrapper

    private var adTimer: Timer?
    private var interval: TimeInterval = 10

    init(adsDAIPlayerEngineWrapper: AdsDAIPlayerEngineWrapper) {
        self.adsDAIPlayerEngineWrapper = adsDAIPlayerEngineWrapper
        super.init()
        
        self.adsDAIPlayerEngineWrapper.delegate = self
        delegate = self
    }
    
    public var volume: Float {
        get {
            return adsDAIPlayerEngineWrapper.volume
        }
        set {
            adsDAIPlayerEngineWrapper.volume = newValue
        }
    }
    
    public func loadStream(_ streamURL: URL!, withSubtitles subtitles: [Any]!) {
        adsDAIPlayerEngineWrapper.loadStream(streamURL)
    }
    
    public func load(_ url: URL!) {
        adsDAIPlayerEngineWrapper.loadStream(url)
    }
    
    public func play() {
//        adsDAIPlayerEngineWrapper.play()
//        adsDAIPlayerEngineWrapper.videoDisplayDidPlay(self)
        // TODO: is playing ad? -> send
//        if adsDAIPlayerEngineWrapper.isPlaying {
        
//            delegate.videoDisplayDidPlay(self)
//        }
    }
    
    public func pause() {
//        adsDAIPlayerEngineWrapper.pause()
//        adsDAIPlayerEngineWrapper.pause()
//        if !adsDAIPlayerEngineWrapper.isPlaying {
//            delegate.videoDisplayDidPause(self)
//        }
    }
    
    public func reset() {
        
    }
    
    public func seekStream(toTime time: TimeInterval) {
        adsDAIPlayerEngineWrapper.seek(to: time)
    }
    
    public var currentMediaTime: TimeInterval {
        get {
            return adsDAIPlayerEngineWrapper.currentTime
        }
    }
    
    public var totalMediaTime: TimeInterval {
        return adsDAIPlayerEngineWrapper.duration
    }
    
    public var bufferedMediaTime: TimeInterval {
        return 0
    }
    
    public var isPlaying: Bool {
        return adsDAIPlayerEngineWrapper.isPlaying
    }
    
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
    
    // MARK: - AdsDAIPlayerEngineWrapperDelegate
    
    public func streamStarted() {
        delegate.videoDisplayDidStart(self)
    }
    
    public func adPlaying() {
//        delegate.videoDisplayDidLoad(self)
        delegate.videoDisplayDidStart(self)
        
//        adTimer = 
    }
    
    public func adPaused() {
        delegate.videoDisplayDidPause(self)
    }
    
    public func adResumed() {
        delegate.videoDisplayDidResume(self)
    }
}

// MARK: - IMAVideoDisplayDelegate

extension PKIMAVideoDisplay: IMAVideoDisplayDelegate {
    // We are only calling these function so that IMA can trigger their events.
    // You won't stop here. Any code writen here won't be performed.
    public func videoDisplayDidPlay(_ videoDisplay: IMAVideoDisplay!) {
        // Resume
    }
    
    public func videoDisplayDidPause(_ videoDisplay: IMAVideoDisplay!) {
        
    }
    
    public func videoDisplayDidResume(_ videoDisplay: IMAVideoDisplay!) {
        
    }
    
    public func videoDisplayDidStart(_ videoDisplay: IMAVideoDisplay!) {
        // Stream Started
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
