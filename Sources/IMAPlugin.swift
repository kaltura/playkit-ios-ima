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
import PlayKit
import PlayKitUtils

/// `IMAState` represents `IMAPlugin` state machine states.
enum IMAState: Int, StateProtocol, CustomStringConvertible {
    /// initial state.
    case start = 0
    /// when request was interrupted by going to background.
    /// (indicates we should make the request again when return to foreground)
    case startAndRequest
    /// ads request was made.
    case adsRequested
    /// ads request was made and play() was used.
    case adsRequestedAndPlay
    /// the ads request failed (loader failed to load ads and error was sent)
    case adsRequestFailed 
    /// the ads request was timed out.
    case adsRequestTimedOut
    /// ads request was succeeded and loaded.
    case adsLoaded
    /// ads request was succeeded and loaded and play() was used.
    case adsLoadedAndPlay
    /// ads are playing.
    case adsPlaying
    /// content is playing.
    case contentPlaying
    
    var description: String {
        switch self {
        case .start: return "Start"
        case .startAndRequest: return "StartAndRequest"
        case .adsRequested: return "AdsRequested"
        case .adsRequestedAndPlay: return "AdsRequestedAndPlay"
        case .adsRequestFailed: return "AdsRequestFailed"
        case .adsRequestTimedOut: return "AdsRequestTimedOut"
        case .adsLoaded: return "AdsLoaded"
        case .adsLoadedAndPlay: return "AdsLoadedAndPlay"
        case .adsPlaying: return "AdsPlaying"
        case .contentPlaying: return "contentPlaying"
        }
    }
}

@objc public class IMAPlugin: BasePlugin, PKPluginWarmUp, AdsPlugin, PlayerDecoratorProvider, PlayerEngineWrapperProvider, IMAAdsLoaderDelegate, IMAAdsManagerDelegate, IMAWebOpenerDelegate, IMAContentPlayhead {

    // internal errors for requesting ads
    enum IMAPluginRequestError: Error {
        case missingPlayerView
        case emptyAdTag
    }
    
    /// the default timeout interval for ads request.
    static let defaultTimeoutInterval: TimeInterval = 5
    
    weak public var dataSource: AdsPluginDataSource? {
        didSet {
            PKLog.debug("data source set")
        }
    }
    weak public var delegate: AdsPluginDelegate?
    #if os(iOS)
    weak public var pipDelegate: AVPictureInPictureControllerDelegate?
    #endif
    
    /// The IMA plugin state machine
    private var stateMachine = BasicStateMachine(initialState: IMAState.start, allowTransitionToInitialState: false)
    
    private static var loader: IMAAdsLoader!
    private static let loaderRetryCount = 3
    private var loaderRetries = IMAPlugin.loaderRetryCount
    
    private var adsManager: IMAAdsManager?
    private var renderingSettings: IMAAdsRenderingSettings! = IMAAdsRenderingSettings()
    private var pictureInPictureProxy: IMAPictureInPictureProxy?
    
    // we must have config error will be thrown otherwise
    private var config: IMAConfig!
    
    /// timer for checking IMA requests timeout.
    private var requestTimeoutTimer: Timer?
    /// the request timeout interval
    private var requestTimeoutInterval: TimeInterval = IMAPlugin.defaultTimeoutInterval
    
    private var adDisplayContainer: IMAAdDisplayContainer?
    
    private var pkAdInfo: PKAdInfo?
    private var contentEndedNeedToPlayPostroll: Bool = false

    /************************************************************/
    // MARK: - IMAContentPlayhead
    /************************************************************/
    
    @objc public var currentTime: TimeInterval {
        // IMA must receive a number value so we must check `isNaN` on any value we send.
        // Before returning `player.currentTime` we need to check `!player.currentTime.isNaN`.
        if let currentTime = self.player?.currentTime, !currentTime.isNaN {
            return currentTime
        }
        return 0
    }
    
    /************************************************************/
    // MARK: - PKWarmUpProtocol
    /************************************************************/
    
    @objc public static func warmUp() {
        // load adsLoader in order to make IMA download the needed objects before initializing.
        // will setup the instance when first player is loaded
        _ = IMAAdsLoader(settings: IMASettings())
    }
    
    /************************************************************/
    // MARK: - PKPlugin
    /************************************************************/
    
