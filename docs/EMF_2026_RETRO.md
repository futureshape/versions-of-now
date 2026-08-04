# EMF 2026 Retrospective

I created and first exhibited this [installation](https://www.emfcamp.org/installations/2026/211) at the 2026 [Electromagnetic Field festival](https://www.emfcamp.org). These are my reflections/learnings both from what happened before and during the festival.

## Before

### Good stuff

* ESPHome worked overall as a platform for creating each of the clocks, I didn't have to worry about boring stuff like display drivers, time sync etc.
* Building HTML simulations for some of the clocks was useful for validating the animations before bothering to flash anything on a real device
* Choosing to build the installation around a grid (IKEA pegboard) and using parametric CAD for the boxes - this meant that I didn't have to decide on the final layout until the end

### Could do better

* In my rush to play with my new flip-digit modules I connected the power supply with the wrong polarity and let the magic smoke out of one of the modules. Fortunately I managed to repair it by replacing the burnt out regulator + one resistor, with the help of a member of South London Makerspace (since I had no experience with SMD soldering)
* Even though I had enough notice from EMF that my installation was accepted, as always the last 20% is where 80% of the complexity is, and in the end I was working on it until the last minute 

## During

### Good stuff

* The installation looked nice and mounted OK on the space that was provided, pretty much as I'd expect.
* The Arts & Installations team were super helpful and responsive in term of pointing out the area where I was supposed to install.
* Carrying the installation from the car to the Lounge tent was fine, nothing fell apart. A couple of people asked me what this was, when they saw me carrying a board with a whole bunch of cables sticking out from the back
* People were curious and asked questions when I was around, many of them didn't know about some of the most "exotic" displays that I had used so it was a good chance to have a conversation.
* People took photos/videos (and even thermal photos) - and it was fun to see these posted on sociale media and on blog posts showing people's highlights of the event
* It was easy to do software updates in the field, if only over USB (not OTA, see below)

### Could do better

* The biggest issue during the even was that some clocks had a poor/inconsistent WiFi connection or entirely refused to connect to WiFi, even to the open WiFi without any authentication (that was the case with the ePaper RPi Pico)
* I really should have predicted this, given that there have sometimes been WiFi issues at EMF with badges, which run on ESP32, but I didn't. It would have been trivial to do some testing at home, I could have just created an extra SSID, got the clocks connected to it, and then temporarily disable it to simulate loss of connectivity
* I managed to fix the RPi Pico display in the field by getting it to switch the WiFi to Access Point mode, so I could connect to it and manually set the time. 
* Some other displays periodically lost the WiFi connection and ended up in a state where they showed "Connecting to WiFi ..." rather than showing the time. This was not meant to happen, as the clocks don't need an ongoing WiFi connection, they just need it when they start to sync the time. This happened because of the default ESPHome [`reboot_timeout`](https://esphome.io/components/wifi/#:~:text=Defaults%20to%20.local.-,reboot_timeout,-(Optional%2C%20Time):%20The) WiFI setting, as well as AI-generated code (that I didn't really review) which prioritised showing the WiFi status over the time