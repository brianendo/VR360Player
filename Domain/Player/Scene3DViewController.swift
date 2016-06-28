//
//  Scene3DViewController.swift
//  VR360Player
//
//  Created by Brian Endo on 6/23/16.
//  Copyright © 2016 Brian Endo. All rights reserved.
//


import GLKit
import CoreMotion
import AVFoundation
import CoreImage


let ONE_FRAME_DURATION = 0.033
let HIDE_CONTROL_DELAY = 3.0
let DEFAULT_VIEW_ALPHA = 0.6
let kTracksKey = "tracks"
let kPlayableKey = "playable"
let kRateKey = "rate"
let kCurrentItemKey = "currentItem"
let kStatusKey = "status"


var AVPlayerDemoPlaybackViewControllerRateObservationContext = UnsafeMutablePointer<Void>()
var AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = UnsafeMutablePointer<Void>()
var AVPlayerDemoPlaybackViewControllerStatusObservationContext = UnsafeMutablePointer<Void>()
var AVPlayerItemStatusContext = UnsafeMutablePointer<Void>()

class Scene3DViewController: GLKViewController
{
    // MARK: - IBOutlets
    @IBOutlet private weak var scene3DView: Scene3DView!
    @IBOutlet weak var playerControlBackgroundView: UIView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var positionButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var filterButton: UIButton!
    
