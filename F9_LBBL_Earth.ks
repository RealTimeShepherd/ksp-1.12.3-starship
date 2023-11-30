//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       F9_LBBL_Earth
// Translation: Falcon 9 - Launch, Boostback and Land - Earth
// Description: This script deals with controlling the Falcon 9 Booster through the following stages
// Launch:      
// Boostback:   
// Land:        

// Parameters:  launchTrg - if specified, the Falcon 9 will wait until the correct moment to launch to the target

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
global log_fle is "Telemetry/f9_lbbl_earth_log.csv".

// Landing pad
global pad is latlng(28.4736891, -80.5291855). // SpaceX Landing Zone 1

// Arrays for engines and legs
global arrMerlins is list().
global arrMerlinMDs is list().
global arrInlines is list().
global arrInlineMDs is list().
global arrGridFins is list().
global arrLandingLegs is list().

// Launch variables
global mGravTurn is 500. // Altitude to start gravity turn
global kNThrLaunch is 847. // Kn Thrust (above) to trigger launch clamp release
global pctMinProp is 10. // Percent of propellant remaining to trigger MECO & stage separation
global mAeroGuid is 60000. // Altitude to switch to aerodynamic guidance
global degYawTrg is 0.

// PID controller
global pidYaw is pidLoop(0.5, 0.001, 0.001, -10, 10).
set pidYaw:setpoint to 0.

global mPETrg is 200000. // Altitude of target perigee
global kmVesDst is 1175. // Distance of target vessel to trigger launch
global kmIncDst is 0. // Number of additional Km to add per degree of inclination delta (Original 60)
global degMaxInc is 20. // Maximum inclination delta to trigger launch

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("FSS") { set ptCrewTower to pt. }
	if pt:name:startswith("39Base") { set ptSuppressor to pt. }
	if pt:name:startswith("39A.pad") { set ptStrongBack to pt. }
	if pt:name:startswith("KK.SPX.F93.S1tank") { set ptF9Core to pt. }
	if pt:name:startswith("KK.SPX.F93.interstage") { set ptF9Inter to pt. }
	if pt:name:startswith("KK.SPX.F9LandingLeg") { arrLandingLegs:add(pt). }
	if pt:name:startswith("PMB.F9.Merlin1Dplusplus") {
		arrMerlins:add(pt).
		if vdot(ship:facing:topvector, pt:position) > 0
		and vdot(ship:facing:topvector, pt:position) < 0.5 {
			set ptMerlinCnt to pt.
		}
		if vdot(ship:facing:topvector, pt:position) > 1
		and vdot(ship:facing:topvector, pt:position) > 6 {
			arrInlines:add(pt).
		}
		if vdot(ship:facing:topvector, pt:position) < -0.5
		and vdot(ship:facing:topvector, pt:position) < 6 {
			arrInlines:add(pt).
		}
	}
	if pt:name:startswith("Grid Fin L Titanium") {
		arrGridFins:add(pt).
		if vdot(ship:facing:topvector, pt:position) > 0 {
			if vdot(ship:facing:starvector, pt:position) > 6 {
				set ptGridFL to pt.
			} else {
				set ptGridFR to pt.
			}
		} else {
			if vdot(ship:facing:starvector, pt:position) > 6 {
				set ptGridAL to pt.
			} else {
				set ptGridAR to pt.
			}
		}
	}
}

// Bind to Crew Tower Crew Arm
if defined ptCrewTower {
	set mdCrewArm to ptCrewTower:getmodule("ModuleAnimateGeneric").
}

// Bind to StrongBack retractor and clamp release
if defined ptStrongBack {
	set mdRetractor to ptStrongBack:getmodule("ModuleAnimateGeneric").
	set mdLaunchClamp to ptStrongBack:getmodule("LaunchClamp").
}

// Bind to water suppression engine
if defined ptSuppressor {
	set mdSuppressor to ptSuppressor:getmodule("ModuleEnginesRF").
}

// Bind to Merlin engine modules
for ptMerlin in arrMerlins { arrMerlinMDs:add(ptMerlin:getmodule("ModuleEnginesRF")). }
for ptMerlin in arrInlines { arrInlineMDs:add(ptMerlin:getmodule("ModuleEnginesRF")). }
if defined ptMerlinCnt { set mdMerlinCnt to ptMerlinCnt:getmodule("ModuleEnginesRF"). }

