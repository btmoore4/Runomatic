//
//  ViewController.swift
//  runomatic
//
//  Created by Vasil Pendavinji on 2/1/16.
//  Copyright © 2016 Vasil Pendavinji. All rights reserved.
//
import Foundation
import UIKit
import CoreMotion
import AVFoundation
import GPUImage
import SocketIOClientSwift

var motionManager: CMMotionManager!


class ViewController: UIViewController {
    let pi = M_PI
    let accel_scale = 9.81
    let socket = SocketIOClient(socketURL: NSURL(string: "http://192.168.0.113:3000")!, options: ["log": true])
    
    let captureSession = AVCaptureSession()
    var captureDevice : AVCaptureDevice?
    var stillImageOutput : AVCaptureStillImageOutput? = AVCaptureStillImageOutput()

    var gpuImgCamera:GPUImageVideoCamera = GPUImageVideoCamera(sessionPreset: AVCaptureSessionPreset640x480, cameraPosition: AVCaptureDevicePosition.Front)
    var gpuImgLumFilter:GPUImageLuminosity = GPUImageLuminosity()

    @IBOutlet var time:UILabel!
    @IBOutlet var xal:UILabel!
    @IBOutlet var yal:UILabel!
    @IBOutlet var zal:UILabel!
    @IBOutlet var xrl:UILabel!
    @IBOutlet var yrl:UILabel!
    @IBOutlet var zrl:UILabel!
    @IBOutlet var xml:UILabel!
    @IBOutlet var yml:UILabel!
    @IBOutlet var zml:UILabel!
    @IBOutlet var luml:UILabel!

    
    var img:UIImage = UIImage()
    
    
    var startTime:NSDate = NSDate()
    var elapsedTime:NSTimeInterval = 0.0
    var xa:Double = 0,ya:Double = 0,za:Double = 0
    var xr:Double = 0,yr:Double = 0,zr:Double = 0
    var xm:Double = 0,ym:Double = 0,zm:Double = 0
    var lum:Double = 0

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addHandlers()
        //self.socket.connect()
        //sendReadings()
        /*

        let devices = AVCaptureDevice.devices()

        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == AVCaptureDevicePosition.Front) {
                    captureDevice = device as? AVCaptureDevice
                }
            }
        }
        
        stillImageOutput!.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
        
        if captureDevice != nil {
            configureDevice()
            beginSession()
        }
        */
        
        if gpuImgCamera.inputCamera != nil {
        }
        configureDevice()


       
        gpuImgCamera.startCameraCapture()
        gpuImgCamera.addTarget(gpuImgLumFilter)
        gpuImgLumFilter.luminosityProcessingFinishedBlock = {
            (luminosity : CGFloat, frameTime: CMTime) in
            self.lum = Double(luminosity)
            
        }
        
        print("exposure duration",  gpuImgCamera.inputCamera.exposureDuration, " ISO: ", gpuImgCamera.inputCamera.ISO)

        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()

        _ = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: Selector("getReadings"), userInfo: nil, repeats: true)
