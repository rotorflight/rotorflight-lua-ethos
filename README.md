# Rotorflight Lua Scripts for Ethos

*Rotorflight* is a _Flight Control_/_FBL_ Software Suite for traditional single-rotor RC helicopters. It is based on Betaflight, enjoying all the great features of the Betaflight platform, plus many new features added for helicopters.

*Rotorflight Lua Scripts* is a package of Ethos Lua scripts for configuring the Rotorflight flightcontroller from the transmitter.

## Requirements

- Ethos 1.1.0 or later
- an X10, X12, X18, X20 or Twin X Lite transmitter
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

Download the latest files (click *Code* and then *Download ZIP*) and copy the `RF` folder to the `scripts` folder on your transmitter. You will know if you did this correctly if the *Rotorflight* tool shows up on the Ethos system menu.

### Copying the RF folder

USB Method

1. Power on your transmitter.
2. Connect your transmitter to a computer with an USB cable.
3. Select *Ethos Suite* on the transmitter.
4. Open the new drive on your computer.
5. Unzip the file and copy the RF folder to the scripts folder on the SDCARD drive.
6. Eject the drive.
7. Unplug the USB cable.
8. Turn off the transmitter and re-power it.

SD Card Method

1. Power off your transmitter.
2. Remove the SD card and plug it into a computer.
3. Unzip the file and copy the RF folder to the scripts folder on the SDCARD drive.
4. Eject the SD card.
5. Reinsert your SD card into the transmitter.
6. Power up your transmitter.

## Usage

See the [Lua Scripts Wiki page](https://github.com/rotorflight/rotorflight/wiki/Lua-Scripts).

## Credits

Thanks go out to everyone who contributed along the way, especially the Betaflight and Rotorflight teams and the following Ethos users:
- **Bender** - testing and suggestions
- **egon** - Lua script maintainer
- **James-T1** - author of the first Lua scripts for Ethos
- **rob.thomson** - providing hardware, testing and suggestions
