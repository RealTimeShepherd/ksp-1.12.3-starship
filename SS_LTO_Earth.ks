//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       SS_LTO_Earth
// Translation: StarShip - Launch to orbit - Earth
// Description: This script deals with taking the StarShip to low Earth orbit (LEO) through the following stages
// On booster:  Wait for the SuperHeavy booster to lift the StarShip up to about 50Km altitude and 2km/s speed
// Ascent:      Full throttle with all 6 engines, controlling the pitch to guide the vehicle into an eccentric orbit
// Coast to AP: Wait half an orbit to climb to the maximum altitude
// Circularise: Circularise the orbit at AP
// Rendezvous:  If the SH_LBBC_Earth script controlling the SuperHeavy Booster targeted a vehicle at launch, this script
//                  will launch a follow on script SS_RVD_LEO to conduct rendezvous and docking manoeuvres

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
global log_sle is "Telemetry/ss_lto_earth_log.csv".

// Arrays for flaps and engines
global arrSSFlaps_sle is list().
global arrRaptorVac_sle is list().
global arrRaptorSL_sle is list().
global arrRSL_actuate_sle is list().
global arrRSL_gimbal_sle is list().
global arrSolarPanels_sle is list().
global arrSPModules_sle is list().

// Set target orbit values
global mAPTrg is 507000. // Target apogee (it is assumed that variance in the gravitational field will affect this)
global mPETrg is 200000. // Target perigee
global cnsGME is 3.986e+14. // Earth's gravitational constant
global mEarthR is 6375000. // Radius of Earth (m)
global mAPRad is mAPTrg + mEarthR.
global mPERad is mPETrg + mEarthR.
global mpsHrzTrg is sqrt(2 * cnsGME * mAPRad / (mPERad * (mAPRad + mPERad))). // Target velocity at perigee

// Engine performance values (Calculated from in-game telemetry)
global mpsExhVel is 3231. // Raptor engines exhaust velocity
global tpsMLRate is 3.4. // Mass in tons lost per second of all 6 raptor engines firing

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
// global pidYaw is pidLoop(0.5, 0.001, 0.001, -10, 10). // Good for StarShip Tanker
global pidYaw is pidLoop(1.2, 0.001, 4, -10, 10).
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
	if pt:name:startswith("SEP.S20.HEADER") { set ptSSHeader to pt. }
	if pt:name:startswith("SEP.22.SHIP.HEADER") { set ptSSHeader to pt. }
	if pt:name:startswith("SEP.23.SHIP.HEADER") { set ptSSHeader to pt. }
	if pt:name:startswith("SEP.S20.CREW") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.22.SHIP.CREW") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.23.SHIP.CREW") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.S20.TANKER") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.22.SHIP.TANKER") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.23.SHIP.TANKER") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.S20.BODY") { set ptSSBody to pt. }
	if pt:name:startswith("SEP.22.SHIP.BODY") { set ptSSBody to pt. }
	if pt:name:startswith("SEP.23.SHIP.BODY") { set ptSSBody to pt. }
	if pt:name:startswith("SEP.23.SHIP.DEPOT") { set ptSSDepot to pt. }
	if pt:name:startswith("SEP.S20.FWD.LEFT") { set ptFlapFL to pt. }
	if pt:name:startswith("SEP.22.SHIP.FWD.LEFT") { set ptFlapFL to pt. }
	if pt:name:startswith("SEP.23.SHIP.FWD.LEFT") { set ptFlapFL to pt. }
	if pt:name:startswith("SEP.S20.FWD.RIGHT") { set ptFlapFR to pt. }
	if pt:name:startswith("SEP.22.SHIP.FWD.RIGHT") { set ptFlapFR to pt. }
	if pt:name:startswith("SEP.23.SHIP.FWD.RIGHT") { set ptFlapFR to pt. }
	if pt:name:startswith("SEP.S20.AFT.LEFT") { set ptFlapAL to pt. }
	if pt:name:startswith("SEP.22.SHIP.AFT.LEFT") { set ptFlapAL to pt. }
	if pt:name:startswith("SEP.23.SHIP.AFT.LEFT") { set ptFlapAL to pt. }
	if pt:name:startswith("SEP.S20.AFT.RIGHT") { set ptFlapAR to pt. }
	if pt:name:startswith("SEP.22.SHIP.AFT.RIGHT") { set ptFlapAR to pt. }
	if pt:name:startswith("SEP.23.SHIP.AFT.RIGHT") { set ptFlapAR to pt. }
	if pt:name:startswith("SEP.RAPTOR.VAC") { arrRaptorVac_sle:add(pt). }
	if pt:name:startswith("SEP.22.RAPTOR.VAC") { arrRaptorVac_sle:add(pt). }
	if pt:name:startswith("SEP.23.RAPTOR.VAC") { arrRaptorVac_sle:add(pt). }
	if pt:name:startswith("SEP.RAPTOR.SL") { arrRaptorSL_sle:add(pt). }
	if pt:name:startswith("SEP.22.RAPTOR2.SL.RC") { arrRaptorSL_sle:add(pt). }
	if pt:name:startswith("SEP.23.RAPTOR2.SL.RC") { arrRaptorSL_sle:add(pt). }
	if pt:name:startswith("nfs-panel-deploying-blanket-arm-1") { arrSolarPanels_sle:add(pt). }
}

