
import GoogleInteractiveMediaAds
import PlayKit
import PlayKitUtils

@objc public class IMADAIPlugin: BasePlugin, AdsDAIPlugin, PKPluginWarmUp, PlayerEngineWrapperProvider, IMAAdsLoaderDelegate, IMAStreamManagerDelegate, IMAWebOpenerDelegate {
    
    // Internal errors for requesting ads
    enum IMADAIPluginRequestError: Error {
        case missingPlayerView
        case missingVideoDisplay
        case missingLiveData
        case missingVODData
    }
    
    /// The IMA DAI plugin state machine
    private var stateMachine = BasicStateMachine(initialState: IMAState.start, allowTransitionToInitialState: false)
    
    // We must have config, an error will be thrown otherwise
    private var pluginConfig: IMADAIConfig!
    
    private var adsDAIPlayerEngineWrapper: AdsDAIPlayerEngineWrapper?
    
    private static var adsLoader: IMAAdsLoader!
    private var streamManager: IMAStreamManager?
    private var adDisplayContainer: IMAAdDisplayContainer?
    private var videoDisplay: IMAVideoDisplay?
    private var renderingSettings: IMAAdsRenderingSettings! = IMAAdsRenderingSettings()
    
    /// Timer for checking IMA requests timeout.
    private var requestTimeoutTimer: Timer?
    private var requestTimeoutInterval: TimeInterval = IMAPlugin.defaultTimeoutInterval

    private var currentCuepoint: IMACuepoint?
    private var cuepoints: [IMACuepoint] = [] {
        didSet {
            if cuepoints.count > 0 {
                var adDAICuePoints: [CuePoint] = []
                for imaCuepoint in cuepoints {
                    let cuePoint = CuePoint(startTime: imaCuepoint.startTime, endTime: imaCuepoint.endTime, played: imaCuepoint.isPlayed)
                    adDAICuePoints.append(cuePoint)
                }
                
                notify(event: AdEvent.AdCuePointsUpdate(adDAICuePoints: PKAdDAICuePoints(adDAICuePoints)))
            }
        }
    }
    
    public var isContentPlaying: Bool {
        return stateMachine.getState() == .contentPlaying
    }
    
    /************************************************************/
    // MARK: - BasePlugin
    /************************************************************/
    
    public override class var pluginName: String {
        return "IMADAIPlugin"
    }
    
    public required init(player: Player, pluginConfig: Any?, messageBus: MessageBus) throws {
        guard let imaDAIConfig = pluginConfig as? IMADAIConfig else {
            PKLog.error("Missing plugin config")
            throw PKPluginError.missingPluginConfig(pluginName: IMADAIPlugin.pluginName)
        }
        
        try super.init(player: player, pluginConfig: pluginConfig, messageBus: messageBus)
        
        self.pluginConfig = imaDAIConfig
        requestTimeoutInterval = imaDAIConfig.requestTimeoutInterval
        setupLoader(with: imaDAIConfig)
        
        self.messageBus?.addObserver(self, events: [PlayerEvent.ended]) { [weak self] event in
            guard let strongSelf = self else { return }
            // Do NOT call contentComplete! Because this will reset the IMA correlator, and the UI won't be shown on the ads upon replay.
            // strongSelf.contentComplete()
            strongSelf.notify(event: AdEvent.AllAdsCompleted())
        }
    }
    
    public override func onUpdateConfig(pluginConfig: Any) {
        PKLog.debug("pluginConfig: " + String(describing: pluginConfig))
        
        super.onUpdateConfig(pluginConfig: pluginConfig)
        
        if let adsConfig = pluginConfig as? IMADAIConfig {
            self.pluginConfig = adsConfig
        }
    }
    
    public override func destroy() {
        self.destroyManager()
        super.destroy()
    }
    
    /************************************************************/
    // MARK: - Private
    /************************************************************/
    
