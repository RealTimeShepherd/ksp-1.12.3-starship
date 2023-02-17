//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       SLS_LTO_Earth
// Translation: Space Launch System (NASA) - Launch to orbit - Earth
// Description: This script deals with taking the SLS to low Earth orbit (LEO) through the following stages
// Stage 1:     Lift off with 2 SRBs at max and 4 RS-25s at nearly full throttle
// Stage 2:     Full throttle with 4 remaining RS-25s, controlling the pitch to guide the vehicle into an eccentric orbit
// Coast to AP: Wait half an orbit to climb to the maximum altitude
// PRM:         Perigee raise manouvere

// Parameters:  useCam - if specified, the camera commands will be run (For recording videos)

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
global log_lle is "Telemetry/sls_lto_earth_log.csv".

// Launch variables
global mGravTurn is 500. // Altitude to start gravity turn
global kNThrLaunch is 7400. // Kn Thrust to trigger launch clamp release

// Arrays for flaps and engines
global arrRS25s is list().
global arrSRBs is list().
global arrNoseCones is list().
global arrRS25Mds is list().

// Set target orbit values
global mAPTrg is 511000. // Target apogee (it is assumed that variance in the gravitational field will affect this)
global mPETrg is 200000. // Target perigee
global cnsGME is 3.986e+14. // Earth's gravitational constant
global mEarthR is 6375000. // Radius of Earth (m)
global mAPRad is mAPTrg + mEarthR.
global mPERad is mPETrg + mEarthR.
global mpsHrzTrg is sqrt(2 * cnsGME * mAPRad / (mPERad * (mAPRad + mPERad))). // Target velocity at perigee

// Engine performance values (Calculated from in-game telemetry)
global mpsExhVel is 3231. // RS-25 engines exhaust velocity
global tpsMLRate is 3.4. // Mass in tons lost per second of all 4 RS-25 engines firing

global mpsVrtTrg is 0. // Vertical speed target
global sToTrgVel is 0. // Seconds to target velocity
global sToZoVrDl is 0. // Seconds to zero vertical speed delta
global sToOrbIns is 10. // Achieve target vspeed delta of zero this many seconds before orbital insertion

// Target inclination, this should be timed so precession causes alignment on the desired day
global degOffInc is 70. // Current reckoning of 7 degrees a day, so set to 70 if you want to align in ten days

// Pitch and Yaw targets
global degPitTrg is 10.
global degYawTrg is 0.

// PID controller
global pidYaw is pidLoop(0.5, 0.001, 0.001, -10, 10).
set pidYaw:setpoint to 0.

global trkStpTim is list(0, 0, 0, 0, 0). // Track time per step
global trkVrtDlt is list(0, 0, 0, 0, 0). // Track vertical speed delta per step

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("AM.MLP.SaturnTowerSwingArmGen") { set ptOrionSwing to pt. }
	if pt:name:startswith("AM.MLP.SaturnTowerCrewArm") { set ptOrionCrew to pt. }
	if pt:name:startswith("AM.MLP.SaturnTowerSwingArm0") { set ptSLSSwing to pt. }
	if pt:name:startswith("AM.MLP.SaturnMobileLauncherClampBase") { set ptLauncher to pt. }
	if pt:name:startswith("benjee10.SLS.coreStage") { set ptCore to pt. }
	if pt:name:startswith("PC.5Seg.RSRM") { arrSRBs:add(pt). }
	if pt:name:startswith("PC.Nose") { arrNoseCones:add(pt). }
	if pt:name:startswith("rmm.cotopaxi") { arrRS25s:add(pt). }
}

// Bind to Swing Arm modules
if defined ptOrionSwing {
	set mdOrionSwing to ptOrionSwing:getmodulebyindex(4).
}
if defined ptOrionCrew {
	set mdOrionCrew to ptOrionCrew:getmodule("ModuleAnimateGenericExtra").
}
if defined ptSLSSwing {
	set mdSLSSwing to ptSLSSwing:getmodule("ModuleAnimateGenericExtra").
}

// Bind to Launch clamp
if defined ptLauncher {
	set mdLaunchClamp to ptLauncher:getmodule("LaunchClamp").
}

for ptRS25 in arrRS25s {
	arrRS25Mds:add(ptRS25:getmodule("ModuleEnginesRF")).
}

