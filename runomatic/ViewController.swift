//
//  ViewController.swift
//  runomatic
//
//  Created by Vasil Pendavinji on 2/1/16.
//  Copyright © 2016 Vasil Pendavinji. All rights reserved.
//

import UIKit
import CoreMotion
import Foundation
import SocketIOClientSwift
import MessageUI
var motionManager: CMMotionManager!


class ViewController: UIViewController, MFMailComposeViewControllerDelegate{
    let pi = M_PI
    let accel_scale = 9.81
    let socket = SocketIOClient(socketURL: NSURL(string: "http://172.17.126.37:3000")!, options: ["log": true])

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
    @IBOutlet var Button: UIButton!
    
    var startTime:NSDate = NSDate()
    var elapsedTime:NSTimeInterval = 0.0
    var xa:Double = 0,ya:Double = 0,za:Double = 0
    var xr:Double = 0,yr:Double = 0,zr:Double = 0
    var xm:Double = 0,ym:Double = 0,zm:Double = 0
    
    var pathX:String = "";
    var mess:String = "";
    
    var start:Bool = false;

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addHandlers()
        //self.socket.connect()
        //sendReadings()
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()

        _ = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: Selector("getReadings"), userInfo: nil, repeats: true)
        //_ = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: Selector("sendReadings"), userInfo: nil, repeats: true)
        _ = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: Selector("writeReadings"), userInfo: nil, repeats: true)
        
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
            }
        }

    }
    
    func writeReadings(){
        if (start){
            self.writeToFile("data.asc")
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

