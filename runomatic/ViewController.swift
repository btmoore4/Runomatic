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
    let Xn = 0.0, Yn = 0.0, Zn = -9.81
    var steps = 0
    var relativeAltitude = 0.0
    let idleTol = 1.0
    let walkTol = 1.0
    let runTol = 6.0
    let jumpTol = 9.0
    let stairTol = 2.0
    
    let timeout = -1.2
    let timeout2 = -1.5
    
    let stepTol = 1.3
    let stepRunTol = 4.0
    enum GraphState {
        case above, below, zero
    }
    var Zstate:GraphState = GraphState.above
    var ZCrossings = [NSDate]()
    var lastStep = NSDate()
    
    var paths = [String]()
    var names = [String]()
    var times = [NSDate]()
    var dists = [Double]()
    var fileNum = 0
    
    let runDist = 40.0
    let walkDist = 20.0
    


    
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
                steps = 0
                lastStep = NSDate()
                paths.append(pathX)
                names.append("Idle")
                fileNum++
                times.append(NSDate())
                dists.append(0)
            }
            break
        case .walking:
            if (za < Zn + idleTol){
                if (lastStep.timeIntervalSinceNow < timeout){
                    state = .idle
                    paths.append(pathX)
                    names.append("Walking")
                    fileNum++
                    times.append(NSDate())
                    dists.append(Double(steps)*walkDist)
                }
            }else if(za > Zn + runTol){
                state = .running
                paths.append(pathX)
                names.append("Walking")
                fileNum++
                times.append(NSDate())
                dists.append(Double(steps)*walkDist)
                steps = 1
            }else if(ya > Yn + stairTol){
                state = .stairs
                paths.append(pathX)
                names.append("Walking")
                fileNum++
                times.append(NSDate())
                dists.append(Double(steps)*walkDist)
                steps = 1
            }else{
                lastStep = NSDate()
            }
            break
        case .running:
            if (za < Zn + idleTol){
                if (lastStep.timeIntervalSinceNow < timeout){
                    state = .idle
                    paths.append(pathX)
                    names.append("Running")
                    fileNum++
                    times.append(NSDate())
                    dists.append(Double(steps)*runDist)
                }
            }else if(za < Zn + runTol){
                if (lastStep.timeIntervalSinceNow < timeout){
                    state = .walking
                    paths.append(pathX)
                    names.append("Running")
                    fileNum++
                    times.append(NSDate())
                    dists.append(Double(steps)*runDist)
                    steps = 0
                }
            }else if(za > Zn + jumpTol){
                state = .jumping
                paths.append(pathX)
                names.append("Running")
                fileNum++
                times.append(NSDate())
                dists.append(Double(steps)*runDist)
            }else{
                lastStep = NSDate()
            }
            break
        case .jumping:
            if (za < Zn + idleTol){
                if (lastStep.timeIntervalSinceNow < timeout2){
                    state = .idle
                    paths.append(pathX)
                    names.append("Jumping")
                    fileNum++
                    times.append(NSDate())
                    dists.append(0)
                }
            }else if(za < Zn + jumpTol){
                if (lastStep.timeIntervalSinceNow < timeout2){
                    state = .running
                    steps = 1
                    paths.append(pathX)
                    names.append("Jumping")
                    fileNum++
                    times.append(NSDate())
                    dists.append(0)
                }
            }else if(za < Zn + runTol){
                if (lastStep.timeIntervalSinceNow < timeout2){
                    state = .walking
                    steps = 0
                    paths.append(pathX)
                    names.append("Jumping")
                    fileNum++
                    times.append(NSDate())
                    dists.append(0)
                }
            }else{
                lastStep = NSDate()
            }
            break
        case .stairs:
            steps = 0
            if (za < Zn + idleTol){
                if (lastStep.timeIntervalSinceNow < timeout){
                    state = .idle
                    paths.append(pathX)
                    names.append("Stairs")
                    fileNum++
                    times.append(NSDate())
                    dists.append(Double(steps)*walkDist)
                }
            }else if(za > Zn + jumpTol){
                state = .jumping
                paths.append(pathX)
                names.append("Stairs")
                fileNum++
                times.append(NSDate())
                dists.append(Double(steps)*walkDist)
            }else if(za > Zn + runTol){
                state = .running
                paths.append(pathX)
                names.append("Stairs")
                fileNum++
                times.append(NSDate())
                dists.append(Double(steps)*walkDist)
                steps = 1
            }else if(ya < Yn + stairTol){
                state = .walking
                paths.append(pathX)
                names.append("Stairs")
                fileNum++
                times.append(NSDate())
                dists.append(Double(steps)*walkDist)
                steps = 1
            }else{
                lastStep = NSDate()
            }
            break
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
            //self.writeToFile("./readings.csv")
            self.writeToFile(String(fileNum)+".csv")
        }
    }
    
    func fileNamer(index: Int) -> String{
        let formatter = NSDateFormatter()
        formatter.dateFormat = "dd-MM-yy HH:mm:ss"
        return String(format:"%@_%@_%@cm.csv",names[index],formatter.stringFromDate(times[index]),String(dists[index]))
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
            paths = [String]()
            names = [String]()
            times = [NSDate]()
            dists = [Double]()
            times.append(NSDate())
        }else{
            start = false
        if( MFMailComposeViewController.canSendMail() ) {
            print("Able to send")
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            mailComposer.setSubject("Booty")
            mailComposer.setMessageBody("YAY", isHTML: false)
            let fileManager = NSFileManager.defaultManager()
            for var index = 0; index < paths.count; ++index {
            
                if let fileData = NSData(contentsOfFile: paths[index]) {
                    print("File data loaded.")
                    mailComposer.addAttachmentData(fileData, mimeType: "text/csv", fileName: fileNamer(index))
                    do {
                        try fileManager.removeItemAtPath(paths[index])
                        print("Deleted")
                    }
                    catch let error as NSError {
                        print("Ooops")
                    }
                }else{
                    print("File data is NOT loaded.")
                }
            }

            
            self.presentViewController(mailComposer, animated: true, completion: nil)
        }
        }
    }
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }


}