// Bind to resources within SLS core stage
if defined ptCore {
	for rsc in ptCore:resources {
		if rsc:name = "LqdOxygen" { set rsCoreLOX to rsc. }
		if rsc:name = "LqdHydrogen" { set rsCoreLH2 to rsc. }
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
lock kNThrust to arrRS25Mds[0]:getfield("thrust") + arrRS25Mds[1]:getfield("thrust") + arrRS25Mds[2]:getfield("thrust") + arrRS25Mds[3]:getfield("thrust").
lock klProp to rsCoreLH2:amount.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_lle { // Write unchanging display elements and header line of new CSV file
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

	deletePath(log_lle).
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
	log logline to log_lle.
}

function write_screen_lle { // Write dynamic display elements and write telemetry to logfile
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
	print round(degTrgInc, 4) + "    " at (14, 15).
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
		set logline to logline + round(degTrgInc, 4) + ",".
		set logline to logline + round(degYawTrg, 2) + ",".
		set logline to logline + round(degYawAct, 2) + ",".
		set logline to logline + round(SHIP:mass, 2) + ",".
		set logline to logline + round(klProp, 0) + ",".
		set logline to logline + round(throttle * 100, 2) + ",".
		log logline to log_lle.
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

// Enable RCS modules

// Nullify RCS control values
set SHIP:control:pitch to 0.
set SHIP:control:yaw to 0.
set SHIP:control:roll to 0.

// Switch off RCS and SAS
rcs off.
sas off.

// Kill throttle
lock throttle to 0.

// Shut down RS-25s
for ptRS25 in arrRS25s { ptRS25:shutdown. }

// Retract Crew arm
if mdOrionCrew:hasevent("retract arm") { mdOrionCrew:doevent("retract arm"). }

write_console_lle().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

if SHIP:status <> "PRELAUNCH" {

	// Stage: PRE-LAUNCH
	if target_is_body(launchTrg) {
		lock degTrgInc to abs(abs(SHIP:orbit:lan - target:orbit:lan) - degOffInc).
		set target to launchTrg.
		until degTrgInc < 0.3 {
			write_screen_lle("Pre-launch: - " + round(degTrgInc, 4), false).
		}
	} else {
		lock degTrgInc to 0.
	}

	// Stage: IGNITION
	lock throttle to 1.
	for ptRS25 in arrRS25s { ptRS25:activate. }
	if mdOrionSwing:hasevent("retract arm") { mdOrionSwing:doevent("retract arm"). }
	if mdSLSSwing:hasevent("retract arm") { mdSLSSwing:doevent("retract arm"). }

	until kNThrust > kNThrLaunch {
		write_screen_lle(kNThrust, false).
	}

	// Stage: LIFT OFF
	//lock kNThrust to 
	lock steering to up.
	for ptSRB in arrSRBs { ptSRB:activate. }
	mdLaunchClamp:doevent("release clamp").

	until SHIP:altitude > mGravTurn {
		write_screen_lle("Lift off", true).
	}

	// Stage: GRAVITY TURN
	set degPitTrg to (1 - (sqrt((SHIP:apoapsis - mGravTurn) / mPETrg) * 1.05)) * 90.
	lock steering to lookDirUp(heading(90 - degYawTrg, degPitTrg):vector, up:vector).

	until false {
		write_screen_lle("Gravity turn", true).
		set degYawTrg to pidYaw:update(time:seconds, degTrgInc).
	}

	// Stage: JETTISON SRBs

	until false {
		write_screen_lle("Stage", true).
	}

	// Stage: STAGE 2
	lock steering to lookDirUp(heading(heading_of_vector(prograde:vector) - degYawTrg, degPitTrg + vang(prograde:vector, vxcl(up:vector, prograde:vector))):vector, up:vector).
	set mpsVrtTrg to calculate_tvspd().

	until sToTrgVel < sToOrbIns {
		write_screen_lle("Ascent", true).
		set mpsVrtTrg to calculate_tvspd().
		set degPitTrg to calculate_pitch().
		set degYawTrg to 0 - pidYaw:update(time:seconds, degTrgInc).
	}

	// Stage: ORBITAL INSERTION
	until SHIP:orbit:apoapsis > (mAPTrg * 0.9) {
		write_screen_lle("Orbital insertion", true).
		set mpsVrtTrg to calculate_tvspd().
		set degPitTrg to calculate_pitch().
		set degYawTrg to 0 - pidYaw:update(time:seconds, degTrgInc).
	}

	// Stage: TRIM
	set degYawTrg to 0.
	set degPitTrg to 0.
	lock throttle to 0.4.

	until SHIP:orbit:apoapsis > (mAPTrg * 0.97) {
		write_screen_lle("Trim        ", true).
	}

	lock throttle to 0.
	rcs on.
	set SHIP:control:fore to 1.

	until SHIP:orbit:apoapsis > (mAPTrg * 0.999) {
		write_screen_lle("Trim", true).
		set SHIP:control:fore to max(1, (mAPTrg - SHIP:orbit:apoapsis) / (mAPTrg * 0.97)).
	}

	// Stage: COAST TO APOGEE
	set SHIP:control:fore to 0.

	lock steering to lookDirUp(prograde:vector, up:vector).
	local timOrient is time:seconds + 30.
	until time:seconds > timOrient {
		write_screen_lle("Orient for coast", true).
	}
	unlock steering.
	rcs off.
	sas on.
	wait 0.2.
	set sasMode to "Prograde".

	until SHIP:orbit:eta:apoapsis < 4 {
		write_screen_lle("Coast to Apogee", true).
	}

	// Stage: CIRCULARISING
	lock throttle to 1.
	rcs on.

	until (SHIP:orbit:apoapsis + SHIP:orbit:periapsis) > (mAPTrg + SHIP:altitude) {
		write_screen_lle("Circularising", true).
	}

	// Stage: ORBIT ATTAINED
	lock throttle to 0.
	rcs off.

	local timeWait is time:seconds + 1.
	until time:seconds > timeWait {
		write_screen_lle("Orbit attained", true).
	}
	sas off.

	if target_is_vessel(target:name) {
		runPath("SS_RVD_LEO.ks", target:name).
	} else {

		// Stage: Orient for coast
		lock steering to lookDirUp(prograde:vector, up:vector).

		rcs on.
		set timOrient to time:seconds + 10.
		until time:seconds > timOrient {
			write_screen_lle("Orient for coast", true).
		}
		unlock steering.
		rcs off.
		sas on.
		wait 0.2.
		set sasMode to "Prograde".

	}

}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
