
//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       SS_UDHH_LEO
// Translation: StarShip - Undock and head home - Low Earth orbit
// Description: This script takes a docked Tanker StarShip in low Earth orbit through the following stages
// Wait:        Wait for the StarShip to line up with the OLIT tower below - orient for undocking
// Transfer:    Moments before release, move fuel from the tanker to the depot, keeping just enough for EDL
// Undock:      Detach from the Depot StarShip
// Lower PE:    Fire the vac raptors to lower the PE to just the right amount
// Run script:  Launch the SS_EDL_Earth script to guide the tanker safely back to base

// Parameters:  useCam - if specified, the camera commands will be run (For recording videos)

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region PARAMETERS
//---------------------------------------------------------------------------------------------------------------------

parameter useCam.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Logfile
global log_sul is "Telemetry/ss_udhh_leo_log.csv".

// Define Boca Chica catch tower - long term get this from target info
global pad is latlng(25.9669968, -97.1416771). // Tower Catch point - BC OLIT 1

// Fuel ratios
global ratLOXRap is 0.57. // Ratio of LOX in the fuel mix for Raptor
global ratCH4Rap is 0.43. // Ratio of CH4 in the fuel mix for Raptor
global ratSSTKBD is 0.92163. // Ratio of Tanker body capacity to Tanker command
global ratSSTKCM is 0.07837. // Ratio of Tanker command capacity to Tanker body

// Top up propellant (Additional to header)
global lTopUp is 25000.

// Event triggers
global mMaxPadDist is 13000000.
global mTrgPE is 90000.

global arrSSFlaps is list().
global arrRaptorVac is list().
global arrRaptorSL is list().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts (vdot calculations are used to distinguish between the Tanker and Depot StarShips)
for pt in SHIP:parts {
	if pt:name:startswith("SEP.S20.HEADER") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSHeader to pt. }
	if pt:name:startswith("SEP.S20.HEADER") and vdot(ship:facing:topvector, pt:position) > 0 { set ptDPHeader to pt. }
	if pt:name:startswith("SEP.S20.TANKER") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.S20.TANKER") and vdot(ship:facing:topvector, pt:position) > 0 { set ptDPCommand to pt. }
	if pt:name:startswith("SEP.S20.CREW") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.S20.BODY") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSBody to pt. }
	if pt:name:startswith("SEP.S20.BODY") and vdot(ship:facing:topvector, pt:position) > 0 { set ptDPBody to pt. }
	if pt:name:startswith("SEP.RAPTOR.VAC") and vdot(ship:facing:topvector, pt:position) < 0 { arrRaptorVac:add(pt). }
	if pt:name:startswith("SEP.RAPTOR.SL") and vdot(ship:facing:topvector, pt:position) < 0 { arrRaptorSL:add(pt). }
	if pt:name:startswith("SEP.S20.FWD.LEFT") { set ptFlapFL to pt. }
	if pt:name:startswith("SEP.S20.FWD.RIGHT") { set ptFlapFR to pt. }
	if pt:name:startswith("SEP.S20.AFT.LEFT") { set ptFlapAL to pt. }
	if pt:name:startswith("SEP.S20.AFT.RIGHT") { set ptFlapAR to pt. }
}

// Bind to resources within StarShip Tanker Header
if defined ptSSHeader {
	// Bind to header tanks
	for rsc in ptSSHeader:resources {
		if rsc:name = "LqdOxygen" { set rsHDLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsHDCH4 to rsc. }
	}
}

// Bind to resources within StarShip Depot Header
if defined ptDPHeader {
	// Bind to header tanks
	for rsc in ptDPHeader:resources {
		if rsc:name = "LqdOxygen" { set rsDPHDLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsDPHDCH4 to rsc. }
	}
}

// Bind to modules & resources within StarShip Tanker Command
if defined ptSSCommand {
	set mdSSCMRCS to ptSSCommand:getmodule("ModuleRCSFX").
	// Bind to command tanks
	for rsc in ptSSCommand:resources {
		if rsc:name = "LqdOxygen" { set rsCMLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsCMCH4 to rsc. }
	}
}

// Bind to modules & resources within StarShip Depot Command
if defined ptDPCommand {
	// Bind to command tanks
	for rsc in ptDPCommand:resources {
		if rsc:name = "LqdOxygen" { set rsDPCMLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsDPCMCH4 to rsc. }
	}
}

// Bind to modules & resources within StarShip Tanker Body
if defined ptSSBody {
	set mdSSBDRCS to ptSSBody:getmodule("ModuleRCSFX").
	// Bind to command tanks
	for rsc in ptSSBody:resources {
		if rsc:name = "LqdOxygen" { set rsBDLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsBDCH4 to rsc. }
	}
}

// Bind to modules & resources within StarShip Depot Body
if defined ptDPBody {
	set mdDPBDDock to ptDPBody:getmodule("ModuleDockingNode").
	// Bind to command tanks
	for rsc in ptDPBody:resources {
		if rsc:name = "LqdOxygen" { set rsDPBDLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsDPBDCH4 to rsc. }
	}
}