    @objc public override class var pluginName: String { return "IMAPlugin" }
    
    @objc public required init(player: Player, pluginConfig: Any?, messageBus: MessageBus) throws {
        guard let imaConfig = pluginConfig as? IMAConfig else {
            PKLog.error("missing plugin config")
            throw PKPluginError.missingPluginConfig(pluginName: IMAPlugin.pluginName)
        }
        
        try super.init(player: player, pluginConfig: pluginConfig, messageBus: messageBus)
        
        self.config = imaConfig
        self.requestTimeoutInterval = imaConfig.requestTimeoutInterval
        
        self.createLoader()
        
        self.messageBus?.addObserver(self, events: [PlayerEvent.ended]) { [weak self] event in
            guard let self = self else { return }
            
            guard let adCuePoints = self.adsManager?.adCuePoints as? [NSNumber], adCuePoints.count > 1 else {
                // There is only one ad, nothing left to do
                self.contentComplete()
                return
            }
            
            guard adCuePoints.last == -1 else {
                // There is no Post-roll, nothing left to do
                self.contentComplete()
                return
            }
            
            // There is a Post-roll and there are more than one ads
            let duration = player.duration
            var lastValidCuePoint: Double = 0
            
            for cuePoint in adCuePoints {
                if cuePoint.doubleValue <= duration && lastValidCuePoint < cuePoint.doubleValue {
                    lastValidCuePoint = cuePoint.doubleValue
                }
            }
            
            if self.pkAdInfo?.timeOffset != lastValidCuePoint {
                // Last valid CuePoint wasn't played, need to wait for it
                self.contentEndedNeedToPlayPostroll = true
            } else {
                self.contentComplete()
            }
        }
    }
    
    public override func onUpdateConfig(pluginConfig: Any) {
        PKLog.debug("pluginConfig: " + String(describing: pluginConfig))
        
        super.onUpdateConfig(pluginConfig: pluginConfig)
        
        if let adsConfig = pluginConfig as? IMAConfig {
            self.config = adsConfig
        }
    }
    
    public override func destroy() {
        super.destroy()
        self.requestTimeoutTimer?.invalidate()
        self.requestTimeoutTimer = nil
        self.destroyManager()
        
        self.adDisplayContainer?.unregisterAllFriendlyObstructions()
    }
    
    /************************************************************/
    // MARK: - PlayerDecoratorProvider
    /************************************************************/
    
    @objc public func getPlayerDecorator() -> PlayerDecoratorBase? {
        return nil
    }

    /************************************************************/
    // MARK: - PlayerEngineWrapperProvider
    /************************************************************/
    
    public func getPlayerEngineWrapper() -> PlayerEngineWrapper? {
        return AdsPlayerEngineWrapper(adsPlugin: self)
    }
    
    /************************************************************/
    // MARK: - AdsPlugin
    /************************************************************/
    
    public var isAdPlaying: Bool {
        return adsManager?.adPlaybackInfo.isPlaying ?? (self.stateMachine.getState() == .adsPlaying)
    }
    
    public var startWithPreroll: Bool {
        return config.alwaysStartWithPreroll
    }
    