/*
        _ = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("sendReadings"), userInfo: nil, repeats: true)
        _ = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("writeReadings"), userInfo: nil, repeats: true)
        _ = NSTimer.scheduledTimerWithTimeInterval(5.0, target: self, selector: Selector("readFromFile"), userInfo: nil, repeats: true)
*/
       // _ = NSTimer.scheduledTimerWithTimeInterval(0.016666667, target: self, selector: Selector("captureImage"), userInfo: nil, repeats: true)
        
        startTime = NSDate()
        time.text = "hi ben"
        self.xal.text = "x"
        self.yal.text = "y"
        self.zal.text = "z"
        
        
        
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func beginSession() {

        do{
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
        }
        catch {
            print("error capturing video")
        }
        captureSession.sessionPreset = AVCaptureSessionPreset640x480
        captureSession.startRunning()
        captureSession.addOutput(stillImageOutput)
    }
    
    func configureDevice() {
        do{
            try gpuImgCamera.inputCamera.lockForConfiguration()
        }
        catch{
            print("couldn't lock for config")
        }
        
        gpuImgCamera.inputCamera.exposureMode = .Custom
        gpuImgCamera.inputCamera.whiteBalanceMode = .Locked
        gpuImgCamera.inputCamera.setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains(AVCaptureWhiteBalanceGains(redGain: 1 , greenGain: 1, blueGain: 1), completionHandler:  {(tm:CMTime) in print("locked white balance set")})
        gpuImgCamera.inputCamera.setExposureModeCustomWithDuration(CMTime(value: 8333000, timescale: 1000000000), ISO: 34.0, completionHandler: {(tm:CMTime) in print("custom exposure set")})
        gpuImgCamera.inputCamera.unlockForConfiguration()
        
    }
    
    func captureImage(){
        if let stillOutput = self.stillImageOutput {
            // we do this on another thread so that we don't hang the UI
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                //find the video connection
                if let videoConnection = stillOutput.connectionWithMediaType(AVMediaTypeVideo){
                    //take a photo here
                    stillOutput.captureStillImageAsynchronouslyFromConnection(videoConnection){
                        (imageSampleBuffer : CMSampleBuffer!, _) in
                        if(imageSampleBuffer != nil){
                            let imageDataJpeg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
                            self.img = UIImage(data: imageDataJpeg)!
                        }
                    }
                    //self.captureSession.stopRunning()
                }
            }
        }
    }
    
    func addHandlers() {
        // Our socket handlers go here
        self.socket.onAny {print("Got event: \($0.event), with items: \($0.items)")}

    }
    
    func sendReadings(){
        self.socket.emit("accel", self.xa, self.ya, self.za)
        self.socket.emit("gyro", self.xr, self.yr, self.zr)
        self.socket.emit("mag", self.xm, self.ym, self.zm)
        
    }
    
    func getReadings(){
        
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            if let accelerometerData = motionManager.accelerometerData {
                self.xa = accelerometerData.acceleration.x * self.accel_scale
                self.ya = accelerometerData.acceleration.y * self.accel_scale
                self.za = accelerometerData.acceleration.z * self.accel_scale
                self.elapsedTime = NSDate().timeIntervalSinceDate(self.startTime)

            }
            if let gyroData = motionManager.gyroData {
                self.xr = gyroData.rotationRate.x*180/self.pi
                self.yr = gyroData.rotationRate.y*180/self.pi
                self.zr = gyroData.rotationRate.z*180/self.pi
                
            }
            if let magData = motionManager.magnetometerData {
                self.xm = magData.magneticField.x
                self.ym = magData.magneticField.y
                self.zm = magData.magneticField.z
                
            }
            dispatch_async(dispatch_get_main_queue()) {
                //update accelerometer labels
                self.xal.text = String(format: "%.2f", self.xa)
                self.yal.text = String(format: "%.2f", self.ya)
                self.zal.text = String(format: "%.2f", self.za)
                //update gyro labels
                self.xrl.text = String(format: "%.2f", self.xr)
                self.yrl.text = String(format: "%.2f", self.yr)
                self.zrl.text = String(format: "%.2f", self.zr)
                //update mag labels
                self.xml.text = String(format: "%.2f", self.xm)
                self.yml.text = String(format: "%.2f", self.ym)
                self.zml.text = String(format: "%.2f", self.zm)

                self.time.text = String(self.elapsedTime)
                
                self.luml.text = String(self.lum)
            }
        }

    }
    
    func writeReadings(){
        self.writeToFile("X_accel.asc")

    }
    
    func writeToFile(file: String){
        let text =  self.xal.text! + ", "
        
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(file);
            if let outputStream = NSOutputStream(toFileAtPath: path, append: true) {
                outputStream.open()
                outputStream.write(text, maxLength: text.characters.count)
                outputStream.close()
            } else {
                print("Write to file failed")
            }
            
        }
            
    }
    
    func readFromFile(){
        let file = "X_accel.asc"
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(file);
            
            do {
                let read = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
              //  print(read)
              //  print("Done")
            }
            catch {print("Read from file failed")}
            
        }
        
    }
    

}