    private func setupLoader(with config: IMADAIConfig) {
        let imaSettings = IMASettings()
        if let ppid = config.ppid { imaSettings.ppid = ppid }
        imaSettings.language = config.language
        imaSettings.maxRedirects = config.maxRedirects
        imaSettings.enableBackgroundPlayback = config.enableBackgroundPlayback
        imaSettings.autoPlayAdBreaks = config.autoPlayAdBreaks
        imaSettings.disableNowPlayingInfo = config.disableNowPlayingInfo
        imaSettings.playerType = config.playerType
        imaSettings.playerVersion = config.playerVersion
        imaSettings.enableDebugMode = config.enableDebugMode
        
        IMADAIPlugin.adsLoader = IMAAdsLoader(settings: imaSettings)
        IMADAIPlugin.adsLoader.delegate = self
    }
    
    private func invalidateRequestTimer() {
        requestTimeoutTimer?.invalidate()
        requestTimeoutTimer = nil
    }
    
    private func createAdsLoader() {
        contentComplete()
        setupLoader(with: self.pluginConfig)
    }
    
    private static func createAdDisplayContainer(forView view: UIView, withCompanionView companionView: UIView? = nil) -> IMAAdDisplayContainer {
        // Setup ad display container and companion if exists, needs to create a new ad container for each request.
        if let cv = companionView {
            let companionAdSlot = IMACompanionAdSlot(view: companionView, width: Int(cv.frame.size.width), height: Int(cv.frame.size.height))
            return IMAAdDisplayContainer(adContainer: view, companionSlots: [companionAdSlot!])
        } else {
            return IMAAdDisplayContainer(adContainer: view, companionSlots: [])
        }
    }
    
    private func createRenderingSettings() {
        renderingSettings.webOpenerDelegate = self
        
        if let mimeTypes = pluginConfig.videoMimeTypes {
            renderingSettings.mimeTypes = mimeTypes
        }
        
        renderingSettings.bitrate = Int(pluginConfig.videoBitrate)
        
        if let loadVideoTimeout = pluginConfig.loadVideoTimeout {
            renderingSettings.loadVideoTimeout = loadVideoTimeout
        }
        
        if !pluginConfig.alwaysStartWithPreroll, let playAdsAfterTime = dataSource?.playAdsAfterTime, playAdsAfterTime > 0 {
            renderingSettings.playAdsAfterTime = playAdsAfterTime
        }
        
        if let uiElements = pluginConfig.uiElements {
            renderingSettings.uiElements = uiElements
        }
        
        renderingSettings.disableUi = pluginConfig.disableUI
        
        if let webOpenerPresentingController = pluginConfig.webOpenerPresentingController {
            renderingSettings.webOpenerPresentingController = webOpenerPresentingController
        }
    }
    
    private func notify(event: AdEvent) {
        delegate?.adsPlugin(self, didReceive: event)
        messageBus?.post(event)
    }
    
    private func isAdPlayable() -> Bool {
        guard let currentTime = player?.currentTime else { return true }
        
        for cuepoint in cuepoints {
            if cuepoint.startTime >= currentTime && cuepoint.endTime <= currentTime {
                currentCuepoint = cuepoint
                return !cuepoint.isPlayed
            }
        }
        
        return true
    }
    
    /************************************************************/
    // MARK: - AdsPlugin
    /************************************************************/
    
    weak public var dataSource: AdsPluginDataSource? {
        didSet {
            PKLog.debug("data source set")
        }
    }
    
    weak public var delegate: AdsPluginDelegate?
    
    public var isAdPlaying: Bool {
        return self.stateMachine.getState() == .adsPlaying
    }
    
    public var startWithPreroll: Bool {
        return pluginConfig.alwaysStartWithPreroll
    }
    
