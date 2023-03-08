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

// Up/down direction is random with two craft docked
global boolSSUp is true.

// Define Boca Chica catch tower - long term get this from target info
global pad_sul is latlng(25.9669968, -97.1416771). // Tower Catch point - BC OLIT 1

// Fuel ratios
global ratLOXRap is 0.57. // Ratio of LOX in the fuel mix for Raptor
global ratCH4Rap is 0.43. // Ratio of CH4 in the fuel mix for Raptor
global ratSSTKBD is 0.92163. // Ratio of Tanker body capacity to Tanker command
global ratSSTKCM is 0.07837. // Ratio of Tanker command capacity to Tanker body

// Top up propellant (Additional to header)
global lTopUp is 25000.

// Event triggers
global mMaxDist is 13000000. // Script start when pad is over this distance away
global mTrgPE is 90000. // Lower Periapsis to this altitude

global arrSSFlaps_sul is list().
global arrRaptorVac0 is list().
global arrRaptorVac1 is list().
global arrRaptorSL0 is list().
global arrRaptorSL1 is list().
global arrRaptorVac_sul is list().
global arrRaptorSL_sul is list().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts (vdot calculations are used to distinguish between the two StarShips)
for pt in SHIP:parts {
	if pt:name:startswith("SEP.S20.HEADER") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSHeader0 to pt. }
	if pt:name:startswith("SEP.22.SHIP.HEADER") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSHeader0 to pt. }
	if pt:name:startswith("SEP.S20.HEADER") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSHeader1 to pt. }
	if pt:name:startswith("SEP.22.SHIP.HEADER") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSHeader1 to pt. }
	if pt:name:startswith("SEP.S20.TANKER") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSCommand0 to pt. }
	if pt:name:startswith("SEP.22.SHIP.TANKER") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSCommand0 to pt. }
	if pt:name:startswith("SEP.S20.TANKER") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSCommand1 to pt. }
	if pt:name:startswith("SEP.22.SHIP.TANKER") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSCommand1 to pt. }
	if pt:name:startswith("SEP.S20.CREW") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSCommand0 to pt. }
	if pt:name:startswith("SEP.22.SHIP.CREW") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSCommand0 to pt. }
	if pt:name:startswith("SEP.S20.CREW") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSCommand1 to pt. }
	if pt:name:startswith("SEP.22.SHIP.CREW") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSCommand1 to pt. }
	if pt:name:startswith("SEP.S20.BODY") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSBody0 to pt. }
	if pt:name:startswith("SEP.22.SHIP.BODY") and vdot(ship:facing:topvector, pt:position) < 0 { set ptSSBody0 to pt. }
	if pt:name:startswith("SEP.S20.BODY") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSBody1 to pt. }
	if pt:name:startswith("SEP.S22.SHIP20.BODY") and vdot(ship:facing:topvector, pt:position) > 0 { set ptSSBody1 to pt. }
	if pt:name:startswith("SEP.RAPTOR.VAC") and vdot(ship:facing:topvector, pt:position) < 0 { arrRaptorVac0:add(pt). }
	if pt:name:startswith("SEP.22.RAPTOR.VAC") and vdot(ship:facing:topvector, pt:position) < 0 { arrRaptorVac0:add(pt). }
	if pt:name:startswith("SEP.RAPTOR.VAC") and vdot(ship:facing:topvector, pt:position) > 0 { arrRaptorVac1:add(pt). }
	if pt:name:startswith("SEP.22.RAPTOR.VAC") and vdot(ship:facing:topvector, pt:position) > 0 { arrRaptorVac1:add(pt). }
	if pt:name:startswith("SEP.RAPTOR.SL") and vdot(ship:facing:topvector, pt:position) < 0 { arrRaptorSL0:add(pt). }
	if pt:name:startswith("SEP.22.RAPTOR.SL") and vdot(ship:facing:topvector, pt:position) < 0 { arrRaptorSL0:add(pt). }
	if pt:name:startswith("SEP.RAPTOR.SL") and vdot(ship:facing:topvector, pt:position) > 0 { arrRaptorSL1:add(pt). }
	if pt:name:startswith("SEP.22.RAPTOR.SL") and vdot(ship:facing:topvector, pt:position) > 0 { arrRaptorSL1:add(pt). }
	if pt:name:startswith("SEP.S20.FWD.LEFT") { set ptFlapFL_sul to pt. }
	if pt:name:startswith("SEP.22.SHIP.FWD.LEFT") { set ptFlapFL_sul to pt. }
	if pt:name:startswith("SEP.S20.FWD.RIGHT") { set ptFlapFR_sul to pt. }
	if pt:name:startswith("SEP.22.SHIP.FWD.RIGHT") { set ptFlapFR_sul to pt. }
	if pt:name:startswith("SEP.S20.AFT.LEFT") { set ptFlapAL_sul to pt. }
	if pt:name:startswith("SEP.22.SHIP.AFT.LEFT") { set ptFlapAL_sul to pt. }
	if pt:name:startswith("SEP.S20.AFT.RIGHT") { set ptFlapAR_sul to pt. }
	if pt:name:startswith("SEP.22.SHIP.AFT.RIGHT") { set ptFlapAR_sul to pt. }
}

