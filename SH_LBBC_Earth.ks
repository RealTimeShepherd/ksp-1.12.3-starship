//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       SH_LBBC_Earth
// Translation: SuperHeavy - Launch, Boostback and Catch - Earth
// Description: This script deals with controlling the SuperHeavy Booster through the following stages
// Launch:      Lift the StarShip up to about 50Km altitude and 2km/s speed using 82% of the available fuel
// Boostback:   Release the StarShip and reverse direction to target the launchsite using another 10% of the fuel
// Catch:       Perform a single landing burn guiding the vehicle to a tower catch using the remaining 8% of fuel

// Parameters:  launchTrg - if specified, the SuperHeavy will wait until the correct moment to launch to the target

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region PARAMETERS
//---------------------------------------------------------------------------------------------------------------------

parameter launchTrg.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Logfile
global log_ble is "Telemetry/sh_lbbc_earth_log.csv".

global pad is latlng(25.9669968, -97.1416771). // Tower Catch point - BC OLIT 1
global degPadEnt is 262. // Heading when entering chopsticks
global mTowerHgt is 235. // Tower height in metres
global mltOffset is 1.5. // Multiplier for calculating offset target
//global mAltWP1 is 600. // Waypoints - ship will travel through these altitudes
global mAltWP2 is 300.
global mAltWP4 is 200.5. // Tower Catch altitude - BC OLIT 1
global mAltAP1 is 300. // Aim points - ship will aim at these altitudes
global mAltAP2 is 230.
global mAltAP3 is 200.

global mGravTurn is 500. // Altitude to start gravity turn
global kNThrLaunch is 68000. // Kn Thrust to trigger launch clamp release
global pctMinProp is 18. // Percent of propellant remaining to trigger MECO & stage separation
global mAeroGuid is 60000. // Altitude to switch to aerodynamic guidance
global degYawTrg is 0.

// PID controller
global pidYaw is pidLoop(0.5, 0.001, 0.001, -10, 10).
set pidYaw:setpoint to 0.

global mPETrg is 200000. // Altitude of target perigee
global kmVesDst is 1175. // Distance of target vessel to trigger launch (Original 1125)
global kmIncDst is 0. // Number of additional Km to add per degree of inclination delta (Original 60)
global degMaxInc is 20. // Maximum inclination delta to trigger launch
global degOffInc is 70. // Target inclination, this should be timed so precession causes alignment on the desired day
                        // Current reckoning of 7 degrees a day, so set to 70 if you want to align in ten days

global mOvrSht is 2000. // Overshoot targeting of tower in metres
global mLdgBrn is 35000. // Altitude to start landing burn
global degMaxAeD is 2. // Maximum deflection during aero portion of landing burn
global degMaxThD is 5. // Maximum deflection during thrust portion of landing burn
global degMaxTBD is 10. // Maximum deflection during throttle balancing portion of descent

global mltDlfAer is 0.12. //Angle multiplier during aero portion of landing burn
global mltDlfThr is 1. //Angle multiplier during thrust portion of landing burn
global dynAerThr is 1.2. // Dynamic pressure threshold to switch from aero to thrust

global arrGridFins is list(). // Array for grid fins

global pidThr is pidLoop(0.7, 0.2, 0, 0.0000001, 1). // PID loop for throttle balance
set pidThr:setpoint to 0.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("SEP.B4.INTER") { set ptBInter to pt. }
	if pt:name:startswith("SEP.22.BOOSTER.INTER") { set ptBInter to pt. }
	if pt:name:startswith("SEP.B4.CORE") { set ptBCore to pt. }
	if pt:name:startswith("SEP.22.BOOSTER.CORE") { set ptBCore to pt. }
	if pt:name:startswith("SEP.23.BOOSTER.INTEGRATED") { set ptBIntegrated to pt. }
	if pt:name:startswith("SEP.B4.33.CLUSTER") { set ptEngClus to pt. }
	if pt:name:startswith("SEP.22.BOOSTER.CLUSTER") { set ptEngClus22 to pt. }
	if pt:name:startswith("SEP.23.BOOSTER.CLUSTER") { set ptEngClus23 to pt. }
	if pt:name:startswith("KI.SS.Quickdisconect") { set ptQDSH to pt. }
	if pt:name:startswith("KI.SS.Shiparm") { set ptQDSS to pt. }
	if pt:name:startswith("SLE.SS.OLP") { set ptOLP to pt. }
	if pt:name:startswith("SEP.B4.GRIDFIN") OR pt:name:startswith("SEP.22.BOOSTER.GRIDFIN") {
		if vdot(ship:facing:topvector, pt:position) > 0 {
			if vdot(ship:facing:starvector, pt:position) > 0 {
				set ptGridFL to pt.
			} else {
				set ptGridFR to pt.
			}
		} else {
			if vdot(ship:facing:starvector, pt:position) > 0 {
				set ptGridAL to pt.
			} else {
				set ptGridAR to pt.
			}
		}
	}
}