    public func requestAds() throws {
        guard let playerView = player?.view else {
            throw IMADAIPluginRequestError.missingPlayerView
        }
        
        adDisplayContainer = IMADAIPlugin.createAdDisplayContainer(forView: playerView, withCompanionView: pluginConfig.companionView)
        
        if let videoControlsOverlays = pluginConfig.videoControlsOverlays {
            for overlay in videoControlsOverlays {
                adDisplayContainer?.registerVideoControlsOverlay(overlay)
            }
        }
        
        guard let adsDAIPlayerEngineWrapper = self.adsDAIPlayerEngineWrapper else { throw IMADAIPluginRequestError.missingVideoDisplay }
        let imaPlayerVideoDisplay = PKIMAVideoDisplay(adsDAIPlayerEngineWrapper: adsDAIPlayerEngineWrapper)
        videoDisplay = imaPlayerVideoDisplay
        
        var request: IMAStreamRequest
        switch pluginConfig.streamType {
        case .live:
            guard let assetKey = pluginConfig.assetKey else { throw IMADAIPluginRequestError.missingLiveData }
            
            request = IMALiveStreamRequest(assetKey: assetKey,
                                           adDisplayContainer: adDisplayContainer,
                                           videoDisplay: videoDisplay)
        case .vod:
            guard let contentSourceId = pluginConfig.contentSourceId, let videoId = pluginConfig.videoId else { throw IMADAIPluginRequestError.missingVODData }
            
            request = IMAVODStreamRequest(contentSourceID: contentSourceId,
                                          videoID: videoId,
                                          adDisplayContainer: adDisplayContainer,
                                          videoDisplay: videoDisplay)
        }
        
        request.apiKey = pluginConfig.apiKey
        
        if IMADAIPlugin.adsLoader == nil || stateMachine.getState() == .adsRequestFailed || stateMachine.getState() == .adsRequestTimedOut {
            createAdsLoader()
        }
        
        PKLog.debug("Request Ads")
        IMADAIPlugin.adsLoader.requestStream(with: request)
        stateMachine.set(state: .adsRequested)
        notify(event: AdEvent.AdsRequested())
        
        requestTimeoutTimer = PKTimer.after(requestTimeoutInterval) { [weak self] _ in
            guard let strongSelf = self else { return }
            
            if strongSelf.streamManager == nil {
                PKLog.debug("Ads request timed out")
                switch strongSelf.stateMachine.getState() {
                case .adsRequested:
                    strongSelf.delegate?.adsRequestTimedOut(shouldPlay: false)
                case .adsRequestedAndPlay:
                    strongSelf.delegate?.adsRequestTimedOut(shouldPlay: true)
                default:
                    break // Should not receive timeout for any other state
                }
                // Set state to request timed out
                strongSelf.stateMachine.set(state: .adsRequestTimedOut)
                strongSelf.invalidateRequestTimer()
                // Post ads request timeout event
                strongSelf.notify(event: AdEvent.RequestTimedOut())
            }
        }
    }
    
    public func resume() {
        // No need to resume the ad because it is embeded in the stream.
    }
    
    public func pause() {
        // No need to pause the ad because it is embeded in the stream.
    }
    
    public func contentComplete() {
        IMADAIPlugin.adsLoader.contentComplete()
    }
    
    public func destroyManager() {
        invalidateRequestTimer()
        
        // In order to make multiple ad requests, StreamManager instance should be destroyed, and then contentComplete() should be called on AdsLoader.
        // This will "reset" the SDK.
        contentComplete()
        
        streamManager?.delegate = nil
        streamManager?.destroy()
        streamManager = nil
        
        // Reset the state machine
        stateMachine.reset()
        
        adDisplayContainer?.unregisterAllVideoControlsOverlays()
    }
    
    public func didPlay() {
        // Ad is embeded in the stream, state is changed upon the IMA events received.
    }
    
    public func didRequestPlay(ofType type: PlayType) {
        switch self.stateMachine.getState() {
        case .adsRequested, .adsRequestedAndPlay:
            self.stateMachine.set(state: .adsRequestedAndPlay)
        default:
            // Ad is embeded in the stream, anyway the play request is approved.
            delegate?.play(type)
        }
    }
    