    public func requestAds() throws {
        guard let playerView = self.player?.view else { throw IMAPluginRequestError.missingPlayerView }
        
        if self.config.adTagUrl.isEmpty && self.config.adsResponse.isEmpty {
            PKLog.debug("Can't request ads, at least one of adTagUrl and adsResponse must be provided.")
            throw IMAPluginRequestError.emptyAdTag
        }
        
        adDisplayContainer = IMAPlugin.createAdDisplayContainer(forView: playerView, viewController: playerView.findViewController(), withCompanionView: self.config.companionView)
        
        self.adDisplayContainer?.unregisterAllFriendlyObstructions()
        if let videoControlsOverlays = self.config?.videoControlsOverlays {
            for overlay in videoControlsOverlays {
                adDisplayContainer?.register(IMAFriendlyObstruction(view: overlay, purpose: .mediaControls, detailedReason: nil))
            }
        }
        
        let request: IMAAdsRequest?
        if !self.config.adTagUrl.isEmpty {
            request = IMAAdsRequest(adTagUrl: self.config.adTagUrl, adDisplayContainer: adDisplayContainer, contentPlayhead: self, userContext: nil)
        } else {
            request = IMAAdsRequest(adsResponse: self.config.adsResponse, adDisplayContainer: adDisplayContainer, contentPlayhead: self, userContext: nil)
        }
        
        if let vastLoadTimeout = self.config.vastLoadTimeout {
            request?.vastLoadTimeout = vastLoadTimeout.floatValue
        }
        
        // If the device volume is muted, this is not indicated by the mute switch.
        if AVAudioSession.sharedInstance().outputVolume == 0 {
            request?.adWillPlayMuted = true
        }
        
        // sets the state
        self.stateMachine.set(state: .adsRequested)
        // make sure loader exists otherwise create.
        if IMAPlugin.loader == nil {
            self.createLoader()
        }
        // request ads
        PKLog.debug("request Ads")
        IMAPlugin.loader.requestAds(with: request)
        // notify ads requested
        self.notify(event: AdEvent.AdsRequested(adTagUrl: self.config.adTagUrl))
        // start timeout timer
        self.requestTimeoutTimer = PKTimer.after(self.requestTimeoutInterval) { [weak self] _ in
            
            guard let self = self else { return }
            
            if self.adsManager == nil {
                PKLog.debug("Ads request timed out")
                switch self.stateMachine.getState() {
                case .adsRequested: self.delegate?.adsRequestTimedOut(shouldPlay: false)
                case .adsRequestedAndPlay: self.delegate?.adsRequestTimedOut(shouldPlay: true)
                default: break // should not receive timeout for any other state
                }
                // set state to request failure
                self.stateMachine.set(state: .adsRequestTimedOut)
                
                self.invalidateRequestTimer()
                // post ads request timeout event
                self.notify(event: AdEvent.RequestTimedOut())
            }
        }
    }
    
    public func resume() {
        self.adsManager?.resume()
    }
    
    public func pause() {
        self.adsManager?.pause()
    }
    
    public func contentComplete() {
        IMAPlugin.loader?.contentComplete()
    }
    
    public func destroyManager() {
        self.invalidateRequestTimer()
        self.adsManager?.delegate = nil
        self.adsManager?.destroy()
        // In order to make multiple ad requests, AdsManager instance should be destroyed, and then contentComplete() should be called on AdsLoader.
        // This will "reset" the SDK.
        self.contentComplete()
        self.adsManager = nil
        // reset the state machine
        self.stateMachine.reset()
    }
    
    // when play() was used set state to content playing
    public func didPlay() {
        self.stateMachine.set(state: .contentPlaying)
    }
    
    public func didRequestPlay(ofType type: PlayType) {
        switch self.stateMachine.getState() {
        case .adsLoaded: self.startAd()
        case .adsRequested: self.stateMachine.set(state: .adsRequestedAndPlay)
        case .adsPlaying: self.resume()
        default: self.delegate?.play(type)
        }
    }
    
    public func didEnterBackground() {
        switch self.stateMachine.getState() {
        case .adsRequested, .adsRequestedAndPlay:
            self.destroyManager()
            self.stateMachine.set(state: .startAndRequest)
        default: break
        }
    }
    
    public func willEnterForeground() {
        switch self.stateMachine.getState() {
        case .startAndRequest:
            try? self.requestAds()
        default:
            break
        }
    }
    
    /************************************************************/
    // MARK: - AdsLoaderDelegate
    /************************************************************/
    
    @objc public func adsLoader(_ loader: IMAAdsLoader!, adsLoadedWith adsLoadedData: IMAAdsLoadedData!) {
        self.loaderRetries = IMAPlugin.loaderRetryCount
        
        switch self.stateMachine.getState() {
        case .adsRequested: self.stateMachine.set(state: .adsLoaded)
        case .adsRequestedAndPlay: self.stateMachine.set(state: .adsLoadedAndPlay)
        default: self.invalidateRequestTimer()
        }
        
        self.adsManager = adsLoadedData.adsManager
        adsLoadedData.adsManager.delegate = self
        self.createRenderingSettings()
        
        // initialize on ads manager starts the ads loading process, we want to initialize it only after play.
        // `adsLoaded` state is when ads request succeeded but play haven't been received yet, 
        // we don't want to initialize ads manager until play() will be used.
        if self.stateMachine.getState() != .adsLoaded {
            self.initAdsManager()
        }
    }
    
