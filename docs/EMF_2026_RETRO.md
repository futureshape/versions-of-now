# EMF 2026 Retrospective

I created and first exhibited this [installation](https://www.emfcamp.org/installations/2026/211) at the 2026 [Electromagnetic Field festival](https://www.emfcamp.org). These are my reflections and learnings from before and during the festival.

## Before

### Good stuff

* ESPHome worked well overall as a platform for creating each of the clocks, so I didn't have to worry about boring stuff like display drivers and time sync.
* Building HTML simulations for some of the clocks was useful for validating the animations before flashing anything to a real device.
* Choosing to build the installation around a grid (an IKEA pegboard) and using parametric CAD for the boxes meant that I didn't have to decide on the final layout until the end.

### Could do better

* In my rush to play with my new flip-digit modules, I connected the power supply with the wrong polarity and let the magic smoke out of one of them. Fortunately, I managed to repair it by replacing the burnt-out regulator and one resistor, with the help of a member of South London Makerspace, as I had no experience with SMD soldering.
* Even though EMF gave me enough notice that my installation had been accepted, the last 20% involved 80% of the complexity, as always, and I ended up working on it until the last minute.

## During

### Good stuff

* The installation looked nice and fitted well in the space that was provided, pretty much as I expected.
* The Arts & Installations team were super helpful and responsive in pointing out the area where I was supposed to install it.
* Carrying the installation from the car to the Lounge tent was fine; nothing fell apart. A couple of people asked me what it was when they saw me carrying a board with a whole bunch of cables sticking out from the back.
* People were curious and asked questions when I was around. Many of them didn't know about some of the more "exotic" displays that I had used, so it was a good chance to have a conversation.
* People took photos and videos (and even thermal photos), and it was fun to see these posted on social media and in blog posts about people's highlights of the event.
* It was easy to do software updates in the field, albeit only over USB (not OTA; see below).

### Could do better

* The biggest issue during the event was that some clocks had poor or inconsistent Wi-Fi connections, or refused to connect to Wi-Fi altogether, even to the open network without authentication. This was the case with the ePaper RPi Pico.
* I really should have predicted this, given that EMF badges, which run on ESP32s, have sometimes had Wi-Fi issues. It would have been trivial to test at home: I could have created an extra SSID, connected the clocks to it, and then temporarily disabled it to simulate a loss of connectivity.
* I managed to fix the RPi Pico display in the field by switching its Wi-Fi to access-point mode, so I could connect to it and manually set the time.
* Some other displays periodically lost their Wi-Fi connection and ended up showing "Connecting to Wi-Fi ..." rather than the time. This was not meant to happen: the clocks do not need an ongoing Wi-Fi connection, only one when they start to synchronise the time. This happened because of ESPHome's default [`reboot_timeout`](https://esphome.io/components/wifi/#:~:text=Defaults%20to%20.local.-,reboot_timeout,-(Optional%2C%20Time):%20The) Wi-Fi setting, as well as AI-generated code that I didn't really review, which prioritised showing the Wi-Fi status over the time.