    public func didEnterBackground() {
        switch stateMachine.getState() {
        case .adsRequested, .adsRequestedAndPlay:
            destroyManager()
            stateMachine.set(state: .startAndRequest)
        default:
            break
        }
    }
    
    public func willEnterForeground() {
        if stateMachine.getState() == .startAndRequest {
            try? self.requestAds()
        }
    }
    
    /************************************************************/
    // MARK: - AdsDAIPlugin
    /************************************************************/
    
    public func contentTime(forStreamTime streamTime: TimeInterval) -> TimeInterval {
        return streamManager?.contentTime(forStreamTime: streamTime) ?? streamTime
    }
    
    public func streamTime(forContentTime contentTime: TimeInterval) -> TimeInterval {
        return streamManager?.streamTime(forContentTime: contentTime) ?? contentTime
    }
    
    public func previousCuepoint(forStreamTime streamTime: TimeInterval) -> CuePoint? {
        guard let imaCuePoint = streamManager?.previousCuepoint(forStreamTime: streamTime) else { return nil }
        return CuePoint(startTime: imaCuePoint.startTime, endTime: imaCuePoint.endTime, played: imaCuePoint.isPlayed)
    }
    
    public func canPlayAd(atStreamTime streamTime: TimeInterval) -> (canPlay: Bool, duration: TimeInterval, endTime: TimeInterval)? {
        let nextStreamTime = streamTime + 1
        guard let imaCuePoint = streamManager?.previousCuepoint(forStreamTime: nextStreamTime) else {
            return nil
        }
        return (!imaCuePoint.isPlayed, imaCuePoint.endTime - imaCuePoint.startTime, imaCuePoint.endTime)
    }
    
    /************************************************************/
    // MARK: - PKPluginWarmUp
    /************************************************************/
    
    public static func warmUp() {
        // Load adsLoader in order to make IMA download the needed objects before initializing.
        // Will setup the instance when first player is loaded
        _ = IMAAdsLoader(settings: IMASettings())
    }
    
    /************************************************************/
    // MARK: - IMAContentPlayhead
    /************************************************************/
    
    @objc public var currentTime: TimeInterval {
        // IMA must receive a number value so we must check `isNaN` on any value we send.
        // Before returning `player.currentTime` we need to check `!player.currentTime.isNaN`.
        if let currentTime = player?.currentTime, !currentTime.isNaN {
            return currentTime
        }
        return 0
    }
    
    /************************************************************/
    // MARK: - PlayerEngineWrapperProvider
    /************************************************************/
    
    public func getPlayerEngineWrapper() -> PlayerEngineWrapper? {
        if adsDAIPlayerEngineWrapper == nil {
            adsDAIPlayerEngineWrapper = AdsDAIPlayerEngineWrapper(adsPlugin: self)
        }
        
        return adsDAIPlayerEngineWrapper
    }
    
    /************************************************************/
    // MARK: - IMAAdsLoaderDelegate
    /************************************************************/
    
    public func adsLoader(_ loader: IMAAdsLoader!, adsLoadedWith adsLoadedData: IMAAdsLoadedData!) {
        switch stateMachine.getState() {
        case .adsRequested:
            stateMachine.set(state: .adsLoaded)
        case .adsRequestedAndPlay:
            stateMachine.set(state: .adsLoadedAndPlay)
        default:
            break
        }
        
        invalidateRequestTimer()
        streamManager = adsLoadedData.streamManager
        adsLoadedData.streamManager.delegate = self
        
        createRenderingSettings()
        
        streamManager?.initialize(with: renderingSettings)
    }
    
    public func adsLoader(_ loader: IMAAdsLoader!, failedWith adErrorData: IMAAdLoadingErrorData!) {
        // Cancel the request timer
        invalidateRequestTimer()
        stateMachine.set(state: .adsRequestFailed)
        
        guard let adError = adErrorData.adError else { return }
        PKLog.error(adError.message)
        messageBus?.post(AdEvent.Error(nsError: IMAPluginError(adError: adError).asNSError))
        delegate?.adsPlugin(self, loaderFailedWith: adError.message)
    }
    
