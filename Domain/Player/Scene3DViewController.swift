//
//  Scene3DViewController.swift
//  Spherical Video Player
//
//  Created by Pawel Leszkiewicz on 18.01.2016.
//  Copyright © 2016 Nomtek. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.


import GLKit
import CoreMotion

let DEFAULT_OVERTURE = 85.0
let  ES_PI  = 3.14159265
let SphereScale = 300
let ROLL_CORRECTION = ES_PI/2.0

class Scene3DViewController: GLKViewController, GLKViewControllerDelegate
{
    @IBOutlet private weak var scene3DView: Scene3DView!
    private var context: EAGLContext!
    private var skysphere: Skysphere!
    private var videoReader: VideoReader!
    var isUsingMotion: Bool!
    var savedGyroRotationX: Float!
    var savedGyroRotationY: Float!
    var motionManager: CMMotionManager!
    var referenceAttitude: CMAttitude!
    var overture: Double!
    var fingerRotationX: Float = 0.0
    var fingerRotationY: Float = 0.0
    let newView = UIView(frame: CGRect(x: 10, y: 10, width: 40, height: 40))

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
        
        super.viewDidLoad()
        
        
        self.overture = DEFAULT_OVERTURE
//        glkViewControllerUpdate(self)
        
        self.configureContext()
        self.configureView()
        self.configureVideoReader()
        self.startDeviceMotion()
        
    }

    // This is one of update variants used by GLKViewController.
    // See comment to GLKViewControllerDelegate.glkViewControllerUpdate for more info.
    func update()
    {
        self.videoReader?.currentFrame(
        {
            [weak self] (size, frameData) -> (Void) in
            self?.skysphere.updateTexture(size, imageData: frameData)
        })
        glkViewControllerUpdate(self)
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
        
        newView.backgroundColor = UIColor.whiteColor()
        self.view.addSubview(newView)

        // Pan gesture recognizer
        let panGesture = UIPanGestureRecognizer(target: self, action: "panGestureAction:")
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        self.view.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: "handleSingleTapGesture:")
        self.view.addGestureRecognizer(tapGesture)
    }

    private func configureVideoReader()
    {
//        if let url = NSBundle.mainBundle().URLForResource("videoplayback", withExtension: "mp4")
//        {
//            self.videoReader = VideoReader(url: url)
//        }
        if let url = NSURL(string: "https://mettavr.s3.amazonaws.com/videos/ceci.mourkogiannis.fphw42u8kvyyhqymq/converted/720/0apmZMmbyT.scale-720.fps-20.ZOGael5U9n.mp4")
        {
            self.videoReader = VideoReader(url: url)
        }
    }
    
    
    func glkViewControllerUpdate(controller: GLKViewController) {
        
        print("Reached")
        
        let aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height)
        var projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(Float(self.overture)), Float(aspect), 0.1, 400.0)
        projectionMatrix = GLKMatrix4Rotate(projectionMatrix, Float(ES_PI), 1.0, 0.0, 0.0)
        
        var modelViewMatrix = GLKMatrix4Identity
        let scale = Float(SphereScale)
        modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, scale, scale, scale)
        
        if(self.isUsingMotion == true) {
            if let deviceMotion: CMDeviceMotion = self.motionManager.deviceMotion {
                let attitude: CMAttitude = deviceMotion.attitude
                
                if (self.referenceAttitude != nil) {
                    attitude.multiplyByInverseOfAttitude(self.referenceAttitude)
                } else {
                    //NSLog(@"was nil : set new attitude", nil);
                    self.referenceAttitude = deviceMotion.attitude
                }
                
                let cRoll = Float(-fabs(attitude.roll)) // Up/Down landscape
                let cYaw = Float(attitude.yaw)  // Left/ Right landscape
                var cPitch = Float(attitude.pitch) // Depth landscape
                
                print("Reached")
                
                let orientation = UIDevice.currentDevice().orientation
                if (orientation == UIDeviceOrientation.LandscapeRight ){
                    cPitch = cPitch * -1; // correct depth when in landscape right
                }
                
                modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, cRoll); // Up/Down axis
                modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, cPitch);
                modelViewMatrix = GLKMatrix4RotateZ(modelViewMatrix, cYaw);
                
                modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, Float(ROLL_CORRECTION));
                
                modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, self.fingerRotationX);
                modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, self.fingerRotationY);
                
                self.savedGyroRotationX = cRoll  + self.fingerRotationX
                self.savedGyroRotationY = cPitch + self.fingerRotationY
                
                let camera = self.scene3DView.camera
                camera.updateMotion(cRoll, cPitch: cPitch, cYaw: cYaw)
            }
        } else {
            modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, self.fingerRotationX)
            modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, self.fingerRotationY)
        }
        
//        self.modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
//        
//        glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, GL_FALSE, self.modelViewProjectionMatrix.m);
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
            print(dh)
            camera.yaw += dh
            camera.pitch += dv
            
        }
    }
    
    func handleSingleTapGesture(sender: UITapGestureRecognizer) {
        if self.newView.hidden == true {
            self.newView.hidden = false
        } else {
            self.newView.hidden = true
        }
    }
    
    
    
    func startDeviceMotion() {
    
    self.isUsingMotion = false
    
    self.motionManager = CMMotionManager()
    self.referenceAttitude = nil
    self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
    self.motionManager.gyroUpdateInterval = 1.0 / 60
    self.motionManager.showsDeviceMovementDisplay = true
    
    self.motionManager.startDeviceMotionUpdatesUsingReferenceFrame(CMAttitudeReferenceFrame.XArbitraryCorrectedZVertical)
    
    if self.motionManager.deviceMotion != nil {
        self.referenceAttitude = self.motionManager.deviceMotion!.attitude
    }// Maybe nil actually. reset it later when we have data
    
    self.savedGyroRotationX = 0
    self.savedGyroRotationY = 0
    
    self.isUsingMotion = true
    }
}

