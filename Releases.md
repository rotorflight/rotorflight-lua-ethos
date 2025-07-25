# 2.2.1

This is a maintenance release containing minor bug fixes.

## Downloads

The download locations are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.2.1)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.2.1)
- [Lua Scripts for EdgeTX and OpenTX](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.2.1)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.2.1)
- [Lua Suite for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/tag/release/2.2.1)

## Notes

Rotorflight setup instructions can be found on the Rotorflight website [www.rotorflight.org](https://www.rotorflight.org/).

## Changes from 2.2.0

- Improved support for FLYROTOR ESC
- Various minor fixes



***

# 2.2.0

This is the 2.2.0 release of the *Rotorflight Lua Scripts for Ethos*.

## Downloads

The download locations are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.2.0)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.2.0)
- [Lua Scripts for EdgeTX and OpenTX](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.2.0)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.2.0)
- [Lua Suite for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/tag/release/2.2.0)

## Notes

Rotorflight setup instructions can be found on the Rotorflight website [www.rotorflight.org](https://www.rotorflight.org/).

## Changes from 2.1.0

- Added page *Rate Dynamics*
- Added page *PID Controller Settings*
- Added new RF 2.2 settings to existing pages
- Added units to most settings
- Improved compatibility with Rotorflight Lua Suite for Ethos
- Reduced memory usage
- Various minor fixes



***

# 2.1.0

This is the 2.1.0 release of the *Rotorflight Lua Scripts for Ethos*.

## Downloads

The download locations are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.1.0)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.1.0)
- [Lua Scripts for EdgeTX and OpenTX](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.1.0)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.1.0)
- [Lua Suite for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/tag/release/2.1.0)

## Notes

- Rotorflight setup instructions can be found on the Rotorflight website [www.rotorflight.org](https://www.rotorflight.org/).
- Rotorflight 2.1 *is* backward compatible with Rotorflight 2.0. You *can* load your configuration dump from Rotorflight 2.0 into 2.1.
- If updating from Rotorflight 1, please setup your helicopter from scratch. Follow the instructions on the website.
- As always, please double check your configuration on the bench before flying!

## Changes from 2.0.0

- Added support for custom CRSF/ELRS telemetry
- Added automatic profile switching to all *Profile* pages
- Added a *Status* page which
  - Shows the currently active PID and rate profile numbers
  - Shows *Arming Disabled Flags*, if any
  - Shows the amount of free space on a dataflash, if available. It also offers the option to erase the dataflash.
  - Shows Real-time and CPU load
- The *PIDs* and *Rates* pages
  - Now also show the currently active profile
  - You can change and copy the currently active profile
- *Servo* page
  - Changing the center of a servo now automatically sets servo override for the servo being editted
  - Added button *Override All Servos*
- Added *Model on TX* page, with which you can automatically set model name, timers or global variables on your transmitter. Data is stored on the heli, so you can have different timers for your helis while using just one model on the transmitter.
- *Profile - Governor* page: added *Min throttle*
- Added *Experimental* page for firmware testing purposes
- Added page *ESC - FlyRotor*
- Added page *ESC - HW Platinum V5*
- Added page *ESC - Scorpion Tribunus*
- Added page *ESC - YGE*
- Added *Settings* page for hiding irrelevant pages
- Changing a value using the scroll wheel will go quicker if you scroll fast
- If you try to Save while armed a warning will be given
- Reformatted the *Rescue* page, so the different rescue stages are now more clear
- Improved accessibility by reordering some pages and fields
- Improved MSP handling and processing



***

# 2.0.0

This is the 2.0.0 release of the Rotorflight Lua Scripts for FrSky Ethos.


## Instructions

For instructions and other details, please read the [README](https://github.com/rotorflight/rotorflight-lua-ethos#readme).


## Downloads

The official download locations for Rotorflight 2.0.0 are:

- [Rotorflight Configurator](https://github.com/rotorflight/rotorflight-configurator/releases/tag/release/2.0.0)
- [Rotorflight Blackbox](https://github.com/rotorflight/rotorflight-blackbox/releases/tag/release/2.0.0)
- [Lua Scripts for EdgeTx and OpenTx](https://github.com/rotorflight/rotorflight-lua-scripts/releases/tag/release/2.0.0)
- [Lua Scripts for FrSky Ethos](https://github.com/rotorflight/rotorflight-lua-ethos/releases/tag/release/2.0.0)


## Notes

1. There is a new website [www.rotorflight.org](https://www.rotorflight.org/) for Rotorflight 2.
   The old Wiki in GitHub is deprecated, and is for Rotorflight 1 only.
   Big thanks to the documentation team for setting this up!

1. Rotorflight 2 is **NOT** backward compatible with RF1. You **MUST NOT** load your configuration dump from RF1 into RF2.

1. If coming from RF1, please setup your helicopter from scratch for RF2. Follow the instructions on the website!

1. As always, please double check your configuration on the bench before flying!


## Support

The main source of Rotorflight information and instructions is now the [website](https://www.rotorflight.org/).

Rotorflight has a strong presence on the Discord platform - you can join us [here](https://discord.gg/FyfMF4RwSA/).
Discord is the primary location for support, questions and discussions. The developers are all active there,
and so are the manufacturers of RF Flight Controllers. Many pro pilots are also there.
This is a great place to ask for advice or discuss any complicated problems or even new ideas.

There is also a [Rotorflight Facebook Group](https://www.facebook.com/groups/876445460825093) for hanging out with other Rotorflight pilots.


## Changes

A full changelog can be found online.