    /************************************************************/
    // MARK: - IMAStreamManagerDelegate
    /************************************************************/
    
    public func streamManager(_ streamManager: IMAStreamManager!, didReceive event: IMAAdEvent!) {
        PKLog.trace("Stream manager event: " + event.typeString)
        
        switch event.type {
        case .CUEPOINTS_CHANGED:
            guard let adData = event.adData else { return }
            guard let cuepoints = adData["cuepoints"] else { return }
            guard let cuepointsArray = cuepoints as? [IMACuepoint] else { return }
            self.cuepoints = cuepointsArray
        case .STREAM_LOADED:
            self.notify(event: AdEvent.StreamLoaded())
        case .STREAM_STARTED:
            self.notify(event: AdEvent.StreamStarted())
            self.stateMachine.set(state: .contentPlaying)
        case .AD_BREAK_STARTED:
            if isAdPlayable() {
                self.stateMachine.set(state: .adsPlaying)
                self.notify(event: AdEvent.AdDidRequestContentPause())
                self.notify(event: AdEvent.AdBreakStarted())
            } else {
                if let newTime = self.currentCuepoint?.endTime, let time = self.streamManager?.contentTime(forStreamTime: newTime) {
                    self.player?.seek(to: time)
                }
            }
        case .LOADED:
            let adEvent = event.ad != nil ? AdEvent.AdLoaded(adInfo: PKAdInfo(ad: event.ad)) : AdEvent.AdLoaded()
            self.notify(event: adEvent)
        case .STARTED:
            let event = event.ad != nil ? AdEvent.AdStarted(adInfo: PKAdInfo(ad: event.ad)) : AdEvent.AdStarted()
            self.notify(event: event)
        case .FIRST_QUARTILE:
            self.notify(event: AdEvent.AdFirstQuartile())
        case .MIDPOINT:
            self.notify(event: AdEvent.AdMidpoint())
        case .THIRD_QUARTILE:
            self.notify(event: AdEvent.AdThirdQuartile())
        case .PAUSE:
            self.notify(event: AdEvent.AdPaused())
        case .RESUME:
            self.notify(event: AdEvent.AdResumed())
        case .CLICKED:
            if let clickThroughUrl = event.ad.value(forKey: "clickThroughUrl") as? String {
                self.notify(event: AdEvent.AdClicked(clickThroughUrl: clickThroughUrl))
            } else {
                self.notify(event: AdEvent.AdClicked())
            }
        case .TAPPED:
            self.notify(event: AdEvent.AdTapped())
        case .SKIPPED:
            self.notify(event: AdEvent.AdSkipped())
        case .COMPLETE:
            self.notify(event: AdEvent.AdComplete())
        case .AD_BREAK_ENDED:
            self.notify(event: AdEvent.AdBreakEnded())
            self.stateMachine.set(state: .contentPlaying)
            self.notify(event: AdEvent.AdDidRequestContentResume())
        case .AD_PERIOD_STARTED:
            self.notify(event: AdEvent.AdPeriodStarted())
        case .AD_PERIOD_ENDED:
            self.notify(event: AdEvent.AdPeriodEnded())
        case .LOG:
            break
        default:
            break
        }
    }
    
    public func streamManager(_ streamManager: IMAStreamManager!, didReceive error: IMAAdError!) {
        PKLog.error(error.message)
        self.messageBus?.post(AdEvent.Error(nsError: IMAPluginError(adError: error).asNSError))
        self.delegate?.adsPlugin(self, managerFailedWith: error.message)
    }
    
    public func streamManager(_ streamManager: IMAStreamManager!,
                              adDidProgressToTime time: TimeInterval,
                              adDuration: TimeInterval,
                              adPosition: Int,
                              totalAds: Int,
                              adBreakDuration: TimeInterval) {
        self.notify(event: AdEvent.AdDidProgressToTime(mediaTime: time, totalTime: adDuration))
    }
}
