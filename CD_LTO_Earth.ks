//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       CD_LTO_Earth
// Translation: Crew Dragon - Launch to orbit - Earth
// Description: This script deals with taking the Crew Dragon to low Earth orbit (LEO) through the following stages
// On booster:  Wait for the Falcon 9 booster to lift the Crew Dragon up to about 50Km altitude and 2km/s speed
// Ascent:      Full throttle with the Merlin vac, controlling the pitch to guide the vehicle into an eccentric orbit
// Coast to AP: Wait half an orbit to climb to the maximum altitude
// Circularise: Circularise the orbit at AP
// Rendezvous:  If the F9_LBBL_Earth script controlling the Falcon 9 Booster targeted a vehicle at launch, this script
//                  will launch a follow on script CD_RVD_LEO to conduct rendezvous and docking manoeuvres

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
global log_cle is "Telemetry/cd_lto_earth_log.csv".

// Set target orbit values
global mAPTrg is 457000. // Target apogee (it is assumed that variance in the gravitational field will affect this)
global mPETrg is 200000. // Target perigee
global cnsGME is 3.986e+14. // Earth's gravitational constant
global mEarthR is 6375000. // Radius of Earth (m)
global mAPRad is mAPTrg + mEarthR.
global mPERad is mPETrg + mEarthR.
global mpsHrzTrg is sqrt(2 * cnsGME * mAPRad / (mPERad * (mAPRad + mPERad))). // Target velocity at perigee

// Engine performance values (Calculated from in-game telemetry)
global mpsExhVel is 3073. // Merlin vaccuum engine's exhaust velocity
global tpsMLRate is 0.288164. // Mass in tons lost per second while Merlin vaccuum engine is firing

global mpsVrtTrg is 0. // Vertical speed target
global sToTrgVel is 0. // Seconds to target velocity
global sToZoVrDl is 0. // Seconds to zero vertical speed delta
global sToOrbIns is 10. // Achieve target vspeed delta of zero this many seconds before orbital insertion

// Pitch and Yaw targets
global degPitTrg is 10.
global degYawTrg is 0.

// PID controller
global pidYaw is pidLoop(0.5, 0.001, 0.001, -10, 10).
set pidYaw:setpoint to 0.

global trkStpTim is list(0, 0, 0, 0, 0). // Track time per step
global trkVrtDlt is list(0, 0, 0, 0, 0). // Track vertical speed delta per step

global onBooster is true.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("PMB.F9.Merlin1DVplusplus") { set ptMerlinVac to pt. }
	if pt:name:startswith("PMB.SPX.F94.S2tank") { set ptS2Tank to pt. }
}

// Bind to Merlin vaccuum engine module
if defined ptMerlinVac { set mdMerlinVac to ptMerlinVac:getmodule("ModuleEnginesRF"). }