// Bind to modules within StarShip Flaps
if defined ptFlapFL {
	set mdFlapFLCS to ptFlapFL:getmodule("ModuleSEPControlSurface").
	arrSSFlaps:add(mdFlapFLCS).
}
if defined ptFlapFR {
	set mdFlapFRCS to ptFlapFR:getmodule("ModuleSEPControlSurface").
	arrSSFlaps:add(mdFlapFRCS).
}
if defined ptFlapAL {
	set mdFlapALCS to ptFlapAL:getmodule("ModuleSEPControlSurface").
	arrSSFlaps:add(mdFlapALCS).
}
if defined ptFlapAR {
	set mdFlapARCS to ptFlapAR:getmodule("ModuleSEPControlSurface").
	arrSSFlaps:add(mdFlapARCS).
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

lock mPad to pad:distance.
lock lProp to rsHDCH4:amount + rsCMCH4:amount + rsBDCH4:amount.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_sul { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:        " at (0, 0).
	print "----------------------------" at (0, 1).
	print "Altitude:                  m" at (0, 2).
	print "----------------------------" at (0, 3).
	print "Orb speed:               m/s" at (0, 4).
	print "Vrt speed:               m/s" at (0, 5).
	print "----------------------------" at (0, 6).
	print "Pad distance:             km" at (0, 7).
	print "----------------------------" at (0, 8).
	print "Propellant:                l" at (0, 9).
	print "Throttle:                  %" at (0, 10).

	deletePath(log_sul).
	local logline is "MET,".
	set logline to logline + "Phase,".
	set logline to logline + "Altitude,".
	set logline to logline + "Orb speed,".
	set logline to logline + "Vrt speed,".
	set logline to logline + "Pad distance,".
	set logline to logline + "Propellant,".
	set logline to logline + "Throttle,".
	log logline to log_sul.
}

function write_screen_sul { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "               " at (14, 0).
	// print "----------------------------".
	print round(SHIP:altitude, 0) + "    " at (14, 2).
	// print "----------------------------".
	print round(SHIP:velocity:orbit:mag, 0) + "    " at (14, 4).
	print round(SHIP:verticalspeed, 0) + "    " at (14, 5).
	// print "----------------------------".
	print round(mPad / 1000, 0) + "    " at (14, 7).
	// print "----------------------------".
	print round(lProp, 0) + "    " at (14, 9).
	print round(throttle * 100, 2) + "    " at (14, 10).

	if writelog = true {
		local logline is round(missionTime, 1) + ",".
		set logline to logline + phase + ",".
		set logline to logline + round(SHIP:altitude, 0) + ",".
		set logline to logline + round(SHIP:velocity:orbit:mag, 0) + ",".
		set logline to logline + round(SHIP:verticalspeed, 0) + ",".
		set logline to logline + round(SHIP:airspeed, 0) + ",".
		set logline to logline + round(mPad, 0) + ",".
		set logline to logline + round(lProp, 0) + ",".
		set logline to logline + round(throttle * 100, 2) + ",".
		log logline to log_sul.
	}
}

function fill_depot {
	set trnLOXCM to transfer("lqdOxygen", ptSSCommand, ptDPCommand, rsCMLOX:amount).
	set trnLOXBD to transfer("lqdOxygen", ptSSBody, ptDPBody, rsBDLOX:amount).
	set trnCH4CM to transfer("LqdMethane", ptSSCommand, ptDPCommand, rsCMCH4:amount).
	set trnCH4BD to transfer("LqdMethane", ptSSBody, ptDPBody, rsBDCH4:amount).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnLOXBD:active = false) { set trnLOXBD:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
	if (trnCH4BD:active = false) { set trnCH4BD:active to true. }
}

function fill_depot_header {
	set lReqHDLOX to rsDPHDLOX:capacity - rsDPHDLOX:amount.
	set lReqHDCH4 to rsDPHDCH4:capacity - rsDPHDCH4:amount.
	set trnLOXCM to transfer("lqdOxygen", ptDPCommand, ptDPHeader, lReqHDLOX * ratSSTKCM).
	set trnLOXBD to transfer("lqdOxygen", ptDPBody, ptDPHeader, lReqHDLOX * ratSSTKBD).
	set trnCH4CM to transfer("LqdMethane", ptDPCommand, ptDPHeader, lReqHDCH4 * ratSSTKCM).
	set trnCH4BD to transfer("LqdMethane", ptDPBody, ptDPHeader, lReqHDCH4 * ratSSTKBD).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnLOXBD:active = false) { set trnLOXBD:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
	if (trnCH4BD:active = false) { set trnCH4BD:active to true. }
}

function fill_tanker_header {
	set trnLOXCM to transfer("lqdOxygen", ptDPHeader, ptSSHeader, rsHDLOX:capacity - rsHDLOX:amount).
	set trnCH4CM to transfer("LqdMethane", ptDPHeader, ptSSHeader, rsHDCH4:capacity - rsHDCH4:amount).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
}

function topup_tanker_body { // The header tank doesn't quite have enough now that 'residuals' are implemented in RO
	set lReqHDLOX to lTopUp * ratLOXRap.
	set lReqHDCH4 to lTopUp * ratCH4Rap.
	set trnLOXCM to transfer("lqdOxygen", ptDPCommand, ptSSBody, lReqHDLOX * ratSSTKCM).
	set trnLOXBD to transfer("lqdOxygen", ptDPBody, ptSSBody, lReqHDLOX * ratSSTKBD).
	set trnCH4CM to transfer("LqdMethane", ptDPCommand, ptSSBody, lReqHDCH4 * ratSSTKCM).
	set trnCH4BD to transfer("LqdMethane", ptDPBody, ptSSBody, lReqHDCH4 * ratSSTKBD).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnLOXBD:active = false) { set trnLOXBD:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
	if (trnCH4BD:active = false) { set trnCH4BD:active to true. }
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region INITIALISE
//---------------------------------------------------------------------------------------------------------------------

// Enable RCS modules
mdSSCMRCS:setfield("rcs", true).
mdSSBDRCS:setfield("rcs", true).

// Nullify RCS control values
set SHIP:control:pitch to 0.
set SHIP:control:yaw to 0.
set SHIP:control:roll to 0.

// Switch off RCS and SAS
rcs off.
sas off.

// Enable all fuel tanks
if defined rsHDLOX { set rsHDLOX:enabled to true. }
if defined rsHDCH4 { set rsHDCH4:enabled to true. }
if defined rsCMLOX { set rsCMLOX:enabled to true. }
if defined rsCMCH4 { set rsCMCH4:enabled to true. }
if defined rsBDLOX { set rsBDLOX:enabled to true. }
if defined rsBDCH4 { set rsBDCH4:enabled to true. }

// Kill throttle
lock throttle to 0.

// Shut down sea level Raptors
for ptRaptorSL in arrRaptorSL { ptRaptorSL:shutdown. }

// Shut down vacuum Raptors
for ptRaptorVac in arrRaptorVac { ptRaptorVac:shutdown. }

// Set flaps to default position
for mdSSFlap in arrSSFlaps {
	// Disable manual control
	mdSSFlap:setfield("pitch", true).
	mdSSFlap:setfield("yaw", true).
	mdSSFlap:setfield("roll", true).
	// Set starting angles
	mdSSFlap:setfield("deploy angle", 0).
	// deploy control surfaces
	mdSSFlap:setfield("deploy", true).
}

if useCam {
	// Camera settings
	global cam is addons:camera:flightcamera.
	set cam:target to ptSSBody.
	wait 1.
	set cam:mode to "free".
	wait 1.
	set cam:heading to 0.
	wait 1.
	set cam:pitch to 90.
	wait 1.
	set cam:distance to 100.
}

write_console_sul().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

if mdDPBDDock:hasevent("undock") {

	// STAGE: ORIENT FOR UNDOCK
	rcs on.
	lock steering to lookDirUp(retrograde:vector, up:vector).
	local timOrient is time:seconds + 30.
	until time:seconds > timOrient {
		write_screen_sul("Orient for undock", true).
	}
	unlock steering.
	rcs off.
	sas on.
	wait 1.
	set sasMode to "Retrograde".

	// Stage: WAIT FOR UNDOCK
	until mPad > mMaxPadDist {
		write_screen_sul("Waiting: " + round(((mMaxPadDist - mPad) / 1000), 0) + " km", false).
	}

	// Stage: FUEL TRANSFER
	fill_depot().
	fill_depot_header().
	fill_tanker_header().
	topup_tanker_body().
	local timeFuel is time:seconds + 10.
	until time:seconds > timeFuel {
		write_screen_sul("Fuel transfer", true).
	}

	// Stage: UNDOCK
	sas off.
	mdDPBDDock:doevent("undock").
	rcs on.
	set SHIP:control:top to -1.
	local timeFire is time:seconds + 2.
	until time:seconds > timeFire {
		write_screen_sul("Undock", true).
	}

	// Stage: BACKOFF
	set SHIP:control:top to 0.
	local timeBackoff is time:seconds + 5.
	until time:seconds > timeBackoff {
		write_screen_sul("Backoff", true).
	}

	// Stage: Lower PE
	for ptRaptorVac in arrRaptorVac { ptRaptorVac:activate. }
	lock steering to retrograde.
	lock throttle to 1.
	until SHIP:orbit:periapsis < mTrgPE {
		write_screen_sul("Lower Perigee", true).
	}
	lock throttle to 0.
	for ptRaptorVac in arrRaptorVac { ptRaptorVac:shutdown. }

	// Stage: FACE PROGRADE
	lock steering to lookDirUp(prograde:vector, up:vector).
	set timOrient to time:seconds + 30.
	until time:seconds > timOrient {
		write_screen_sul("Orient for coast", true).
	}
	unlock steering.
	rcs off.
	sas on.
	wait 0.2.
	set sasMode to "Prograde".

}
