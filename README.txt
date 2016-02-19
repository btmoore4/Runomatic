Programming Assignment 1: Exploring Multi-Modal Sensing on Smartphones

Names/netid
Ben Moore		btmoore4
Vasil Pendavinji 	pendavi2

Stage 1: 
For this project, we built an iOS app written in Swift. To achieve collecting all the sensor readings, we used the "CoreMotion" framework in iOS that allows our application to receive data from the phone's hardware. The one exception to this, was that to get the 'light intensity' data, we had to use the "GPUImage" framework. Because in iOS, we cannot directly access the ambient light sensor, we had to use "GPUImage" to compute luminosity from the front facing camera in real time. We found that with default camera settings, the camera auto-adjusts exposure. Because of this, the luminosity of the video feed is .5 on average. We set the camera’s exposure and white balance manually to get around this.
We then simply displayed the sensor data using UILabels and a scheduled timer called our "getReadings" function at a frequency of 100 Hz. 

Stage 2: 
To accomplish the differentiation of the activities, we used a variety of techniques. First to distinguish between idle, walking, running, and jumping, we used a combination of checking for set ranges in the Z and Y acceleration data and monitoring the frequency of the Z accel data, mostly to differentiate the slower frequency of jumping. We had the most trouble differentiating the walking and stairs activity, which we fixed by additional checking of the phone's barometer to see if altitude had changed. 
To write and retrieve the files, we wrote to an additional .csv file every time the activity changed, and then used the MessageUI framework to attach all the files to an email, which we could send to our computers. 

Stage 3: 
For the step algorithm, we actually first did some research like reading this article (http://www.enggjournals.com/ijcse/doc/IJCSE12-04-05-266.pdf), which talked about how a step starts with the foot pushing back on the ground, which is opposed by friction and leads to an initial spike in the negative Z accel direction. This is followed by the foot pushing forward on the floor to complete the step, which is seen as a spike in the positive Z accel direction. We used this information to count the number of full 'spike' cycles to determine the amount of steps. 

Stage 4: We graphed a number of different metrics and decide that the 3 most useful in separating out the various activities were the mean Z acceleration, mean Y acceleration, and maximum Z acceleration. For the mean Z acceleration and mean Y acceleration, we shifted the data by subtracting the average so the data centered around 0, and we also took the absolute value to avoid skewing the average. Walking, running, and jumping each had very different readings for Z mean and Z max especially, so those two metrics were what we used most when designing our decision algorithm. We were unable to find any metrics to differentiate walking up/down stairs from the other activities using the accelerometer, and the research papers that we found on the topic were not able to decipher walking up stairs with any reasonable accuracy either. Instead, we used barometer data to determine if the user walks up/down stairs. 


