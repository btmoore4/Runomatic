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
import MessageUI
var motionManager: CMMotionManager!


class ViewController: UIViewController, MFMailComposeViewControllerDelegate{
    let pi = M_PI
    let accel_scale = 9.81
    let socket = SocketIOClient(socketURL: NSURL(string: "http://192.168.0.113:3000")!, options: ["log": true])
    let altimeter = CMAltimeter()

    
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
    @IBOutlet var stepl:UILabel!
    @IBOutlet var activity:UILabel!
    @IBOutlet var altl:UILabel!
    @IBOutlet var Button: UIButton!
    
    var startTime:NSDate = NSDate()
    var elapsedTime:NSTimeInterval = 0.0
    var xa:Double = 0,ya:Double = 0,za:Double = 0
    var xr:Double = 0,yr:Double = 0,zr:Double = 0
    var xm:Double = 0,ym:Double = 0,zm:Double = 0
    var lum:Double = 0
    var alt:Double = 0
    
    var pathX:String = "";
    var mess:String = "";
    var start:Bool = false;
    enum State {
        case idle, walking, running, jumping, stairs
    }
    var state:State = State.idle
    let Xn = 0, Yn = 0, Zn = -9.81
    var steps = 0
    var relativeAltitude = 0.0
    let idleTol = 1.0
    let walkTol = 1.0
    let runTol = 5.5
    let jumpTol = 10.0
    
    let timeout = -1.2
    let timeout2 = -1.5
    var waitFlag = true
    
    let stepTol = 1.5
    let stepRunTol = 4.0
    enum GraphState {
        case above, below, zero
    }
    var Zstate:GraphState = GraphState.above
    var ZCrossings = [NSDate]()
    var lastStep = NSDate()
    
    


    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addHandlers()
        //self.socket.connect()
        //sendReadings()
        
        configureDevice()
        
        gpuImgCamera.startCameraCapture()
        gpuImgCamera.addTarget(gpuImgLumFilter)
        gpuImgLumFilter.luminosityProcessingFinishedBlock = {
            (luminosity : CGFloat, frameTime: CMTime) in
            self.lum = Double(luminosity)
            
        }
        // 1
        if CMAltimeter.isRelativeAltitudeAvailable() {
            // 2
            altimeter.startRelativeAltitudeUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { data, error in
                // 3

                    print("Relative Altitude: \(data!.relativeAltitude)")
                    print("Pressure: \(data!.pressure)")
                    self.relativeAltitude = Double(data!.relativeAltitude)
            })
        }
        print("exposure duration",  gpuImgCamera.inputCamera.exposureDuration, " ISO: ", gpuImgCamera.inputCamera.ISO)
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()


        _ = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: Selector("getReadings"), userInfo: nil, repeats: true)
        _ = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: Selector("writeReadings"), userInfo: nil, repeats: true)

        
        /*
        _ = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("sendReadings"), userInfo: nil, repeats: true)
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
    
    func addHandlers() {
        // Our socket handlers go here
        self.socket.onAny {print("Got event: \($0.event), with items: \($0.items)")}
        
    }
    
    func decider(){
        switch state {
        case .idle:
            if (za > Zn + walkTol){
                state = .walking
                waitFlag = true
                lastStep = NSDate()
            }
            break
        case .walking:
            if (za < Zn + idleTol){
                if (lastStep.timeIntervalSinceNow < timeout){
                    state = .idle
                    waitFlag = true
                }
            }else if(za > Zn + runTol){
                state = .running
                waitFlag = true
            }else{
                lastStep = NSDate()
            }
            break
        case .running:
            if (za < Zn + idleTol){
                if (lastStep.timeIntervalSinceNow < timeout){
                    state = .idle
                    waitFlag = true
                }
            }else if(za < Zn + runTol){
                if (lastStep.timeIntervalSinceNow < timeout){
                    state = .walking
                    waitFlag = true
                }
            }else if(za > Zn + jumpTol){
                state = .jumping
                waitFlag = false
            }else{
                lastStep = NSDate()
            }
            break
        case .jumping:
            if (za < Zn + idleTol){
                if (lastStep.timeIntervalSinceNow < timeout2){
                    state = .idle
                    waitFlag = true
                }
            }else if(za < Zn + jumpTol){
                if (lastStep.timeIntervalSinceNow < timeout2){
                    state = .running
                    waitFlag = true
                }
            }else if(za < Zn + runTol){
                if (lastStep.timeIntervalSinceNow < timeout2){
                    state = .walking
                    waitFlag = true
                }
            }else{
                lastStep = NSDate()
            }
            break
        case .stairs: break
        default: break
        }
    }
    
    func countSteps(){
        if (state == .running){
            if ((Zstate == .above) && (za < (Zn - stepRunTol))){
                Zstate = .below
            }
            if ((Zstate == .below) && (za > (Zn + stepRunTol))){
                Zstate = .above
                steps++
                waitFlag = false
            }
        }else{
        if ((Zstate == .above) && (za < (Zn - stepTol))){
            Zstate = .below
        }
        if ((Zstate == .below) && (za > (Zn + stepTol))){
            Zstate = .above
            steps++
        }
        }
        
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
                self.countSteps()
                self.decider()
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
                
                self.stepl.text = String(self.steps)
                self.activity.text = String(self.state)
                self.altl.text = String(self.relativeAltitude)
            }
        }
        
    }
    
    func writeReadings(){
        if (start){
            print("writing file")
            self.writeToFile("./readings.csv")
        }
    }
    
    func writeToFile(file: String){
        mess =  self.time.text! + ", " + self.xal.text! + ", " + self.yal.text! + ", " + self.zal.text! + ", " + self.xrl.text! + ", " + self.yrl.text! + ", " + self.zrl.text! + ", " + self.xml.text! + ", " + self.yml.text! + ", " + self.zml.text! + ", " + "\n"
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(file);
            pathX = path;
            if let outputStream = NSOutputStream(toFileAtPath: path, append: true) {
                outputStream.open()
                outputStream.write(mess, maxLength: mess.characters.count)
                outputStream.close()
            } else {
                print("Write to file failed")
            }
            
        }
        
    }
    
    func readFromFile(){
        let file = "data.asc"
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(file);
            
            do {
                let read = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            }
            catch {print("Read from file failed")}
        }
    }

    
    @IBAction func sendEmail(sender: UIButton) {
        if (!start){
            start = true
            startTime = NSDate()
        }else{
            start = false
        if( MFMailComposeViewController.canSendMail() ) {
            print("Able to send")
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            mailComposer.setSubject("Booty")
            mailComposer.setMessageBody("YAY", isHTML: false)

            if let fileData = NSData(contentsOfFile: pathX) {
                print("File data loaded.")
                mailComposer.addAttachmentData(fileData, mimeType: "text/csv", fileName: "data.csv")
            }else{
                print("File data is NOT loaded.")
            }
            let fileManager = NSFileManager.defaultManager()
            do {
                try fileManager.removeItemAtPath(pathX)
                print("Deleted")
            }
            catch let error as NSError {
                print("Ooops")
            }
            self.presentViewController(mailComposer, animated: true, completion: nil)
        }
        }
    }
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }


}