    // MARK: - Variables
    private var context: EAGLContext!
    private var skysphere: Skysphere!
    var isUsingMotion: Bool!
    var savedGyroRotationX: Float!
    var savedGyroRotationY: Float!
    var motionManager: CMMotionManager!
    var referenceAttitude: CMAttitude!
    var overture: Double!
    var fingerRotationX: Float = 0.0
    var fingerRotationY: Float = 0.0
    var mRestoreAfterScrubbingRate: Float = 0.0
    var timeObserver: AnyObject!
    var filterApplied = false
    let filter = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.height, height: UIScreen.mainScreen().bounds.width))
    var speedIncreased = false
    private let singleFrameInterval: NSTimeInterval = 0.02
    var videoURL = "https://mettavr.s3.amazonaws.com/videos/guillaume.sabran.ccwn57bhyfxxy4ams/converted/reprocessed.720/FmHKpTcOPw.scale-720.fps-30.ZWM6GNXZR1.mp4"
    private var videoOutput: AVPlayerItemVideoOutput!
    private var player = AVPlayer()
    private var playerItem: AVPlayerItem!
    private var videoOutputQueue: dispatch_queue_t!
    private var seekToZeroBeforePlay: Bool!
    
    // MARK: - initialize
    deinit
    {
        if EAGLContext.currentContext() == self.context
        {
            EAGLContext.setCurrentContext(nil)
        }
    }

    override func prefersStatusBarHidden() -> Bool
    {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Landscape
    }

    override func viewDidLoad()
    {
        
        filterButton.layer.borderWidth = 1.0
        filterButton.layer.masksToBounds = false
        filterButton.layer.borderColor = UIColor.whiteColor().CGColor
        filterButton.layer.cornerRadius = 8
        filterButton.clipsToBounds = true
        
        super.viewDidLoad()
        self.view.bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
        self.configureVideoPlayback()
        self.configureContext()
        self.configureView()
        self.configurePlayButton()
        self.configureProgressSlider()
        self.configureControlBackgroundView()
        
    }

    // This is one of update variants used by GLKViewController.
    // See comment to GLKViewControllerDelegate.glkViewControllerUpdate for more info.
    func update()
    {
        self.currentFrame(
            {
                [weak self] (size, frameData) -> (Void) in
                self?.skysphere.updateTexture(size, imageData: frameData)
            })
    }

    
    // MARK: - Configuration
    private func configureContext()
    {
        self.context = EAGLContext(API: EAGLRenderingAPI.OpenGLES3)
        EAGLContext.setCurrentContext(self.context)
    }

    private func configureView()
    {
        self.scene3DView.context = self.context

        self.skysphere = Skysphere(radius: 60)
        self.scene3DView.addSceneObject(self.skysphere)
        
        self.view.addSubview(playerControlBackgroundView)

        
        
        // Pan gesture recognizer
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(Scene3DViewController.panGestureAction(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        self.view.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(Scene3DViewController.handleSingleTapGesture(_:)))
        self.view.addGestureRecognizer(tapGesture)
    }
    
    func configureControlBackgroundView() {
        self.playerControlBackgroundView.layer.cornerRadius = 8
    }
    
    override func viewDidDisappear(animated: Bool) {
        if self.player.rate > 0 {
            self.player.pause()
        }
    }
    
    private func configureVideoPlayback()
    {
        let url = NSURL(string: self.videoURL)
        let asset = AVURLAsset(URL: url!, options: nil)
        let requestedKeys = [kTracksKey, kPlayableKey]
        asset.loadValuesAsynchronouslyForKeys(requestedKeys) { () -> Void in
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                for key in requestedKeys
                {
                    var error: NSError?
                    let status = asset.statusOfValueForKey(key, error: &error)
                    if status == AVKeyValueStatus.Failed
                    {
                        print("Failed to load \(key). Reason: \(error?.localizedDescription)")
                    }
                }
                
                var error: NSError?
                let status = asset.statusOfValueForKey(kTracksKey, error: &error)
                guard status == .Loaded else
                {
                    print("Failed to load \(kTracksKey). Reason: \(error?.localizedDescription)")
                    return
                }
                
                let pixelBufferAttributes = [
                    kCVPixelBufferPixelFormatTypeKey as String : NSNumber(unsignedInt: kCVPixelFormatType_32BGRA),
                    //                    kCVPixelBufferWidthKey as String : NSNumber(unsignedInt: 1024),
                    //                    kCVPixelBufferHeightKey as String : NSNumber(unsignedInt: 512),
                ]
                self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
                
                
                self.playerItem = AVPlayerItem(asset: asset)
                self.playerItem.addOutput(self.videoOutput)
                self.videoOutput.requestNotificationOfMediaDataChangeWithAdvanceInterval(ONE_FRAME_DURATION)
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidPlayToEndTime:", name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
                
                self.player = AVPlayer(playerItem: self.playerItem)
                
                self.seekToZeroBeforePlay = false
                self.playerItem.addObserver(self, forKeyPath: kStatusKey, options: [.Initial, .New], context: AVPlayerDemoPlaybackViewControllerStatusObservationContext)
                
                self.player.addObserver(self, forKeyPath: kCurrentItemKey, options: [.Initial, .New], context: AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext)
                
                self.player.addObserver(self, forKeyPath: kRateKey, options: [.Initial, .New], context: AVPlayerDemoPlaybackViewControllerRateObservationContext)
                
                
                self.initScrubberTimer()
                self.syncScrubber()
            })
        }
    }
    
    
    func currentFrame(frameHandler: ((size: CGSize, frameData: UnsafeMutablePointer<Void>) -> (Void))?)
    {
        guard self.playerItem?.status == .ReadyToPlay else
        {
            return
        }
        
        let currentTime = self.playerItem.currentTime()
        guard let pixelBuffer = self.videoOutput.copyPixelBufferForItemTime(currentTime, itemTimeForDisplay: nil) else
        {
            print("empty pixel buffer")
            return
        }
        self.activityIndicator.stopAnimating()
//        print("currentTime: \(currentTime.seconds)")
        
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly)
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        frameHandler?(size: CGSize(width: width, height: height), frameData: baseAddress)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly)
    }
    
    
    
    // MARK: - playButton
    func configurePlayButton() {
        self.playButton.backgroundColor = UIColor.clearColor()
        self.playButton.showsTouchWhenHighlighted = true
    
        self.disablePlayerButtons()
        self.updatePlayButton()
    }
    
    func enablePlayerButtons() {
        self.playButton.enabled = true
    }
    
    func disablePlayerButtons() {
        self.playButton.enabled = false
    }
    
    
    func isPlaying() -> Bool {
        print(self.player.rate)
        return self.mRestoreAfterScrubbingRate != 0.0 || self.player.rate != 0.0
    }
    
    @IBAction func playButtonTouched(sender: UIButton) {
        NSObject.cancelPreviousPerformRequestsWithTarget(self)
        if self.isPlaying() {
            self.pause()
        } else {
            self.play()
        }
    }
    
    func play() {
        if self.isPlaying() {
            return
        }
        if self.seekToZeroBeforePlay == true {
            self.seekToZeroBeforePlay = false
            self.player.seekToTime(kCMTimeZero)
        }
        
        
        self.player.play()
        self.updatePlayButton()
        self.scheduleHideControls()
    }
    
    func pause() {
        if !self.isPlaying() {
            return
        }
        
        self.player.pause()
        self.updatePlayButton()
        self.scheduleHideControls()
    }
    
    func updatePlayButton() {
        print(self.isPlaying())
        self.playButton.setImage(UIImage(named: self.isPlaying() ? "playback_pause": "playback_play"), forState: UIControlState.Normal)
    }
    
    func playerItemDidPlayToEndTime(notification: NSNotification)
    {
        self.seekToZeroBeforePlay = true
    }
    
    // MARK: - Key Value Observing
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        if context == AVPlayerDemoPlaybackViewControllerStatusObservationContext {
            
            if let status:Int = (change![NSKeyValueChangeNewKey]!.integerValue) {
                switch status {
                case AVPlayerStatus.Unknown.rawValue:
                    break
                case AVPlayerStatus.ReadyToPlay.rawValue:
                    print("Reached")
                    self.initScrubberTimer()
                    self.enableScrubber()
                    self.enablePlayerButtons()
                    self.play()
                    break
                case AVPlayerStatus.Failed.rawValue:
                    break
                default:
                    break
                }
            }
        } else if context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext {
            
        } else {
            
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            
        }
    }
    
    // MARK: - IBActions
    @IBAction func increaseSpeedButtonPressed(sender: UIButton) {
        if player.rate == 1 {
            player.rate = 2
        } else {
            player.rate = 1
        }
    }
    
    
    @IBAction func positionButtonTouched(sender: UIButton) {
        let camera = self.scene3DView.camera
        camera.yaw = 0
        camera.pitch = 0
        
    }
    
    
    
    @IBAction func filterButtonPressed(sender: UIButton) {
        print("filter pressed")
        
        
        filter.alpha = 0.2
        filter.backgroundColor = UIColor(patternImage: UIImage(named: "texture2")!)
        
        if filterApplied == false {
            self.view.insertSubview(filter, belowSubview: playerControlBackgroundView)
            self.filterApplied = true
        } else {
            self.filter.removeFromSuperview()
            self.filterApplied = false
        }
        
        
    }
    
    @IBAction func backButtonTouched(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - Event handlers
    func panGestureAction(sender: UIPanGestureRecognizer)
    {
        if (sender.state == .Changed)
        {
            let dt = CGFloat(self.timeSinceLastUpdate)
            let velocity = sender.velocityInView(sender.view)
            let translation = CGPoint(x: velocity.x * dt, y: velocity.y * dt)

            let camera = self.scene3DView.camera
            let scale = Float(UIScreen.mainScreen().scale)
            let dh = Float(translation.x / self.view.frame.size.width) * camera.fovRadians * scale
            let dv = Float(translation.y / self.view.frame.size.height) * camera.fovRadians * scale
            
            camera.yaw += dh
            camera.pitch += dv
            
        }
    }
    
    func handleSingleTapGesture(sender: UITapGestureRecognizer) {
        self.toggleControls()
    }
    
    
    
    // MARK: - Animations
    
    func scheduleHideControls() {
        if(!self.playerControlBackgroundView.hidden) {
            NSObject.cancelPreviousPerformRequestsWithTarget(self)
            self.performSelector(#selector(Scene3DViewController.hideControlsSlowly), withObject: nil, afterDelay: HIDE_CONTROL_DELAY)
        }
    }
    
    func hideControlsWithDuration(duration: NSTimeInterval) {
        self.playerControlBackgroundView.alpha = CGFloat(DEFAULT_VIEW_ALPHA)
        UIView.animateWithDuration(duration, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: {
                self.playerControlBackgroundView.alpha = 0.0
            }) { (finished) in
                if finished {
                    self.playerControlBackgroundView.hidden = true
                }
        }
    }
    
    func hideControlsFast() {
        self.hideControlsWithDuration(0.2)
    }
    
    func hideControlsSlowly() {
        self.hideControlsWithDuration(1.0)
    }
    
    func toggleControls() {
        if self.playerControlBackgroundView.hidden {
            self.showControlsFast()
        } else {
            self.hideControlsFast()
        }
        self.scheduleHideControls()
    }
    
    
    
    // MARK: - progressSlider
    func configureProgressSlider() {
        self.progressSlider.continuous = false
        self.progressSlider.value = 0
        
        self.progressSlider.setThumbImage(UIImage(named: "thumb.png"), forState: UIControlState.Normal)
        self.progressSlider.setThumbImage(UIImage(named: "thumb.png"), forState: UIControlState.Highlighted)
    }
    
    @IBAction func scrub(sender: UISlider) {
        let slider = sender
        let playerDuration = self.playerItemDuration()
        
        if playerDuration == kCMTimeInvalid {
            return
        }
        let duration = CMTimeGetSeconds(playerDuration)
        if isfinite(duration) {
            let minValue = Double(slider.minimumValue)
            let maxValue = Double(slider.maximumValue)
            let value = Double(slider.value)
            let time: Double = duration * (value - minValue) / (maxValue - minValue)
            
            self.player.seekToTime(CMTimeMakeWithSeconds(time, Int32(NSEC_PER_SEC)))
            
            self.updatePlayButton()
        }
        
    }
    
    
    
    @IBAction func beingScrubbing(sender: UISlider) {
        self.mRestoreAfterScrubbingRate = self.player.rate
        let syncTime = CMClockGetHostTimeClock();
        let hostTime = CMClockGetTime(syncTime)
        self.player.setRate(0.0, time: kCMTimeInvalid, atHostTime: hostTime)
        self.removePlayerTimeObserver()
        self.updatePlayButton()
    }
    
    
    
    
    @IBAction func endScrubbing(sender: UISlider) {
        if (self.timeObserver != nil) {
            let playerDuration = self.playerItemDuration()
            
            if playerDuration == kCMTimeInvalid {
                return
            }
            let duration = CMTimeGetSeconds(playerDuration)
            if isfinite(duration) {
                let width = Double(CGRectGetWidth(self.progressSlider.bounds))
                let tolerance = 0.5 * duration / width
                
                let weakSelf: Scene3DViewController = self
                self.timeObserver = self.player.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(tolerance, Int32(NSEC_PER_SEC)), queue: nil, usingBlock: { (time) in
                    weakSelf.syncScrubber()
                    self.updatePlayButton()
                })
                
            }
        }
    }
    
    
    func syncScrubber() {
        let playerDuration = self.playerItemDuration()
        
        if playerDuration == kCMTimeInvalid {
            self.progressSlider.minimumValue = 0.0
            return
        }
        
        let duration = CMTimeGetSeconds(playerDuration)
        if isfinite(duration) {
            
            let minValue = Double(self.progressSlider.minimumValue)
            let maxValue = Double(self.progressSlider.maximumValue)
            let time: Double = CMTimeGetSeconds(self.player.currentTime())
            
            let value = (maxValue - minValue) * time / duration + minValue
            self.progressSlider.setValue(Float(value), animated: false)
            self.updatePlayButton()
            
        }


    }
    
    
    func isScrubbing()-> Bool {
        return self.mRestoreAfterScrubbingRate != 0.0
    }
    
    func enableScrubber() {
        self.progressSlider.enabled = true
    }
    
    func disableScrubber() {
        self.progressSlider.enabled = false
    }
    
    

    func initScrubberTimer() {
        var interval = 0.1
        let playerDuration = self.playerItemDuration()
        if playerDuration == kCMTimeInvalid {
            
            return
        }
        let duration = CMTimeGetSeconds(playerDuration)
        if isfinite(duration) {
            let width = Double(CGRectGetWidth(self.progressSlider.bounds))
            interval = 0.5 * duration / width
        }
        
        let weakSelf: Scene3DViewController = self
        self.timeObserver = self.player.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(interval, Int32(NSEC_PER_SEC)), queue: nil, usingBlock: { (time) in
            weakSelf.syncScrubber()
            self.updatePlayButton()
        })
        
    }
    
    func showControlsFast() {
        self.playerControlBackgroundView.alpha = 0.0
        self.playerControlBackgroundView.hidden = false
        UIView.animateWithDuration(0.2, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: {
            self.playerControlBackgroundView.alpha = CGFloat(DEFAULT_VIEW_ALPHA)
            }, completion: nil)
    }
    
    func playerItemDuration()-> CMTime {
        if self.playerItem.status == AVPlayerItemStatus.ReadyToPlay {
            return self.playerItem.duration
        }
        return kCMTimeInvalid
    }
    
    
    func removePlayerTimeObserver() {
        if (self.timeObserver != nil) {
            self.player.removeTimeObserver(self.timeObserver)
            self.timeObserver = nil
        }
    }
    
    
    
    
}