// Bind to resources within Falcon 9 core
if defined ptF9Core {
	// Bind to main tanks
	for rsc in ptF9Core:resources {
		if rsc:name = "LqdOxygen" { set rsCoreLOX to rsc. }
		if rsc:name = "Kerosene" { set rsCoreKer to rsc. }
	}
}

// Bind to modules within Falcon 9 Interstage
if defined ptF9Inter {
	set mdDecouple to ptF9Inter:getmodule("ModuleDecouple").
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

lock kNThrust to mdMerlinCnt:getfield("thrust").
lock headSH to heading_of_vector(SHIP:srfprograde:vector).
lock vecPad to vxcl(up:vector, pad:position).
lock degBerPad to relative_bearing(headSH, pad:heading).
lock mPad to pad:distance.
lock mSrf to (vecPad - vxcl(up:vector, SHIP:geoposition:position)):mag.
lock pctProp to (rsCoreKer:amount / rsCoreKer:capacity) * 100.
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

function write_console_fle { // Write unchanging display elements and header line of new CSV file
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

	deletePath(log_fle).
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
	log logline to log_fle.
}

function write_screen_fle { // Write dynamic display elements and write telemetry to logfile
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
	print round(pctProp, 0) + "    " at (14, 16).
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
		log logline to log_fle.
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

// Nullify RCS control values
set SHIP:control:pitch to 0.
set SHIP:control:yaw to 0.
set SHIP:control:roll to 0.

// Switch off RCS and SAS
rcs off.
sas off.

write_console_fle().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

//if SHIP:status = "PRELAUNCH" {
if SHIP:status = "PRELAUNCH" {

	// Stage: PRE-LAUNCH
	lock degTrgInc to 0.
	if target_is_body(launchTrg) {
		lock degTrgInc to abs(SHIP:orbit:lan - target:orbit:lan).
		set target to launchTrg.
		until degTrgInc < 0.3 {
			write_screen_fle("Pre-launch: - " + round(degTrgInc, 4), false).
		}
	}
	if target_is_vessel(launchTrg) { // Launch to circularise as close to target vessel as possible
		lock degTrgInc to abs(SHIP:orbit:lan - target:orbit:lan).
		set target to launchTrg.
		until (target:distance / 1000) < (kmVesDst + (kmIncDst * degTrgInc)) and degTrgInc < degMaxInc {
			if (degTrgInc < degMaxInc) {
				write_screen_fle("D0: " + round(((target:distance / 1000) - (kmVesDst + (kmIncDst * degTrgInc))), 0) + " | I: " + round(degTrgInc, 2), false).
			} else {
				write_screen_fle("Max Inc: " + degMaxInc + " | I: " + round(degTrgInc, 2), false).
			}
		}
	}

	// Stage: IGNITION
	if mdCrewArm:hasevent("retract crew access arm") { mdCrewArm:doevent("retract crew access arm"). }
	if mdRetractor:hasevent("retract erector") { mdRetractor:doevent("retract erector"). }
	mdSuppressor:doaction("activate engine", true).
	lock throttle to 1.
	for ptMerlin in arrMerlins { ptMerlin:activate. }

	until kNThrust > kNThrLaunch {
		write_screen_fle(kNThrust, false).
	}

	// Stage: LIFT OFF
	local vecFacLaunch is SHIP:facing:topvector.
	lock steering to lookDirUp(up:vector, vecFacLaunch).
	mdLaunchClamp:doevent("release clamp").

	until SHIP:altitude > mGravTurn {
		write_screen_fle("Lift off", true).
	}

	// Stage: GRAVITY TURN
	lock degPitTrg to (1 - (sqrt((SHIP:apoapsis - mGravTurn) / mPETrg) * 1.05)) * 90.
	lock steering to lookDirUp(heading(90 - degYawTrg, degPitTrg):vector, up:vector).

	until pctProp < pctMinProp {
		write_screen_fle("Gravity turn", true).
		set degYawTrg to pidYaw:update(time:seconds, degTrgInc).
	}

	// Stage: STAGE
	lock throttle to 0.
	for ptMerlin in arrMerlins { ptMerlin:shutdown. }
	wait 0.1.
	mdDecouple:doevent("decouple").
	unlock degTrgInc.

	local timeStage is time:seconds + 4.
	until time:seconds > timeStage {
		write_screen_fle("Stage", true).
	}

}

