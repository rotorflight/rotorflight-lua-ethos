# Rotorflight Lua Scripts for Ethos

[Rotorflight](https://github.com/rotorflight) is a Flight Control software suite designed for
single-rotor helicopters. It consists of:

- Rotorflight Flight Controller Firmware
- Rotorflight Configurator, for flashing and configuring the flight controller
- Rotorflight Blackbox Explorer, for analyzing blackbox flight logs
- Rotorflight Lua Scripts, for configuring the flight controller using a transmitter running:
  - EdgeTX/OpenTX
  - Ethos (this repository)

Built on Betaflight 4.3, Rotorflight incorporates numerous advanced features specifically
tailored for helicopters. It's important to note that Rotorflight does _not_ support multi-rotor
crafts or airplanes; it's exclusively designed for RC helicopters.

This version of Rotorflight is also known as **Rotorflight 2** or **RF2**.


## Information

Tutorials, documentation, and flight videos can be found on the [Rotorflight website](https://www.rotorflight.org/).


## Features

Rotorflight has many features:

* Many receiver protocols: CRSF, S.BUS, F.Port, DSM, IBUS, XBUS, EXBUS, GHOST, CPPM
* Support for various telemetry protocols: CSRF, S.Port, HoTT, etc.
* ESC telemetry protocols: BLHeli32, Hobbywing, Scorpion, Kontronik, OMP Hobby, ZTW, APD, YGE
* Advanced PID control tuned for helicopters
* Stabilisation modes (6D)
* Rotor speed governor
* Motorised tail support with Tail Torque Assist (TTA, also known as TALY)
* Remote configuration and tuning with the transmitter
  - With knobs / switches assigned to functions
  - With Lua scripts on EdgeTX, OpenTX and Ethos
* Extra servo/motor outputs for AUX functions
* Fully customisable servo/motor mixer
* Sensors for battery voltage, current, BEC, etc.
* Advanced gyro filtering
  - Dynamic RPM based notch filters
  - Dynamic notch filters based on FFT
  - Dynamic LPF
* High-speed Blackbox logging

Plus lots of features inherited from Betaflight:

* Configuration profiles for changing various tuning parameters
* Rates profiles for changing the stick feel and agility
* Multiple ESC protocols: PWM, DSHOT, Multishot, etc.
* Configurable buzzer sounds
* Multi-color RGB LEDs
* GPS support

And many more...


## Lua Scripts Requirements

- Ethos 1.1.0 or later
- an X10, X12, X14, X18, X20 or Twin X Lite transmitter
- a FrSky Smartport or F.Port receiver using ACCESS, ACCST, TD or TW mode


## Tested Receivers

The following receivers were correctly working with an X18 or X20 transmitter.
- TD MX 1.0.10
- R9 MX ACCESS 1.3.2
- R9 Mini ACCESS 1.3.1
- Archer RS ACCESS 2.1.10
- RX6R ACCESS 2.1.8
- R-XSR ACCESS 2.1.8
- R-XSR ACCST FCC F.port 2.1.0
- Archer Plus RS and Archer Plus RS Mini ACCESS F.Port 1.0.5

Note: when saving changes fails, the scripts will automatically retry. The R-XSR and the Archer Plus RS (Mini) seem to retry regularly, while the other receivers rarely do this.


## Installation

Download the latest files (click *Code* and then *Download ZIP*) and copy the `RF2` folder to the `scripts` folder on your transmitter. You will know that you've done this correctly if the *Rotorflight 2* tool appears on the Ethos *System* menu.

### Copying the RF2 folder

USB Method

1. Power on your transmitter
2. Connect your transmitter to a computer with an USB cable
3. Select *Ethos Suite* on the transmitter
4. Open the new drive on your computer
5. Unzip the file and copy the `RF2` folder to the `scripts` folder on the SDCARD drive
6. Eject the drive
7. Unplug the USB cable
8. Turn off the transmitter and re-power it

SD Card Method

1. Power off your transmitter
2. Remove the SD card and plug it into a computer
3. Unzip the file and copy the `RF2` folder to the `scripts` folder on the SDCARD drive
4. Eject the SD card
5. Reinsert your SD card into the transmitter
6. Power up your transmitter

## Usage
See the [Lua Scripts page](https://www.rotorflight.org/docs/Tutorial-Setup/Lua-Scripts).


## Contributing

Rotorflight is an open-source community project. Anybody can join in and help to make it better by:

* Helping other users on Rotorflight Discord or other online forums
* [Reporting](https://github.com/rotorflight?tab=repositories) bugs and issues, and suggesting improvements
* Testing new software versions, new features and fixes; and providing feedback
* Participating in discussions on new features
* Create or update content on the [Website](https://www.rotorflight.org)
* [Contributing](https://www.rotorflight.org/docs/Contributing/intro) to the software development - fixing bugs, implementing new features and improvements
* [Translating](https://www.rotorflight.org/docs/Contributing/intro#translations) Rotorflight Configurator into a new language, or helping to maintain an existing translation


## Origins

Rotorflight is software that is **open source** and is available free of charge without warranty.

Rotorflight is forked from [Betaflight](https://github.com/betaflight), which in turn is forked from [Cleanflight](https://github.com/cleanflight).
Rotorflight borrows ideas and code also from [HeliFlight3D](https://github.com/heliflight3d/), another Betaflight fork for helicopters.

Big thanks to everyone who has contributed along the journey!


## Contact

Team Rotorflight can be contacted by email at rotorflightfc@gmail.com.
