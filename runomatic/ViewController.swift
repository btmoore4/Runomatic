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
var motionManager: CMMotionManager!


class ViewController: UIViewController {
    let pi = M_PI
    let accel_scale = 9.81
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
    
    var startTime:NSDate = NSDate()
    var elapsedTime:NSTimeInterval = 0.0
    var xa:Double = 0,ya:Double = 0,za:Double = 0
    var xr:Double = 0,yr:Double = 0,zr:Double = 0
    var xm:Double = 0,ym:Double = 0,zm:Double = 0

    
    override func viewDidLoad() {
        super.viewDidLoad()
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        motionManager.startGyroUpdates()
        motionManager.startMagnetometerUpdates()

        _ = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("getReadings"), userInfo: nil, repeats: true)
        _ = NSTimer.scheduledTimerWithTimeInterval(5.0, target: self, selector: Selector("readFromFile"), userInfo: nil, repeats: true)
        
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
                self.writeToFile("X_accel.asc")
            }
        }

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
                print(read)
                print("Done")
            }
            catch {print("Read from file failed")}
            
        }
        
    }
    

}