// Bind to resources within StarShip Depot
if defined ptSSDepot {
	set mdSSCMRCS to ptSSDepot:getmodule("ModuleRCSFX").
	set mdSSBDRCS to ptSSDepot:getmodule("ModuleRCSFX").
	// Bind to header tanks
	for rsc in ptSSDepot:resources {
		if rsc:name = "LqdOxygen" { set rsDPLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsDPCH4 to rsc. }
	}
}

// Bind to resources within StarShip Header
if defined ptSSHeader {
	// Bind to header tanks
	for rsc in ptSSHeader:resources {
		if rsc:name = "LqdOxygen" { set rsHDLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsHDCH4 to rsc. }
	}
}

// Bind to modules & resources within StarShip Command
if defined ptSSCommand {
	set mdSSCMRCS to ptSSCommand:getmodule("ModuleRCSFX").
	// Bind to command tanks
	for rsc in ptSSCommand:resources {
		if rsc:name = "LqdOxygen" { set rsCMLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsCMCH4 to rsc. }
	}
}

// Bind to modules & resources within StarShip Body
if defined ptSSBody {
	set mdSSBDRCS to ptSSBody:getmodule("ModuleRCSFX").
	// Bind to command tanks
	for rsc in ptSSBody:resources {
		if rsc:name = "LqdOxygen" { set rsBDLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsBDCH4 to rsc. }
	}
}

// Bind to modules within StarShip Flaps
if defined ptFlapFL {
	set mdFlapFLCS to ptFlapFL:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sle:add(mdFlapFLCS).
}
if defined ptFlapFR {
	set mdFlapFRCS to ptFlapFR:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sle:add(mdFlapFRCS).
}
if defined ptFlapAL {
	set mdFlapALCS to ptFlapAL:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sle:add(mdFlapALCS).
}
if defined ptFlapAR {
	set mdFlapARCS to ptFlapAR:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_sle:add(mdFlapARCS).
}

// Bind to actuator and gimbal modules in Raptor sea level engines
for ptRaptorSL in arrRaptorSL_sle {
	arrRSL_actuate_sle:add(ptRaptorSL:getmodule("ModuleSEPRaptor")).
	arrRSL_gimbal_sle:add(ptRaptorSL:getmodule("ModuleGimbal")).
}