// Bind to modules within SuperHeavy Interstage
if defined ptBInter {
	set mdDecouple to ptBInter:getmodule("ModuleDecouple").
}

// Bind to resources within SuperHeavy Booster
if defined ptBCore {
	set mdCoreRCS to ptBCore:getmodule("ModuleRCSFX").
	// Bind to main tanks
	for rsc in ptBCore:resources {
		if rsc:name = "LqdOxygen" { set rsCoreLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsCoreCH4 to rsc. }
	}
}

// Bind to resources within SuperHeavy Booster Integrated
if defined ptBIntegrated {
	set mdDecouple to ptBIntegrated:getmodule("ModuleDecouple").
	set mdCoreRCS to ptBIntegrated:getmodule("ModuleRCSFX").
	// Bind to main tanks
	for rsc in ptBIntegrated:resources {
		if rsc:name = "LqdOxygen" { set rsCoreLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsCoreCH4 to rsc. }
	}
}

// Bind to modules within Engine Cluster
if defined ptEngClus22 {
	set mdAllEngs to ptEngClus22:getmodulebyindex(1).
	set mdMidEngs to ptEngClus22:getmodulebyindex(2).
	set mdCntEngs to ptEngClus22:getmodulebyindex(3).
}
if defined ptEngClus23 {
	set mdAllEngs to ptEngClus23:getmodulebyindex(2).
	set mdMidEngs to ptEngClus23:getmodulebyindex(3).
	set mdCntEngs to ptEngClus23:getmodulebyindex(4).
}

// Bind to Quick Disconnect module within the QD arm
if defined ptQDSH {
	set mdQDSH to ptQDSH:getmodule("ModuleAnimateGeneric").
}

// Bind to Quick Disconnect module within the QD arm
if defined ptQDSS {
	set mdQDSS to ptQDSS:getmodule("ModuleAnimateGeneric").
}

// Bind to clamp module within the OLP
if defined ptOLP {
	set mdOLPClamp to ptOLP:getmodule("LaunchClamp").
}

