
import GoogleInteractiveMediaAds
import PlayKit
import PlayKitUtils

@objc public class IMADAIPlugin: BasePlugin, PKPluginWarmUp, IMAAdsLoaderDelegate, IMAStreamManagerDelegate, IMAWebOpenerDelegate, AdsPlugin {
    
    /// The IMA DAI plugin state machine
    private var stateMachine = BasicStateMachine(initialState: IMAState.start, allowTransitionToInitialState: false)
    
    private static var loader: IMAAdsLoader!
    // We must have config, an error will be thrown otherwise
    private var config: IMADAIConfig!
    
    private var streamManager: IMAStreamManager?
    private var renderingSettings: IMAAdsRenderingSettings! = IMAAdsRenderingSettings()
    
    /// Timer for checking IMA requests timeout.
    private var requestTimeoutTimer: Timer?
    /// The request timeout interval
    private var requestTimeoutInterval: TimeInterval = IMAPlugin.defaultTimeoutInterval

    private var adDisplayContainer: IMAAdDisplayContainer?
    
    /// Tracking for play/pause.
    private var adPlaying: Bool = false
    private var streamPlaying: Bool = false
    // Maintains seeking status for snapback.
    private var seekStartTime: CMTime = kCMTimeZero
    private var seekEndTime: CMTime = kCMTimeZero
    private var snapbackMode: Bool = false
    private var currentlySeeking: Bool = false
    
    
    // MARK: - AdsPlugin - Properties
    weak var dataSource: AdsPluginDataSource? {
        didSet {
            PKLog.debug("data source set")
        }
    }
    weak var delegate: AdsPluginDelegate?
    var pipDelegate: AVPictureInPictureControllerDelegate?
    var isAdPlaying: Bool {
        return self.stateMachine.getState() == .adsPlaying
    }
    
    /************************************************************/
    // MARK: - Private
    /************************************************************/
    
    private func setupLoader(with config: IMADAIConfig) {
        let imaSettings: IMASettings! = IMASettings()
        if let ppid = config.ppid { imaSettings.ppid = ppid }
        imaSettings.language = config.language
        imaSettings.maxRedirects = config.maxRedirects
        imaSettings.enableBackgroundPlayback = config.enableBackgroundPlayback
        imaSettings.autoPlayAdBreaks = config.autoPlayAdBreaks
        imaSettings.disableNowPlayingInfo = config.disableNowPlayingInfo
        imaSettings.playerType = config.playerType
        imaSettings.playerVersion = config.playerVersion
        imaSettings.enableDebugMode = config.enableDebugMode
        
        IMADAIPlugin.loader = IMAAdsLoader(settings: imaSettings)
    }
    
    func contentComplete() {
        IMADAIPlugin.loader?.contentComplete()
    }
    
    private func invalidateRequestTimer() {
        self.requestTimeoutTimer?.invalidate()
        self.requestTimeoutTimer = nil
    }
    
    func destroyManager() {
        self.invalidateRequestTimer()
        self.streamManager?.delegate = nil
        self.streamManager?.destroy()
        // In order to make multiple ad requests, StreamManager instance should be destroyed, and then contentComplete() should be called on AdsLoader.
        // This will "reset" the SDK.
        self.contentComplete()
        self.streamManager = nil
        // Reset the state machine
        self.stateMachine.reset()
        
        self.adDisplayContainer?.unregisterAllVideoControlsOverlays()
    }
    
    private func createRenderingSettings() {
        self.renderingSettings.webOpenerDelegate = self
        
        if let mimeTypes = self.config?.videoMimeTypes {
            self.renderingSettings.mimeTypes = mimeTypes
        }
        
        if let bitrate = self.config?.videoBitrate {
            self.renderingSettings.bitrate = Int(bitrate)
        }
        
        if let loadVideoTimeout = self.config.loadVideoTimeout {
            self.renderingSettings.loadVideoTimeout = loadVideoTimeout
        }
        
        if let playAdsAfterTime = self.dataSource?.playAdsAfterTime, playAdsAfterTime > 0 {
            self.renderingSettings.playAdsAfterTime = playAdsAfterTime
        }
        
        if let uiElements = self.config.uiElements {
            self.renderingSettings.uiElements = uiElements
        }
        
        self.renderingSettings.disableUi = self.config.disableUI
        
        if let webOpenerPresentingController = self.config?.webOpenerPresentingController {
            self.renderingSettings.webOpenerPresentingController = webOpenerPresentingController
        }
    }
    
    private func initStreamManager() {
        self.streamManager?.initialize(with: self.renderingSettings)
        PKLog.debug("Stream manager set")
    }
    
    private func notify(event: AdEvent) {
        self.delegate?.adsPlugin(self, didReceive: event)
        self.messageBus?.post(event)
    }
    
    /// protects against cases where the ads manager will load after timeout.
    /// this way we will only start ads when ads loaded and play() was used or when we came from content playing.
    private func canPlayAd(forState state: IMAState) -> Bool {
        if state == .adsLoadedAndPlay || state == .contentPlaying {
            return true
        }
        return false
    }
    
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
    // MARK: - PKPluginWarmUp
    /************************************************************/
    