// Determine from a known part, which set of parts belong to each vessel
if ptSSBody0:name = "SEP.S20.BODY.NHS" { // 0 is Depot - 1 is StarShip
	set ptDPHeader to ptSSHeader0.
	set ptDPCommand to ptSSCommand0.
	set ptDPBody to ptSSBody0.
	set ptSSHeader_sul to ptSSHeader1.
	set ptSSCommand_sul to ptSSCommand1.
	set ptSSBody_sul to ptSSBody1.
	set arrRaptorVac_sul to arrRaptorVac1.
	set arrRaptorSL_sul to arrRaptorSL1.
	set boolSSUp to false.
} else { // 1 is Depot - 0 is StarShip
	set ptDPHeader to ptSSHeader1.
	set ptDPCommand to ptSSCommand1.
	set ptDPBody to ptSSBody1.
	set ptSSHeader_sul to ptSSHeader0.
	set ptSSCommand_sul to ptSSCommand0.
	set ptSSBody_sul to ptSSBody0.
	set arrRaptorVac_sul to arrRaptorVac0.
	set arrRaptorSL_sul to arrRaptorSL0.
	set boolSSUp to true.
}

// Bind to resources within StarShip Tanker Header
if defined ptSSHeader_sul {
	// Bind to header tanks
	for rsc in ptSSHeader_sul:resources {
		if rsc:name = "LqdOxygen" { set rsHDLOX_sul to rsc. }
		if rsc:name = "LqdMethane" { set rsHDCH4_sul to rsc. }
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
if defined ptSSCommand_sul {
	set mdSSCMRCS to ptSSCommand_sul:getmodule("ModuleRCSFX").
	// Bind to command tanks
	for rsc in ptSSCommand_sul:resources {
		if rsc:name = "LqdOxygen" { set rsCMLOX_sul to rsc. }
		if rsc:name = "LqdMethane" { set rsCMCH4_sul to rsc. }
	}
}

// Bind to modules & resources within StarShip Tanker Body
if defined ptSSBody_sul {
	set mdSSBDRCS to ptSSBody_sul:getmodule("ModuleRCSFX").
	// Bind to command tanks
	for rsc in ptSSBody_sul:resources {
		if rsc:name = "LqdOxygen" { set rsBDLOX_sul to rsc. }
		if rsc:name = "LqdMethane" { set rsBDCH4_sul to rsc. }
	}
}

// Bind to modules within StarShip Depot Body
if defined ptDPBody {
	set mdDPBDDock to ptDPBody:getmodule("ModuleDockingNode").
}
if defined ptSSBody_sul {
	set mdSSBDDock to ptSSBody_sul:getmodule("ModuleDockingNode").
}

// Bind to modules within StarShip Flaps
if defined ptFlapFL_sul {
	set mdFlapFLCS_sul to ptFlapFL_sul:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sul:add(mdFlapFLCS_sul).
}
if defined ptFlapFR_sul {
	set mdFlapFRCS_sul to ptFlapFR_sul:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sul:add(mdFlapFRCS_sul).
}
if defined ptFlapAL_sul {
	set mdFlapALCS_sul to ptFlapAL_sul:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sul:add(mdFlapALCS_sul).
}
if defined ptFlapAR_sul {
	set mdFlapARCS_sul to ptFlapAR_sul:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sul:add(mdFlapARCS_sul).
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

lock mPad_sul to pad_sul:distance.
lock lProp to rsHDCH4_sul:amount + rsCMCH4_sul:amount + rsBDCH4_sul:amount.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_sul { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:" at (0, 0).
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
	print phase + "               " at (7, 0).
	// print "----------------------------".
	print round(SHIP:altitude, 0) + "    " at (14, 2).
	// print "----------------------------".
	print round(SHIP:velocity:orbit:mag, 0) + "    " at (14, 4).
	print round(SHIP:verticalspeed, 0) + "    " at (14, 5).
	// print "----------------------------".
	print round(mPad_sul / 1000, 0) + "    " at (14, 7).
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
		set logline to logline + round(mPad_sul, 0) + ",".
		set logline to logline + round(lProp, 0) + ",".
		set logline to logline + round(throttle * 100, 2) + ",".
		log logline to log_sul.
	}

	if useCam {
		set cam:heading to heading_of_vector(srfPrograde:vector) - 10.
	}

}

function fill_depot {
	local trnLOXCM is transfer("lqdOxygen", ptSSCommand_sul, ptDPCommand, rsCMLOX_sul:amount).
	local trnLOXBD is transfer("lqdOxygen", ptSSBody_sul, ptDPBody, rsBDLOX_sul:amount).
	local trnCH4CM is transfer("LqdMethane", ptSSCommand_sul, ptDPCommand, rsCMCH4_sul:amount).
	local trnCH4BD is transfer("LqdMethane", ptSSBody_sul, ptDPBody, rsBDCH4_sul:amount).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnLOXBD:active = false) { set trnLOXBD:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
	if (trnCH4BD:active = false) { set trnCH4BD:active to true. }
}

function fill_depot_header {
	local lReqHDLOX is rsDPHDLOX:capacity - rsDPHDLOX:amount.
	local lReqHDCH4 is rsDPHDCH4:capacity - rsDPHDCH4:amount.
	local trnLOXCM is transfer("lqdOxygen", ptDPCommand, ptDPHeader, lReqHDLOX * ratSSTKCM).
	local trnLOXBD is transfer("lqdOxygen", ptDPBody, ptDPHeader, lReqHDLOX * ratSSTKBD).
	local trnCH4CM is transfer("LqdMethane", ptDPCommand, ptDPHeader, lReqHDCH4 * ratSSTKCM).
	local trnCH4BD is transfer("LqdMethane", ptDPBody, ptDPHeader, lReqHDCH4 * ratSSTKBD).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnLOXBD:active = false) { set trnLOXBD:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
	if (trnCH4BD:active = false) { set trnCH4BD:active to true. }
}

function fill_tanker_header {
	local trnLOXCM is transfer("lqdOxygen", ptDPHeader, ptSSHeader_sul, rsHDLOX_sul:capacity - rsHDLOX_sul:amount).
	local trnCH4CM is transfer("LqdMethane", ptDPHeader, ptSSHeader_sul, rsHDCH4_sul:capacity - rsHDCH4_sul:amount).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
}

function topup_tanker_body { // The header tank doesn't quite have enough now that 'residuals' are implemented in RO
	local lReqHDLOX is lTopUp * ratLOXRap.
	local lReqHDCH4 is lTopUp * ratCH4Rap.
	local trnLOXCM is transfer("lqdOxygen", ptDPCommand, ptSSBody_sul, lReqHDLOX * ratSSTKCM).
	local trnLOXBD is transfer("lqdOxygen", ptDPBody, ptSSBody_sul, lReqHDLOX * ratSSTKBD).
	local trnCH4CM is transfer("LqdMethane", ptDPCommand, ptSSBody_sul, lReqHDCH4 * ratSSTKCM).
	local trnCH4BD is transfer("LqdMethane", ptDPBody, ptSSBody_sul, lReqHDCH4 * ratSSTKBD).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnLOXBD:active = false) { set trnLOXBD:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
	if (trnCH4BD:active = false) { set trnCH4BD:active to true. }
}

function heading_of_vector { // heading_of_vector returns the heading of the vector (number range 0 to 360)
	parameter vecT.
	local east IS VCRS(SHIP:UP:VECTOR, SHIP:NORTH:VECTOR).
	local trig_x IS VDOT(SHIP:NORTH:VECTOR, vecT).
	local trig_y IS VDOT(east, vecT).
	local result IS ARCTAN2(trig_y, trig_x).
	if result < 0 { return 360 + result. } else { return result. }
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
if defined rsHDLOX_sul { set rsHDLOX_sul:enabled to true. }
if defined rsHDCH4_sul { set rsHDCH4_sul:enabled to true. }
if defined rsCMLOX_sul { set rsCMLOX_sul:enabled to true. }
if defined rsCMCH4_sul { set rsCMCH4_sul:enabled to true. }
if defined rsBDLOX_sul { set rsBDLOX_sul:enabled to true. }
if defined rsBDCH4_sul { set rsBDCH4_sul:enabled to true. }

// Kill throttle
lock throttle to 0.

// Shut down sea level Raptors
for ptRaptorSL in arrRaptorSL_sul { ptRaptorSL:shutdown. }

// Shut down vacuum Raptors
for ptRaptorVac in arrRaptorVac_sul { ptRaptorVac:shutdown. }

// Set flaps to default position
for mdSSFlap in arrSSFlaps_sul {
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
	set cam:target to ptSSBody_sul.
	wait 1.
	set cam:mode to "free".
	wait 1.
	set cam:heading to heading_of_vector(srfPrograde:vector) - 10.
	wait 1.
	set cam:pitch to 0.
	wait 1.
	set cam:distance to 100.
}

// if useCam {
// 	// Camera settings
// 	global cam is addons:camera:flightcamera.
// 	set cam:target to ptSSBody_sul.
// 	wait 1.
// 	set cam:mode to "free".
// 	wait 1.
// 	set cam:pitch to 0.
// 	wait 1.
// 	set cam:heading to -170.
// 	wait 1.
// 	set cam:distance to 80.
// }

write_console_sul().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

// Stage: WAIT FOR UNDOCK
rcs off.
sas on.
wait 1.
set sasMode to "Retrograde".

until mPad_sul > mMaxDist {
	write_screen_sul("Wait for undock: " + round(((mMaxDist - mPad_sul) / 1000), 0) + " km", false).
}

if vAng(SHIP:facing:vector, retrograde:vector) > 2 {
	// STAGE: ORIENT FOR UNDOCK
	rcs on.
	if boolSSUp {
		lock steering to lookDirUp(retrograde:vector, up:vector).
	} else {
		lock steering to lookDirUp(retrograde:vector, -up:vector).
	}
	local timOrient is time:seconds + 10.
	until time:seconds > timOrient {
		write_screen_sul("Orient for undock", true).
	}
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
if mdDPBDDock:hasevent("undock") {
	mdDPBDDock:doevent("undock").
} else {
	mdSSBDDock:doevent("undock").
}
if kuniverse:activevessel:name <> SHIP:name {
	set kuniverse:activevessel to SHIP.
}
wait 0.1.
sas off.
rcs on.
set SHIP:control:top to -1.
local timeFire is time:seconds + 2.

until time:seconds > timeFire {
	write_screen_sul("Undock", true).
	if useCam {
		set cam:target to ptSSBody_sul.
		wait 0.1.
		set cam:heading to heading_of_vector(srfPrograde:vector) - 10.
		wait 0.1.
		set cam:pitch to 0.
	}
}

// Stage: BACKOFF
set SHIP:control:top to 0.
local timeBackoff is time:seconds + 5.

until time:seconds > timeBackoff {
	write_screen_sul("Backoff", true).
	if useCam {
		set cam:mode to "chase".
		wait 0.1.
		set cam:target to ptSSBody_sul.
		wait 0.1.
		set cam:heading to heading_of_vector(srfPrograde:vector) - 10.
		wait 0.1.
		set cam:pitch to 0.
	}
}
if kuniverse:activevessel:name <> SHIP:name {
	set kuniverse:activevessel to SHIP.
}

// Stage: Lower PE
for ptRaptorVac in arrRaptorVac_sul { ptRaptorVac:activate. }
lock throttle to 1.

until SHIP:orbit:periapsis < mTrgPE {
	write_screen_sul("Lower Perigee", true).
}
if kuniverse:activevessel:name <> SHIP:name {
	set kuniverse:activevessel to SHIP.
}

// Stage: FACE PROGRADE
lock throttle to 0.
for ptRaptorVac in arrRaptorVac_sul { ptRaptorVac:shutdown. }
lock steering to lookDirUp(prograde:vector, up:vector).
set timOrient to time:seconds + 30.

until time:seconds > timOrient {
	write_screen_sul("Orient for coast", true).
}

// Stage: EDL
set ag8 to false.
runPath("SS_EDL_Earth.ks", useCam).