    @objc public func adsLoader(_ loader: IMAAdsLoader!, failedWith adErrorData: IMAAdLoadingErrorData!) {
        // cancel the request timer
        self.invalidateRequestTimer()
        self.stateMachine.set(state: .adsRequestFailed)
        
        guard let adError = adErrorData.adError else {
            PKLog.error("AdsLoader faild with error.")
            return
        }
        let adErrorMessage: String = adError.message == nil ? "" : adError.message
        PKLog.error(adErrorMessage)
        self.messageBus?.post(AdEvent.Error(nsError: IMAPluginError(adError: adError).asNSError))
        self.delegate?.adsPlugin(self, loaderFailedWith: adErrorMessage)
        
        // if the error relates to IMA SDK failed to load recreate loader instance.
        // otherwise loader will never work again
        IMAPlugin.loader = nil
        if (adError.code.rawValue == 1005 || adError.code.rawValue == 1010) && self.loaderRetries > 0 {
            self.loaderRetries -= 1
            try? self.requestAds()
        }
    }
    
    /************************************************************/
    // MARK: - AdsManagerDelegate
    /************************************************************/
    
    @objc public func adsManagerAdDidStartBuffering(_ adsManager: IMAAdsManager!) {
        self.notify(event: AdEvent.AdStartedBuffering())
    }
    
    @objc public func adsManagerAdPlaybackReady(_ adsManager: IMAAdsManager!) {
        self.notify(event: AdEvent.AdPlaybackReady())
    }
    
    @objc public func adsManager(_ adsManager: IMAAdsManager!, didReceive event: IMAAdEvent!) {
        PKLog.trace("ads manager event: " + String(describing: event))
        let currentState = self.stateMachine.getState()
        
        switch event.type {
        // Ad break, will be called before each scheduled ad break. Ad breaks may contain more than 1 ad.
        // `event.ad` is not available at this point do not use it here.
        case .AD_BREAK_READY:
            self.notify(event: AdEvent.AdBreakReady())
            guard canPlayAd(forState: currentState) else { return }
            self.start(adsManager: adsManager)
            
        // single ad only fires `LOADED` without `AD_BREAK_READY`.
        case .LOADED:
            if shouldDiscard(ad: event.ad, currentState: currentState) {
                self.discardAdBreak(adsManager: adsManager)
            } else {
                var adEvent = AdEvent.AdLoaded()
                if event.ad != nil {
                    let adInfo = PKAdInfo(ad: event.ad)
                    self.pkAdInfo = adInfo
                    adEvent = AdEvent.AdLoaded(adInfo: adInfo)
                }
                self.notify(event: adEvent)
                // if we have more than one ad don't start the manager, it will be handled in `AD_BREAK_READY`
                guard adsManager.adCuePoints.count == 0 else { return }
                guard canPlayAd(forState: currentState) else { return }
                self.start(adsManager: adsManager)
            }
            
        case .STARTED:
            self.stateMachine.set(state: .adsPlaying)
            var adEvent = AdEvent.AdStarted()
            if event.ad != nil {
                let adInfo = PKAdInfo(ad: event.ad)
                self.pkAdInfo = adInfo
                adEvent = AdEvent.AdStarted(adInfo: PKAdInfo(ad: event.ad))
            }
            self.notify(event: adEvent)
            
        case .ALL_ADS_COMPLETED:
            // detaching the delegate and destroying the adsManager.
            // means all ads have been played so we can destroy the adsManager.
            self.destroyManager()
            self.notify(event: AdEvent.AllAdsCompleted())
            
        case .CLICKED:
            if let clickThroughUrl = event.ad.value(forKey: "clickThroughUrl") as? String {
                self.notify(event: AdEvent.AdClicked(clickThroughUrl: clickThroughUrl))
            } else {
                self.notify(event: AdEvent.AdClicked())
            }
            
        case .COMPLETE:
            self.notify(event: AdEvent.AdComplete())
            if pkAdInfo?.adPosition == pkAdInfo?.totalAds, contentEndedNeedToPlayPostroll {
                contentEndedNeedToPlayPostroll = false
                contentComplete()
            }
            
        case .FIRST_QUARTILE:
            self.notify(event: AdEvent.AdFirstQuartile())
            
        case .LOG:
            self.notify(event: AdEvent.AdLog())
            
        case .MIDPOINT:
            self.notify(event: AdEvent.AdMidpoint())
            
        case .PAUSE:
            self.notify(event: AdEvent.AdPaused())
            
        case .RESUME:
            self.notify(event: AdEvent.AdResumed())
            
        case .SKIPPED:
            self.notify(event: AdEvent.AdSkipped())
            
        case .TAPPED:
            self.notify(event: AdEvent.AdTapped())
            
        case .THIRD_QUARTILE:
            self.notify(event: AdEvent.AdThirdQuartile())
            
        // Only used for dynamic ad insertion (not officially supported)
        case .AD_BREAK_ENDED, .AD_BREAK_STARTED, .CUEPOINTS_CHANGED, .STREAM_LOADED, .STREAM_STARTED, .AD_PERIOD_STARTED, .AD_PERIOD_ENDED, .AD_BREAK_FETCH_ERROR:
            break
        // This event only fires for tvOS
        case .ICON_FALLBACK_IMAGE_CLOSED:
            break
        case .ICON_TAPPED:
            break
        @unknown default:
            break
        }
    }
    