// Bind to resources within Falcon 9 core
if defined ptS2Tank {
	// Bind to main tanks
	for rsc in ptS2Tank:resources {
		if rsc:name = "LqdOxygen" { set rsS2TankLOX to rsc. }
		if rsc:name = "Kerosene" { set rsS2TankKer to rsc. }
	}
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

lock degPitAct to get_pit(prograde).
lock degYawAct to get_yaw(prograde).
lock mpsVrtDlt to SHIP:verticalspeed - mpsVrtTrg. // Delta between target vertical speed and actual vertical speed
if defined rsS2TankKer { lock klProp to rsS2TankKer:amount. }

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_cle { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:" at (0, 0).
	print "----------------------------" at (0, 1).
	print "Altitude:                  m" at (0, 2).
	print "Apogee:                    m" at (0, 3).
	print "Perigee:                   m" at (0, 4).
	print "Orb speed:               m/s" at (0, 5).
	print "----------------------------" at (0, 6).
	print "Target VSpd:             m/s" at (0, 7).
	print "Actual VSpd:             m/s" at (0, 8).
	print "VSpd delta:              m/s" at (0, 9).
	print "----------------------------" at (0, 10).
	print "Target pitch:            deg" at (0, 11).
	print "Actual pitch:            deg" at (0, 12).
	print "Time to TVel:              s" at (0, 13).
	print "----------------------------" at (0, 14).
	print "Incl delta:              deg" at (0, 15).
	print "Target yaw:              deg" at (0, 16).
	print "Actual yaw:              deg" at (0, 17).
	print "----------------------------" at (0, 18).
	print "Ship mass:                 t" at (0, 19).
	print "Propellant:                l" at (0, 20).
	print "Throttle:                  %" at (0, 21).

	deletePath(log_cle).
	local logline is "MET,".
	set logline to logline + "Phase,".
	set logline to logline + "Altitude,".
	set logline to logline + "Apogee,".
	set logline to logline + "Perigee,".
	set logline to logline + "Orb speed,".
	set logline to logline + "Target VSpd,".
	set logline to logline + "Actual VSpd,".
	set logline to logline + "VSpd delta,".
	set logline to logline + "Target pitch,".
	set logline to logline + "Actual pitch,".
	set logline to logline + "Time to TVel,".
	set logline to logline + "Incl delta,".
	set logline to logline + "Target yaw,".
	set logline to logline + "Actual yaw,".
	set logline to logline + "Ship mass,".
	set logline to logline + "Propellant,".
	set logline to logline + "Throttle,".
	log logline to log_cle.
}

function write_screen_cle { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "        " at (7, 0).
	// print "----------------------------".
	print round(SHIP:altitude, 0) + "    " at (14, 2).
	print round(SHIP:orbit:apoapsis, 0) + "    " at (14, 3).
	print round(SHIP:orbit:periapsis, 0) + "    " at (14, 4).
	print round(SHIP:velocity:orbit:mag, 0) + "    " at (14, 5).
	// print "----------------------------".
	print round(mpsVrtTrg, 0) + "    " at (14, 7).
	print round(SHIP:verticalspeed, 0) + "    " at (14, 8).
	print round(mpsVrtDlt, 0) + "    " at (14, 9).
	// print "----------------------------".
	print round(degPitTrg, 2) + "    " at (14, 11).
	print round(degPitAct, 2) + "    " at (14, 12).
	print round(sToTrgVel, 2) + "    " at (14, 13).
	// print "----------------------------".
	print round(degTarDlt, 4) + "    " at (14, 15).
	print round(degYawTrg, 2) + "    " at (14, 16).
	print round(degYawAct, 2) + "    " at (14, 17).
	// print "----------------------------".
	print round(SHIP:mass, 2) + "    " at (14, 19).
	print round(klProp, 0) + "    " at (14, 20).
	print round(throttle * 100, 2) + "    " at (14, 21).

	if writelog = true {
		local logline is round(missionTime, 1) + ",".
		set logline to logline + phase + ",".
		set logline to logline + round(SHIP:altitude, 0) + ",".
		set logline to logline + round(SHIP:orbit:apoapsis, 0) + ",".
		set logline to logline + round(SHIP:orbit:periapsis, 0) + ",".
		set logline to logline + round(SHIP:velocity:orbit:mag, 0) + ",".
		set logline to logline + round(mpsVrtTrg, 0) + ",".
		set logline to logline + round(SHIP:verticalspeed, 0) + ",".
		set logline to logline + round(mpsVrtDlt, 0) + ",".
		set logline to logline + round(degPitTrg, 2) + ",".
		set logline to logline + round(degPitAct, 2) + ",".
		set logline to logline + round(sToTrgVel, 2) + ",".
		set logline to logline + round(degTarDlt, 4) + ",".
		set logline to logline + round(degYawTrg, 2) + ",".
		set logline to logline + round(degYawAct, 2) + ",".
		set logline to logline + round(SHIP:mass, 2) + ",".
		set logline to logline + round(klProp, 0) + ",".
		set logline to logline + round(throttle * 100, 2) + ",".
		log logline to log_cle.
	}
}

function get_pit { // Get current pitch
	parameter rTarget.
	local fcgShip is SHIP:facing.

	local svlPit is vxcl(fcgShip:starvector, rTarget:forevector):normalized.
	local dirPit is vDot(fcgShip:topvector, svlPit).
	local degPit is vAng(fcgShip:forevector, svlPit).

	if dirPit < 0 { return degPit. } else { return (0 - degPit). }
}

function get_yaw { // Get current yaw
	parameter rTarget.
	local fcgShip is SHIP:facing.

	local svlRol is vxcl(fcgShip:topvector, rTarget:forevector):normalized.
	local dirRol is vDot(fcgShip:starvector, svlRol).
	local degRol is vAng(fcgShip:forevector, svlRol).

	if dirRol > 0 { return degRol. } else { return (0 - degRol). }
}

function heading_of_vector { // heading_of_vector returns the heading of the vector (number range 0 to 360)
	parameter vecT.
	local east IS VCRS(SHIP:UP:VECTOR, SHIP:NORTH:VECTOR).
	local trig_x IS VDOT(SHIP:NORTH:VECTOR, vecT).
	local trig_y IS VDOT(east, vecT).
	local result IS ARCTAN2(trig_y, trig_x).
	if result < 0 { return 360 + result. } else { return result. }
}

function calculate_tvspd { // Calculate target vertical speed (m/s)
	local tEnd is SHIP:mass / (constant:e ^ ((mpsHrzTrg - SHIP:velocity:orbit:mag) / mpsExhVel)). // Calculate end mass (t)
	set sToTrgVel to (SHIP:mass - tEnd) / tpsMLRate. // Calculate time to end mass (s)
	return (2 * (mPETrg - SHIP:altitude)) / sToTrgVel. // Assume linear reduction to zero at T0
}

function calculate_pitch { // Adjust pitch by increments depending upon when vertical speed delta will hit zero
	trkStpTim:remove(0).
	trkStpTim:add(time:seconds). // track time on each step
	trkVrtDlt:remove(0).
	trkVrtDlt:add(mpsVrtDlt). // track how delta is changing
	local chgInDlt is trkVrtDlt[0] - trkVrtDlt[4].
	local chgInTim is trkStpTim[4] - trkStpTim[0].
	if abs(mpsVrtDlt) < 1 {
		set sToOrbIns to sToTrgVel. // We've reached the target, now try and hold it
	}
	if sToTrgVel < sToOrbIns { // Orbital instertion
		if (chgInDlt < 0 and mpsVrtDlt > 0) or (chgInDlt > 0 and mpsVrtDlt < 0) { // Delta is increasing - do something
			if mpsVrtDlt > 0 {
				return degPitTrg - 0.2.
			} else {
				return degPitTrg + 0.2.
			}
		} else { // Delta is decreasing - do nothing
			return degPitTrg.
		}
	} else { // Ascent
		if chgInDlt < 0 { // Delta is increasing - do nothing
			return degPitTrg.
		} else { // Aim for zero delta at sToOrbIns before orbit
			set sToZoVrDl to mpsVrtDlt / (chgInDlt / chgInTim).
			if sToZoVrDl > (sToTrgVel - sToOrbIns) {
				return degPitTrg - 0.02.
			} else {
				return degPitTrg + 0.02.
			}
		}
	}
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

write_console_cle().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

if hastarget {
	if target_is_body(target) {
		lock degTarDlt to abs(target:orbit:lan - SHIP:orbit:lan).
	} else {
		lock degTarDlt to target:orbit:lan - SHIP:orbit:lan.
	}
} else {
	lock degTarDlt to 0.
}

if SHIP:status = "PRELAUNCH" {

	// Stage: PRE-LAUNCH
	until SHIP:verticalspeed > 0.1 {
		write_screen_cle("Pre-launch", false).
	}

	if hastarget {
		if target_is_vessel(target) {
			lock degTarDlt to target:orbit:lan - SHIP:orbit:lan.
		}
	}

	// Stage: ON BOOSTER
	until onBooster = false {
		write_screen_cle("On Booster", true).
		set onBooster to false.
		for pt in SHIP:parts {
			if pt:name:startswith("KK.SPX.F93.S1tank") { set onBooster to true. }
		}
	}

	// Stage: STAGE
	ptMerlinVac:activate.
	lock throttle to 1.
	local timeStage is time:seconds + 4.

	until time:seconds > timeStage {
		write_screen_cle("Stage", true).
	}

	// Stage: ASCENT
	lock steering to lookDirUp(heading(heading_of_vector(prograde:vector) - degYawTrg, degPitTrg + vang(prograde:vector, vxcl(up:vector, prograde:vector))):vector, up:vector).
	set mpsVrtTrg to calculate_tvspd().

	until sToTrgVel < sToOrbIns {
		write_screen_cle("Ascent", true).
		set mpsVrtTrg to calculate_tvspd().
		set degPitTrg to calculate_pitch().
		set degYawTrg to 0 - pidYaw:update(time:seconds, degTarDlt).
	}

	// Stage: ORBITAL INSERTION
	until SHIP:orbit:apoapsis > (mAPTrg * 0.9) {
		write_screen_cle("Orbital insertion", true).
		set mpsVrtTrg to calculate_tvspd().
		set degPitTrg to calculate_pitch().
		set degYawTrg to 0 - pidYaw:update(time:seconds, degTarDlt).
	}

	// Stage: TRIM
	set degYawTrg to 0.
	set degPitTrg to 0.
	lock throttle to 0.4.

	until SHIP:orbit:apoapsis > (mAPTrg * 0.97) {
		write_screen_cle("Trim        ", true).
	}

	lock throttle to 0.
	rcs on.
	set SHIP:control:fore to 1.

	until SHIP:orbit:apoapsis > (mAPTrg * 0.999) {
		write_screen_cle("Trim", true).
		set SHIP:control:fore to max(1, (mAPTrg - SHIP:orbit:apoapsis) / (mAPTrg * 0.97)).
	}

}

// Stage: COAST TO APOGEE
ptMerlinVac:shutdown.
set SHIP:control:fore to 0.

lock steering to lookDirUp(prograde:vector, up:vector).
local timOrient is time:seconds + 30.
until time:seconds > timOrient {
	write_screen_cle("Orient for coast", true).
}
unlock steering.
rcs off.
sas on.
wait 0.2.
set sasMode to "Prograde".

until SHIP:orbit:eta:apoapsis < 4 {
	write_screen_cle("Coast to Apogee", true).
}

// Stage: CIRCULARISING
ptMerlinVac:activate.
lock throttle to 1.
rcs on.

until (SHIP:orbit:apoapsis + SHIP:orbit:periapsis) > (mAPTrg + SHIP:altitude) {
	write_screen_cle("Circularising", true).
}

// Stage: ORBIT ATTAINED
ptMerlinVac:shutdown.
lock throttle to 0.
rcs off.

local timeWait is time:seconds + 1.
until time:seconds > timeWait {
	write_screen_cle("Orbit attained", true).
}
sas off.

if target_is_vessel(target:name) {
	runPath("CD_RVD_LEO.ks", target:name).
} else {

	// Stage: Orient for coast
	lock steering to lookDirUp(prograde:vector, up:vector).

	rcs on.
	set timOrient to time:seconds + 10.
	until time:seconds > timOrient {
		write_screen_cle("Orient for coast", true).
	}
	unlock steering.
	rcs off.
	sas on.
	wait 0.2.
	set sasMode to "Prograde".

}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