// Bind to modules within Grid Fins
if defined ptGridFL {
	set mdGridFLCS to ptGridFL:getmodule("ModuleControlSurface").
	arrGridFins:add(mdGridFLCS).
}
if defined ptGridFR {
	set mdGridFRCS to ptGridFR:getmodule("ModuleControlSurface").
	arrGridFins:add(mdGridFRCS).
}
if defined ptGridAL {
	set mdGridALCS to ptGridAL:getmodule("ModuleControlSurface").
	arrGridFins:add(mdGridALCS).
}
if defined ptGridAR {
	set mdGridARCS to ptGridAR:getmodule("ModuleControlSurface").
	arrGridFins:add(mdGridARCS).
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

//lock headSH to vang(north:vector, SHIP:srfPrograde:vector).
lock headSH to heading_of_vector(SHIP:srfprograde:vector).
lock vecPad to vxcl(up:vector, pad:position).
lock degBerPad to relative_bearing(headSH, pad:heading).
lock mPad to pad:distance.
lock mSrf to (vecPad - vxcl(up:vector, SHIP:geoposition:position)):mag.
lock pctProp to (rsCoreCH4:amount / rsCoreCH4:capacity) * 100.
lock degAOAPro to vAng(srfPrograde:vector, SHIP:facing:vector).
lock degVector to 0.
lock degProDes to 0.
lock degVecTrg to 0.
lock mpsVrtTrg to 0.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_ble { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:" at (0, 0).
	print "----------------------------" at (0, 1).
	print "Altitude:                  m" at (0, 2).
	print "----------------------------" at (0, 3).
	print "Hrz speed:               m/s" at (0, 4).
	print "Vrt speed:               m/s" at (0, 5).
	print "Air speed:               m/s" at (0, 6).
	print "----------------------------" at (0, 7).
	print "Pad distance:             km" at (0, 8).
	print "Srf distance:              m" at (0, 9).
	print "----------------------------" at (0, 10).
	print "Pad bearing:             deg" at (0, 11).
	print "Vector angle:            deg" at (0, 12).
	print "Attack angle:            deg" at (0, 13).
	print "Target vAng:             deg" at (0, 14).
	print "----------------------------" at (0, 15).
	print "Propellant:                %" at (0, 16).
	print "Throttle:                  %" at (0, 17).
	print "Target VSpd:             mps" at (0, 18).

	deletePath(log_ble).
	local logline is "MET,".
	set logline to logline + "Phase,".
	set logline to logline + "Altitude,".
	set logline to logline + "Hrz speed,".
	set logline to logline + "Vrt speed,".
	set logline to logline + "Air speed,".
	set logline to logline + "Pad distance,".
	set logline to logline + "Srf distance,".
	set logline to logline + "Pad bearing,".
	set logline to logline + "Vector angle,".
	set logline to logline + "Attack angle,".
	set logline to logline + "Target vAng,".
	set logline to logline + "Propellant,".
	set logline to logline + "Throttle,".
	set logline to logline + "Target VSpd,".
	log logline to log_ble.
}

function write_screen_ble { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "            " at (7, 0).
	// print "----------------------------".
	print round(SHIP:altitude, 0) + "    " at (14, 2).
	// print "----------------------------".
	print round(SHIP:groundspeed, 0) + "    " at (14, 4).
	print round(SHIP:verticalspeed, 0) + "    " at (14, 5).
	print round(SHIP:airspeed, 0) + "    " at (14, 6).
	// print "----------------------------".
	print round(mPad / 1000, 0) + "    " at (14, 8).
	print round(mSrf, 0) + "    " at (14, 9).
	// print "----------------------------".
	print round(degBerPad, 2) + "    " at (14, 11).
	print round(degVector, 2) + "    " at (14, 12).
	print round(degAOAPro, 2) + "    " at (14, 13).
	print round(degProDes, 2) + "    " at (14, 14).
	// print "----------------------------".
	print round(pctProp, 2) + "    " at (14, 16).
	print round(throttle * 100, 2) + "    " at (14, 17).
	print round(mpsVrtTrg, 0) + "    " at (14, 18).

	if writelog = true {
		local logline is round(missionTime, 1) + ",".
		set logline to logline + phase + ",".
		set logline to logline + round(SHIP:altitude, 0) + ",".
		set logline to logline + round(SHIP:groundspeed, 0) + ",".
		set logline to logline + round(SHIP:verticalspeed, 0) + ",".
		set logline to logline + round(SHIP:airspeed, 0) + ",".
		set logline to logline + round(mPad, 0) + ",".
		set logline to logline + round(mSrf, 0) + ",".
		set logline to logline + round(degBerPad, 2) + ",".
		set logline to logline + round(degVector, 2) + ",".
		set logline to logline + round(degAOAPro, 2) + ",".
		set logline to logline + round(degProDes, 2) + ",".
		set logline to logline + round(pctProp, 0) + ",".
		set logline to logline + round(throttle * 100, 2) + ",".
		set logline to logline + round(mpsVrtTrg, 0) + ",".
		log logline to log_ble.
	}
}

function relative_bearing { // Returns the delta angle between two supplied headings
	parameter headA.
	parameter headB.
	local delta is headB - headA.
	if delta > 180 { return delta - 360. }
	if delta < -180 { return delta + 360. }
	return delta.
}

function heading_of_vector { // heading_of_vector returns the heading of the vector (number range 0 to 360)
	parameter vecT.
	local east IS VCRS(SHIP:UP:VECTOR, SHIP:NORTH:VECTOR).
	local trig_x IS VDOT(SHIP:NORTH:VECTOR, vecT).
	local trig_y IS VDOT(east, vecT).
	local result IS ARCTAN2(trig_y, trig_x).
	if result < 0 { return 360 + result. } else { return result. }
}

function set_rcs_translate { // Set RCS translation values to target tower
	parameter mag.
	parameter deg.
	set SHIP:control:top to min(1, mag) * cos(deg - degPadEnt).
	set SHIP:control:starboard to 0 - min(1, mag) * sin(deg - degPadEnt).
}

function target_is_body { // Is parameter a valid target
	parameter testTrg.
	list bodies in bodylist.
	for trg in bodylist {
		if trg:name = testTrg { return true. }
	}
	return false.
}

function target_is_vessel { // Is parameter a valid target
	parameter testTrg.
	list targets in targetlist.
	for trg in targetlist {
		if trg:name = testTrg { return true. }
	}
	return false.
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region INITIALISE
//---------------------------------------------------------------------------------------------------------------------

// Enable RCS modules
mdCoreRCS:setfield("rcs", true).

// Nullify RCS control values
set SHIP:control:pitch to 0.
set SHIP:control:yaw to 0.
set SHIP:control:roll to 0.

// Switch off RCS and SAS
rcs off.
sas off.

// Enable all fuel tanks
if defined rsCoreLOX { set rsCoreLOX:enabled to true. }
if defined rsCoreCH4 { set rsCoreCH4:enabled to true. }

// Kill throttle
lock throttle to 0.

// Set grid fins
for mdGridFin in arrGridFins {
	// Disable manual control
	mdGridFin:setfield("pitch", true).
	mdGridFin:setfield("yaw", true).
	mdGridFin:setfield("roll", true).
	// Set starting angles
	mdGridFin:setfield("deploy angle", 0).
	// deploy control surfaces
	mdGridFin:setfield("deploy", true).
}

// Enable all engine group, disable others
//mdAllEngs:doaction("activate engine", true).
wait 0.1.
mdAllEngs:doaction("activate engine", true).
wait 0.1.
mdMidEngs:doaction("activate engine", true).
wait 0.1.
mdCntEngs:doaction("activate engine", true).

write_console_ble().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

if SHIP:status = "PRELAUNCH" {

	// Stage: PRE-LAUNCH
	lock degTrgInc to 0.
	if target_is_body(launchTrg) {
		lock degTrgInc to abs(abs(SHIP:orbit:lan - target:orbit:lan) - degOffInc).
		set target to launchTrg.
		until degTrgInc < 0.3 {
			write_screen_ble("Pre-launch: - " + round(degTrgInc, 4), false).
		}
	}
	if target_is_vessel(launchTrg) { // Launch to circularise as close to target vessel as possible
		lock degTrgInc to abs(SHIP:orbit:lan - target:orbit:lan).
		set target to launchTrg.
		until (target:distance / 1000) < (kmVesDst + (kmIncDst * degTrgInc)) and degTrgInc < degMaxInc {
			if (degTrgInc < degMaxInc) {
				write_screen_ble("D0: " + round(((target:distance / 1000) - (kmVesDst + (kmIncDst * degTrgInc))), 0) + " | I: " + round(degTrgInc, 2), false).
			} else {
				write_screen_ble("Max Inc: " + degMaxInc + " | I: " + round(degTrgInc, 2), false).
			}
		}
	}

	if target_is_vessel(launchTrg) {
		lock degTrgInc to SHIP:orbit:lan - target:orbit:lan.
	}

	// Stage: IGNITION
	lock throttle to 1.
	if defined mdQDSH {
		if mdQDSH:hasevent("Open") { mdQDSH:doevent("Open"). }
	}
	if defined mdQDSS {
		if mdQDSS:hasevent("Open") { mdQDSS:doevent("Open"). }
	}

	until mdAllEngs:getfield("thrust") > kNThrLaunch {
		write_screen_ble("Ignition", false).
	}

	// Stage: LIFT OFF
	lock steering to up.
	if defined mdOLPClamp {
		mdOLPClamp:doaction("Release clamp", true).
	}

	// Record tower position to return to
	set pad to geoPosition.

	until SHIP:altitude > mGravTurn {
		write_screen_ble("Lift off", true).
	}

	// Stage: GRAVITY TURN
	lock degPitTrg to (1 - (sqrt((SHIP:apoapsis - mGravTurn) / mPETrg) * 1.05)) * 90.
	lock steering to lookDirUp(heading(90 - degYawTrg, degPitTrg):vector, up:vector).

	until pctProp < pctMinProp {
		write_screen_ble("Gravity turn", true).
		set degYawTrg to pidYaw:update(time:seconds, degTrgInc).
	}

	// Stage: HOT STAGE
	// lock throttle to 0. // Hot staging - keep throttle on
	mdAllEngs:doaction("shutdown engine", true).
	wait 1.
	mdMidEngs:doaction("shutdown engine", true).
	wait 1.
	mdDecouple:doevent("decouple").
	unlock degTrgInc.

	local timeStage is time:seconds + 4.
	until time:seconds > timeStage {
		write_screen_ble("Hot stage", true).
	}

	// Stage: BEGIN FLIP
	for mdGridFin in arrGridFins { // Enable manual control
		mdGridFin:setfield("pitch", false).
		mdGridFin:setfield("yaw", false).
		mdGridFin:setfield("roll", false).
	}
	rcs on.
	local headBB is heading_of_vector(srfRetrograde:vector).
	lock steering to lookdirup(heading(headBB, 0):vector, heading(0, -90):vector). // Aim at horizon in direction of retrograde

	until mdCntEngs:getfield("propellant") = "Very Stable (100.00 %)" {
		write_screen_ble("Begin flip", true).
	}

	// Stage: FLIP
	until vAng(SHIP:facing:vector, heading(headBB, 0):vector) < 30 {
		write_screen_ble("Flip", true).
	}

	// Stage: BOOSTBACK
	mdMidEngs:doaction("activate engine", true).
	// lock throttle to 1. - Hot staging keeps throttle on

	until abs(degBerPad) < 20 {
		write_screen_ble("Boostback", true).
		// set navMode to "Surface".
	}

	// Stage: TARGET PAD
	lock steering to lookdirup(heading(pad:heading + degBerPad, 0):vector, heading(0, -90):vector).
	mdAllEngs:doaction("shutdown engine", true).
	wait 0.1.
	mdMidEngs:doaction("shutdown engine", true).
	wait 0.1.
	mdCntEngs:doaction("activate engine", true).
	wait 0.1.
	lock timeFall to sqrt((2 * SHIP:apoapsis) / 9.8).
	lock mpsVelTrg to (mSrf + mOvrSht) / (eta:apoapsis + timeFall).

	until SHIP:groundspeed > (mpsVelTrg * 0.99) {
		write_screen_ble("Target Pad", true).
		// set navMode to "Surface".
	}

	// Stage: STABILISE
	lock throttle to 0.
	rcs on.
	lock steering to lookdirup(heading(pad:heading, 0):vector, heading(0, -90):vector).
	local timeStab is time:seconds + 20.

	until time:seconds > timeStab {
		write_screen_ble("Stabilise", true).
	}

	// Stage: BEGIN RE-ORIENT
	set SHIP:control:pitch to -1. // Begin pitch back
	local timeRO is time:seconds + 7.

	until time:seconds > timeRO {
		write_screen_ble("Begin re-orient", true).
	}

	// Stage: RE-ORIENT
	set SHIP:control:pitch to 0.
	rcs off.

	until 180 - abs(degAOAPro) < 20 {
		write_screen_ble("Re-orient", true).
	}

}

// Stage: RETRO ATTITUDE
rcs on.
lock steering to lookdirup(srfRetrograde:vector, heading(degPadEnt, 0):vector).

until SHIP:altitude < mAeroGuid {
	write_screen_ble("Retro attitude", true).
}

// Re-entry section is effective to begin with but it all goes wrong at about 20km alt
// It seems this version of KSP/FAR gives the atmos much greater effect on the light body of the nearly empty SH
// So, the angle between prograde and the desired vector just keeps increasing from sometime below 20km alt
// I've not yet found a consistent way to reduce the angle, should possibly start to look into serious grid fin automation
// For the moment though, everything below these comments is basically up for grabs
// Stage: RE-ENTRY
lock degVecTrg to (SHIP:altitude - 1000) / 2500. // Calculate desired angle for falling trajectory
lock axsPadZen to vcrs(pad:position, SHIP:up:vector). // Common axis of the vector to the pad and up
lock rotPadDes to angleAxis(degVecTrg, axsPadZen).
lock vecDesire to rotPadDes * pad:position. // Desired vector - we want to be travelling in this direction
lock degProDes to vAng(srfPrograde:vector, vecDesire). // Angle between the prograde vector and the desired vector
lock axsProDes to vcrs(vecDesire, srfPrograde:vector). // Common axis of the prograde vector and the desired vector
lock rotMag to max(-15, min(15, degProDes * (0 - ((5 - SHIP:q) * 2)))). // Magnitude of the rotation
lock rotProDes to angleAxis(rotMag, axsProDes).
lock steering to lookdirup(rotProDes * -vecDesire, heading(degPadEnt, 0):vector). // Product of rotProDes and '-' of the desired vector

until SHIP:altitude < mLdgBrn {
	write_screen_ble("Re-entry", true).
}

// Stage: LANDING BURN (AERO)
lock steering to lookdirup(heading(pad:heading + degBerPad, 0):vector, heading(0, -90):vector).
mdAllEngs:doaction("shutdown engine", true).
wait 0.1.
mdMidEngs:doaction("activate engine", true).
wait 0.1.
mdCntEngs:doaction("activate engine", true).
wait 0.1.
lock throttle to 1.
set mAltTrg to mAltAP1.
lock degProPad to vAng(srfPrograde:vector, pad:position).
lock axsProPad to vcrs(srfPrograde:vector, pad:position).
lock rotProDes to angleAxis(max(degMaxAeD, degProPad * mltDlfAer), axsProPad).
lock steering to lookdirup(rotProDes * srfRetrograde:vector, heading(degPadEnt, 0):vector).
lock mpsVrtTrg to 0 - (sqrt((SHIP:altitude - mAltTrg) / 1000) * 130).

until SHIP:q < dynAerThr {
	write_screen_ble("Landing burn (aero)", true).
}

// Stage: LANDING BURN (THRUST)
lock rotProDes to angleAxis(max(0 - degMaxThD, degProPad * (0 - mltDlfThr)), axsProPad).

until SHIP:verticalspeed > mpsVrtTrg {
	write_screen_ble("Landing burn (thrust)", true).
}

// Stage: BALANCE THROTTLE
mdAllEngs:doaction("shutdown engine", true).
wait 0.1.
mdMidEngs:doaction("shutdown engine", true).
wait 0.1.
mdCntEngs:doaction("activate engine", true).
wait 0.1.
lock mpsVrtTrg to (mAltTrg - SHIP:altitude) / 5.
lock throttle to max(0.0001, pidThr:update(time:seconds, SHIP:verticalspeed - mpsVrtTrg)). // Attempt to hover at mAltTrg
set padOS to latlng(pad:lat - ((mTowerHgt * mltOffset/SHIP:altitude) * (SHIP:geoposition:lat - pad:lat)), pad:lng - ((mTowerHgt * mltOffset/SHIP:altitude) * (SHIP:geoposition:lng - pad:lng))).
lock mltDflBal to 50 / (SHIP:altitude / 250).
lock degProOSP to vAng(srfPrograde:vector, padOS:position).
lock axsProOSP to vcrs(srfPrograde:vector, padOS:position).
lock rotProOSP to angleAxis(max(degMaxTBD, degProOSP * ( mltDflBal)), axsProOSP).
// lock rotProOSP to angleAxis(max(0 - degMaxTBD, degProOSP * (0 - mltDflBal)), axsProOSP).
lock steering to lookdirup(rotProOSP * srfRetrograde:vector, heading(degPadEnt, 0):vector). // Target offset pad

until SHIP:altitude < mAltAP1 {
	write_screen_ble("Balance throttle", true).
}

// Stage: TOWER APPROACH
set mAltTrg to mAltAP2.
lock vecSrfVel to vxcl(up:vector, SHIP:velocity:surface).
set sTTR to 0.01 + min(10, mSrf).
lock vecThr to ((vecPad / sTTR) - vecSrfVel).
lock degThrHed to heading_of_vector(vecThr).
lock steering to lookdirup(vecThr + (150 * up:vector), heading(degPadEnt, 0):vector).
unlock rotProOSP.
unlock axsProOSP.
unlock degProOSP.

until mSrf < 5 and SHIP:groundspeed < 3 and SHIP:altitude < mAltWP2 {
	write_screen_ble("Tower Approach", true).
	set_rcs_translate(vecThr:mag, degThrHed).
}

// Stage: DESCENT
lock steering to lookDirUp(up:vector, heading(degPadEnt, 0):vector).
set mAltTrg to mAltAP3.

until SHIP:altitude < mAltWP4 {
	write_screen_ble("Descent", true).
	set_rcs_translate(vecThr:mag, degThrHed).
}

// Stage: TOWER CATCH
lock throttle to 0.
set SHIP:control:top to 0.
set SHIP:control:starboard to 0.
unlock steering.
rcs off.
for mdGridFin in arrGridFins {
	// Disable manual control
	mdGridFin:setfield("pitch", true).
	mdGridFin:setfield("yaw", true).
	mdGridFin:setfield("roll", true).
}

local sStabilise is 10.
local timeStable is time:seconds + sStabilise.
until time:seconds > timeStable {
	write_screen_ble("Tower catch", true).
}

unlock steering.
sas on.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