    @objc public func adsManager(_ adsManager: IMAAdsManager!, didReceive error: IMAAdError!) {
        PKLog.error(error.message)
        self.messageBus?.post(AdEvent.Error(nsError: IMAPluginError(adError: error).asNSError))
        self.delegate?.adsPlugin(self, managerFailedWith: error.message)
    }
    
    @objc public func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager!) {
        self.stateMachine.set(state: .adsPlaying)
        self.notify(event: AdEvent.AdDidRequestContentPause())
    }
    
    @objc public func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager!) {
        self.stateMachine.set(state: .contentPlaying)
        self.notify(event: AdEvent.AdDidRequestContentResume())
    }
    
    @objc public func adsManager(_ adsManager: IMAAdsManager!, adDidProgressToTime mediaTime: TimeInterval, totalTime: TimeInterval) {
        self.notify(event: AdEvent.AdDidProgressToTime(mediaTime: mediaTime, totalTime: totalTime))
    }
    
    /************************************************************/
    // MARK: - Private
    /************************************************************/
    
    private func setupLoader(with config: IMAConfig) {
        let imaSettings: IMASettings! = IMASettings()
        if let ppid = config.ppid { imaSettings.ppid = ppid }
        imaSettings.language = config.language
        imaSettings.maxRedirects = config.maxRedirects
        imaSettings.enableBackgroundPlayback = config.enableBackgroundPlayback
        imaSettings.autoPlayAdBreaks = config.autoPlayAdBreaks
        imaSettings.playerType = config.playerType
        imaSettings.playerVersion = config.playerVersion
        imaSettings.enableDebugMode = config.enableDebugMode
        
        IMAPlugin.loader = IMAAdsLoader(settings: imaSettings)
    }
    
    private func createLoader() {
        self.setupLoader(with: self.config)
        IMAPlugin.loader.delegate = self
    }
    
    private func createRenderingSettings() {
        self.renderingSettings.webOpenerDelegate = self
        
        if let webOpenerPresentingController = self.config?.webOpenerPresentingController {
            self.renderingSettings.webOpenerPresentingController = webOpenerPresentingController
        }
        
        if let bitrate = self.config?.videoBitrate {
            self.renderingSettings.bitrate = Int(bitrate)
        }
        
        if let mimeTypes = self.config?.videoMimeTypes {
            self.renderingSettings.mimeTypes = mimeTypes
        }

        if !config.alwaysStartWithPreroll, let playAdsAfterTime = self.dataSource?.playAdsAfterTime, playAdsAfterTime > 0 {
            self.renderingSettings.playAdsAfterTime = playAdsAfterTime
        }
    }
    
    private func notify(event: AdEvent) {
        self.delegate?.adsPlugin(self, didReceive: event)
        self.messageBus?.post(event)
    }
    
    private func notifyAdCuePoints(fromAdsManager adsManager: IMAAdsManager) {
        // send ad cue points if exists and request is url type
        let adCuePoints = adsManager.getAdCuePoints()
        if adCuePoints.count > 0 {
            self.notify(event: AdEvent.AdCuePointsUpdate(adCuePoints: adCuePoints))
        }
    }
    
    private func start(adsManager: IMAAdsManager) {
        adsManager.start()
    }
    
    private func initAdsManager() {
        self.adsManager!.initialize(with: self.renderingSettings)
        PKLog.debug("ads manager set")
        self.notifyAdCuePoints(fromAdsManager: self.adsManager!)
    }
    
    private func invalidateRequestTimer() {
        self.requestTimeoutTimer?.invalidate()
        self.requestTimeoutTimer = nil
    }
    
    /// called when plugin need to start the ad playback on first ad play only
    private func startAd() {
        self.stateMachine.set(state: .adsLoadedAndPlay)
        self.initAdsManager()
    }
    
    /// protects against cases where the ads manager will load after timeout.
    /// this way we will only start ads when ads loaded and play() was used or when we came from content playing.
    private func canPlayAd(forState state: IMAState) -> Bool {
        if state == .adsLoadedAndPlay || state == .contentPlaying {
            return true
        }
        return false
    }
    
    private func shouldDiscard(ad: IMAAd, currentState: IMAState) -> Bool {
        let adInfo = PKAdInfo(ad: ad,
                              podCount: nil,
                              adPlayHead: adsManager?.adPlaybackInfo.currentMediaTime)
        let isPreRollInvalid = adInfo.positionType == .preRoll && (currentState == .adsRequestTimedOut || currentState == .contentPlaying)
        if isPreRollInvalid {
            return true
        }
        
        if adInfo.positionType == .preRoll && !startWithPreroll && renderingSettings.playAdsAfterTime > 0 {
            return true
        }
        return false
    }
    
    private func discardAdBreak(adsManager: IMAAdsManager) {
        PKLog.debug("discard Ad Break")
        adsManager.discardAdBreak()
        self.adsManagerDidRequestContentResume(adsManager)
    }
    
    /************************************************************/
    // MARK: - IMAWebOpenerDelegate
    /************************************************************/
    
    @objc public func webOpenerWillOpenExternalBrowser(_ webOpener: NSObject) {
        self.notify(event: AdEvent.AdWebOpenerWillOpenExternalBrowser(webOpener: webOpener))
    }
    
    @objc public func webOpenerWillOpen(inAppBrowser webOpener: NSObject!) {
        self.notify(event: AdEvent.AdWebOpenerWillOpenInAppBrowser(webOpener: webOpener))
    }
    
    @objc public func webOpenerDidOpen(inAppBrowser webOpener: NSObject!) {
        self.notify(event: AdEvent.AdWebOpenerDidOpenInAppBrowser(webOpener: webOpener))
    }
    
    @objc public func webOpenerWillClose(inAppBrowser webOpener: NSObject!) {
        self.notify(event: AdEvent.AdWebOpenerWillCloseInAppBrowser(webOpener: webOpener))
    }
    
    @objc public func webOpenerDidClose(inAppBrowser webOpener: NSObject!) {
        self.notify(event: AdEvent.AdWebOpenerDidCloseInAppBrowser(webOpener: webOpener))
    }
}

#if os(iOS)
extension IMAPlugin: PIPEnabledAdsPlugin {
    
    /************************************************************/
    // MARK: - AVPictureInPictureControllerDelegate
    /************************************************************/
    
    @available(iOS 9.0, *)
    @objc public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.pipDelegate?.pictureInPictureControllerWillStartPictureInPicture?(pictureInPictureController)
    }
    
    @available(iOS 9.0, *)
    @objc public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.pipDelegate?.pictureInPictureControllerDidStartPictureInPicture?(pictureInPictureController)
    }
    
    @available(iOS 9.0, *)
    @objc public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        self.pipDelegate?.pictureInPictureController?(pictureInPictureController, failedToStartPictureInPictureWithError: error)
    }
    
    @available(iOS 9.0, *)
    @objc public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.pipDelegate?.pictureInPictureControllerWillStopPictureInPicture?(pictureInPictureController)
    }
    
    @available(iOS 9.0, *)
    @objc public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.pipDelegate?.pictureInPictureControllerDidStopPictureInPicture?(pictureInPictureController)
    }
    
    @available(iOS 9.0, *)
    @objc public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        self.pipDelegate?.pictureInPictureController?(pictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: completionHandler)
    }
}
#endif