// Bind to modules within solar panels
for ptSolarPanel in arrSolarPanels_sle {
	arrSPModules_sle:add(ptSolarPanel:getmodule("ModuleDeployableSolarPanel")).
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

lock degPitAct to get_pit(prograde).
lock degYawAct to get_yaw(prograde).
lock mpsVrtDlt to SHIP:verticalspeed - mpsVrtTrg. // Delta between target vertical speed and actual vertical speed
if defined ptSSDepot {
	lock klProp to rsDPCH4:amount.
} else {
	if defined rsCMCH4 {
		lock klProp to rsHDCH4:amount + rsCMCH4:amount + rsBDCH4:amount.
	} else {
		lock klProp to rsHDCH4:amount + rsBDCH4:amount.
	}
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_sle { // Write unchanging display elements and header line of new CSV file
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

	deletePath(log_sle).
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
	log logline to log_sle.
}

function write_screen_sle { // Write dynamic display elements and write telemetry to logfile
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
		log logline to log_sle.
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
		if chgInDlt < 0 { // Delta is increasing - do something!!
			// return degPitTrg.
			if SHIP:verticalspeed > mpsVrtTrg {
				return degPitTrg - 0.02.
			} else {
				return degPitTrg + 0.02.
			}
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

// Retract Solar Panels
for mdSP in arrSPModules_sle { mdSP:doaction("retract solar panel", true). }

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

// Enable main fuel tanks - disable header tanks
if defined rsHDLOX { set rsHDLOX:enabled to false. }
if defined rsHDCH4 { set rsHDCH4:enabled to false. }
if defined rsCMLOX { set rsCMLOX:enabled to true. }
if defined rsCMCH4 { set rsCMCH4:enabled to true. }
if defined rsBDLOX { set rsBDLOX:enabled to true. }
if defined rsBDCH4 { set rsBDCH4:enabled to true. }
if defined rsDPLOX { set rsDPLOX:enabled to true. }
if defined rsDPCH4 { set rsDPCH4:enabled to true. }

// Kill throttle
lock throttle to 0.

// Actuate out sea level raptors
for ptRaptorSL in arrRaptorSL_sle { ptRaptorSL:activate. }
wait 1.
for mdRSL_actuate in arrRSL_actuate_sle {
	mdRSL_actuate:setfield("actuate out", true).
}
wait 1.

// Lock gimbal on sea level Raptors
for mdRSL_gimbal in arrRSL_gimbal_sle {
	mdRSL_gimbal:doaction("lock gimbal", true).
}

// Shut down sea level Raptors
for ptRaptorSL in arrRaptorSL_sle { ptRaptorSL:shutdown. }

// Shut down vacuum Raptors
for ptRaptorVac in arrRaptorVac_sle { ptRaptorVac:shutdown. }

// Set flaps to launch position
for mdSSFlap in arrSSFlaps_sle {
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

write_console_sle().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

if hastarget {
	if target_is_body(target) {
		lock degTarDlt to abs(abs(target:orbit:lan - SHIP:orbit:lan) - degOffInc).
	} else {
		lock degTarDlt to target:orbit:lan - SHIP:orbit:lan.
	}
} else {
	lock degTarDlt to 0.
}

if SHIP:status = "PRELAUNCH" {

	// Stage: PRE-LAUNCH
	until SHIP:verticalspeed > 0.1 {
		write_screen_sle("Pre-launch", false).
	}

	if hastarget {
		if target_is_vessel(target) {
			lock degTarDlt to target:orbit:lan - SHIP:orbit:lan.
		}
	}

	// Stage: ON BOOSTER
	until onBooster = false {
		write_screen_sle("On Booster", true).
		set onBooster to false.
		for pt in SHIP:parts {
			if pt:name:startswith("SEP.B4.INTER") { set onBooster to true. }
			if pt:name:startswith("SEP.22.BOOSTER.INTER") { set onBooster to true. }
			if pt:name:startswith("SEP.23.BOOSTER.INTEGRATED") { set onBooster to true. }
		}
	}

	// Stage: HOT STAGE
	lock throttle to 1.
	for ptRaptorVac in arrRaptorVac_sle { ptRaptorVac:activate. }
	local timeStage is time:seconds + 1.
	until time:seconds > timeStage {
		write_screen_sle("Hot stage", true).
	}
	for ptRaptorSL in arrRaptorSL_sle { ptRaptorSL:activate. }
	set timeStage to time:seconds + 4.
	until time:seconds > timeStage {
		write_screen_sle("Hot stage", true).
	}
	// Actuate in sea level raptors
	for mdRSL_actuate in arrRSL_actuate_sle {
		mdRSL_actuate:setfield("actuate out", false).
	}
	set timeStage to time:seconds + 2.
	until time:seconds > timeStage {
		write_screen_sle("Hot stage", true).
	}
	// Free gimbal on sea level Raptors
	for mdRSL_gimbal in arrRSL_gimbal_sle {
		mdRSL_gimbal:doaction("free gimbal", true).
	}

	// Stage: ASCENT
	//lock steering to lookDirUp(heading(heading_of_vector(prograde:vector) - degYawTrg, degPitTrg + vang(prograde:vector, vxcl(up:vector, prograde:vector))):vector, up:vector).
	lock steering to lookDirUp(heading(heading_of_vector(prograde:vector) - degTarDlt, degPitTrg + vang(prograde:vector, vxcl(up:vector, prograde:vector))):vector, up:vector).
	set mpsVrtTrg to calculate_tvspd().

	until sToTrgVel < sToOrbIns {
		write_screen_sle("Ascent", true).
		set mpsVrtTrg to calculate_tvspd().
		set degPitTrg to calculate_pitch().
		set degYawTrg to 0 - pidYaw:update(time:seconds, degTarDlt).
	}

	// Stage: ORBITAL INSERTION
	until SHIP:orbit:apoapsis > (mAPTrg * 0.9) {
		write_screen_sle("Orbital insertion", true).
		set mpsVrtTrg to calculate_tvspd().
		set degPitTrg to calculate_pitch().
		set degYawTrg to 0 - pidYaw:update(time:seconds, degTarDlt).
	}

	// Stage: TRIM
	set degYawTrg to 0.
	set degPitTrg to 0.
	lock throttle to 0.4.

	until SHIP:orbit:apoapsis > (mAPTrg * 0.97) {
		write_screen_sle("Trim        ", true).
	}

	lock throttle to 0.
	rcs on.
	set SHIP:control:fore to 1.

	until SHIP:orbit:apoapsis > (mAPTrg * 0.999) {
		write_screen_sle("Trim", true).
		set SHIP:control:fore to max(1, (mAPTrg - SHIP:orbit:apoapsis) / (mAPTrg * 0.97)).
	}

}

// Stage: COAST TO APOGEE
set ag7 to true.
set ag9 to true.
for ptRaptorSL in arrRaptorSL_sle { ptRaptorSL:shutdown. }
for ptRaptorVac in arrRaptorVac_sle { ptRaptorVac:shutdown. }
for mdSP in arrSPModules_sle { mdSP:doaction("extend solar panel", true). }
set SHIP:control:fore to 0.

lock steering to lookDirUp(prograde:vector, up:vector).
local timOrient is time:seconds + 30.
until time:seconds > timOrient {
	write_screen_sle("Orient for coast", true).
}
unlock steering.
rcs off.
sas on.
wait 0.2.
set sasMode to "Prograde".

until SHIP:orbit:eta:apoapsis < 4 {
	write_screen_sle("Coast to Apogee", true).
}

// Stage: CIRCULARISING
for ptRaptorVac in arrRaptorVac_sle { ptRaptorVac:activate. }
lock throttle to 1.
rcs on.

until (SHIP:orbit:apoapsis + SHIP:orbit:periapsis) > (mAPTrg + SHIP:altitude) {
	write_screen_sle("Circularising", true).
}

// Stage: ORBIT ATTAINED
for ptRaptorVac in arrRaptorVac_sle { ptRaptorVac:shutdown. }
lock throttle to 0.
rcs off.

local timeWait is time:seconds + 1.
until time:seconds > timeWait {
	write_screen_sle("Orbit attained", true).
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
		write_screen_sle("Orient for coast", true).
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
