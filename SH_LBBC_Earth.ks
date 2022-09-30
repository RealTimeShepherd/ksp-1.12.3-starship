
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Logfile
global log is "sh_lbbc_earth_log.csv".

// Define Boca Chica catch tower - long term get this from target info
global pad is latlng(25.9669968, -97.1416771). // Tower Catch point - BC OLIT 1
global degPadEnt is 262.

global mGravTurn is 500.
global kNThrLaunch is 68000.
global pctMinProp is 16.

global mAPTrg is 500000.
global mPETrg is 200000.
global degPitTrg is 0.

global arrGridFins is list().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("SEP.B4.INTER") { set ptBInter to pt. }
	if pt:name:startswith("SEP.B4.CORE") { set ptBCore to pt. }
	if pt:name:startswith("SEP.B4.33.CLUSTER") { set ptEngClus to pt. }
	if pt:name:startswith("KI.SS.Quickdisconect") { set ptQDSH to pt. }
	if pt:name:startswith("KI.SS.Shiparm") { set ptQDSS to pt. }
	if pt:name:startswith("SLE.SS.OLP") { set ptOLP to pt. }
	if pt:name:startswith("SEP.B4.GRIDFIN") {
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
	set mdCommand to ptBInter:getmodule("ModuleCommand").
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

// Bind to modules within Engine Cluster
if defined ptEngClus {
	set mdEngSwitch to ptEngClus:getmodule("ModuleTundraEngineSwitch").
	set mdAllEngs to ptEngClus:getmodulebyindex(1).
	set mdMidEngs to ptEngClus:getmodulebyindex(2).
	set mdCntEngs to ptEngClus:getmodulebyindex(3).
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
lock degAttack to vAng(srfPrograde:vector, SHIP:facing:vector).
lock degVector to 0.
lock degVecTrg to 0.
lock mpsVrtTrg to 0.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:        " at (0, 0).
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

	deletePath(log).
	local logline is "Time,".
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
	log logline to log.
}

function write_screen { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "                " at (14, 0).
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
	print round(degAttack, 2) + "    " at (14, 13).
	print round(degVecTrg, 2) + "    " at (14, 14).
	// print "----------------------------".
	print round(pctProp, 0) + "    " at (14, 16).
	print round(throttle * 100, 2) + "    " at (14, 17).
	print round(mpsVrtTrg, 0) + "    " at (14, 18).

	if writelog = true {
		local logline is time:seconds + ",".
		set logline to logline + phase + ",".
		set logline to logline + round(SHIP:altitude, 0) + ",".
		set logline to logline + round(SHIP:groundspeed, 0) + ",".
		set logline to logline + round(SHIP:verticalspeed, 0) + ",".
		set logline to logline + round(SHIP:airspeed, 0) + ",".
		set logline to logline + round(mPad, 0) + ",".
		set logline to logline + round(mSrf, 0) + ",".
		set logline to logline + round(degBerPad, 2) + ",".
		set logline to logline + round(degVector, 2) + ",".
		set logline to logline + round(degAttack, 2) + ",".
		set logline to logline + round(degVecTrg, 2) + ",".
		set logline to logline + round(pctProp, 0) + ",".
		set logline to logline + round(throttle * 100, 2) + ",".
		set logline to logline + round(mpsVrtTrg, 0) + ",".
		log logline to log.
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
mdAllEngs:doaction("activate engine", true).
wait 0.1.
mdMidEngs:doaction("activate engine", true).
wait 0.1.
mdCntEngs:doaction("activate engine", true).

set target to moon.

write_console().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

// Stage: PRE-LAUNCH
until abs(SHIP:orbit:lan - target:orbit:lan) < 0.01 {
	write_screen("Pre-launch: - " + round(abs(SHIP:orbit:lan - target:orbit:lan), 4), false).
}

// Stage: IGNITION
lock throttle to 1.
if mdQDSH:hasevent("Open") { mdQDSH:doevent("Open"). }
if mdQDSS:hasevent("Open") { mdQDSS:doevent("Open"). }

until mdAllEngs:getfield("thrust") > kNThrLaunch {
	write_screen("Ignition", false).
}

// Stage: LIFT OFF
lock steering to up.
mdOLPClamp:doaction("Release clamp", true).

until SHIP:altitude > mGravTurn {
	write_screen("Lift off", true).
}

// Stage: GRAVITY TURN
lock degPitTrg to (1 - sqrt((SHIP:apoapsis - mGravTurn) / mPETrg)) * 90.
lock steering to lookDirUp(heading(90, degPitTrg):vector, up:vector).

until pctProp < pctMinProp {
	write_screen("Gravity turn", true).
}

// Stage: STAGE
mdAllEngs:doaction("shutdown engine", true).
wait 0.1.
mdMidEngs:doaction("shutdown engine", true).
wait 0.1.
mdCntEngs:doaction("shutdown engine", true).
wait 0.1.
mdDecouple:doevent("decouple").

local timeStage is time:seconds + 120.
until time:seconds > timeStage {
	write_screen("Stage", true).
}


//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
