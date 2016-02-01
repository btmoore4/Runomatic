//
//  ViewController.swift
//  runomatic
//
//  Created by Vasil Pendavinji on 2/1/16.
//  Copyright © 2016 Vasil Pendavinji. All rights reserved.
//

import UIKit
import CoreMotion
var motionManager: CMMotionManager!


class ViewController: UIViewController {
    @IBOutlet var time:UILabel!
    @IBOutlet var xaccl:UILabel!
    @IBOutlet var yaccl:UILabel!
    @IBOutlet var zaccl:UILabel!
    var xa:Double = 0,ya:Double = 0,za:Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
    //    var helloWorldTimer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: Selector("getAccel"), userInfo: nil, repeats: true)

        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
        if let accelerometerData = motionManager.accelerometerData {
            self.xa = accelerometerData.acceleration.x
            self.ya = accelerometerData.acceleration.y
            self.za = accelerometerData.acceleration.z
            
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.xaccl.text = String(self.xa)
            self.yaccl.text = String(self.ya)
            self.zaccl.text = String(self.za)
        }
        }

        time.text = "hi ben"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getaccel(){
            }

}