    public static func warmUp() {
        // load adsLoader in order to make IMA download the needed objects before initializing.
        // will setup the instance when first player is loaded
//        _ = IMAAdsLoader(settings: IMASettings())
    }
    
    /************************************************************/
    // MARK: - PKPlugin
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
        
        self.config = imaDAIConfig
        self.requestTimeoutInterval = imaDAIConfig.requestTimeoutInterval
        if IMADAIPlugin.loader == nil {
            self.setupLoader(with: imaDAIConfig)
        }
        
//        IMADAIPlugin.loader.contentComplete() // For previous one
        IMADAIPlugin.loader.delegate = self
        
        self.messageBus?.addObserver(self, events: [PlayerEvent.ended]) { [weak self] event in
            self?.contentComplete()
        }
    }
    
    public override func onUpdateConfig(pluginConfig: Any) {
        PKLog.debug("pluginConfig: " + String(describing: pluginConfig))
        
        super.onUpdateConfig(pluginConfig: pluginConfig)
        
        if let adsConfig = pluginConfig as? IMADAIConfig {
            self.config = adsConfig
        }
    }
    
    public override func destroy() {
        super.destroy()
        self.destroy()
    }
    
    /************************************************************/
    // MARK: - IMAAdsLoaderDelegate
    /************************************************************/
    
    public func adsLoader(_ loader: IMAAdsLoader!, adsLoadedWith adsLoadedData: IMAAdsLoadedData!) {
//        self.loaderRetries = IMAPlugin.loaderRetryCount
        
        switch self.stateMachine.getState() {
        case .adsRequested:
            self.stateMachine.set(state: .adsLoaded)
        case .adsRequestedAndPlay:
            self.stateMachine.set(state: .adsLoadedAndPlay)
        default: self.invalidateRequestTimer()
        }
        
        self.streamManager = adsLoadedData.streamManager
        adsLoadedData.streamManager.delegate = self
        
        self.createRenderingSettings()
        
        // Initialize on the stream manager starts the ads loading process, we want to initialize it only after play.
        // Machine state `adsLoaded` is when ads request succeeded but play haven't been received yet.
        // We don't want to initialize the stream manager until play() has been performed.
        if self.stateMachine.getState() == .adsLoadedAndPlay {
            self.initStreamManager()
        }
    }
    
    public func adsLoader(_ loader: IMAAdsLoader!, failedWith adErrorData: IMAAdLoadingErrorData!) {
        // Cancel the request timer
        self.invalidateRequestTimer()
        self.stateMachine.set(state: .adsRequestFailed)
        
        guard let adError = adErrorData.adError else { return }
        PKLog.error(adError.message)
        self.messageBus?.post(AdEvent.Error(nsError: IMAPluginError(adError: adError).asNSError))
        self.delegate?.adsPlugin(self, loaderFailedWith: adError.message)
    }
    
    /************************************************************/
    // MARK: - IMAStreamManagerDelegate
    /************************************************************/
    
    public func streamManager(_ streamManager: IMAStreamManager!, didReceive event: IMAAdEvent!) {
        PKLog.trace("Stream manager event: " + event.typeString)
        let currentState = self.stateMachine.getState()
        
        switch event.type {
        case .STARTED:
//            ad.adPodInfo
            self.stateMachine.set(state: .adsPlaying)
            let event = (event.ad != nil) ? AdEvent.AdStarted(adInfo: PKAdInfo(ad: event.ad)) : AdEvent.AdStarted()
            self.notify(event: event)
        case .AD_BREAK_READY:
            self.notify(event: AdEvent.AdBreakReady())
//            guard canPlayAd(forState: currentState) else { return }
//            self.start(
        case .AD_BREAK_STARTED:
            self.adPlaying = true
            let event = AdEvent.AdBreakStarted()
            self.notify(event: event)
        case .AD_BREAK_ENDED:
            self.adPlaying = false
            if self.snapbackMode {
                self.snapbackMode = false
                let currentTime = CMTime(seconds: self.currentTime, preferredTimescale: 1)
                if (CMTimeCompare(self.seekEndTime, currentTime) == 1) {
                    self.player?.seek(to: CMTimeGetSeconds(self.seekEndTime))
                }
            }
        case .STREAM_LOADED:
            if self.config.streamType == .vod {
                
            }
        default:
            break
        }
    }
    
    public func streamManager(_ streamManager: IMAStreamManager!, didReceive error: IMAAdError!) {
        <#code#>
    }
    
    public func streamManager(_ streamManager: IMAStreamManager!, adDidProgressToTime time: TimeInterval, adDuration: TimeInterval, adPosition: Int, totalAds: Int, adBreakDuration: TimeInterval) {
        <#code#>
    }
    
    /************************************************************/
    // MARK - AdsPlugin
    /************************************************************/
    
    
    
    func requestAds() throws {
        <#code#>
    }
    
    func resume() {
        <#code#>
    }
    
    func pause() {
        <#code#>
    }
    
    func didPlay() {
        <#code#>
    }
    
    func didRequestPlay(ofType type: AdsEnabledPlayerController.PlayType) {
        <#code#>
    }
    
    func didEnterBackground() {
        <#code#>
    }
    
    func willEnterForeground() {
        <#code#>
    }
}
