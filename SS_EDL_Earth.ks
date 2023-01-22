//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       SS_EDL_Earth
// Translation: StarShip - Entry Descent and Landing - Earth
// Description: This script takes the StarShip from a decaying Earth orbit through the following stages
// Descend:     Wait for the StarShip to touch the top of the atmosphere
// Balance:     Move fuel about within the vehicle to achieve a balanced craft for easier flap control
// High atmos:  Maintain attitude with RCS while atmosphere is too thin to use flaps
// Navigate:    Control the vehicle entirely with the flaps, calculating pitch and yaw to navigate back to base
// Bellyflop:   Close to the tower, use the flaps to guide the falling ship towards the tower
// Flip & burn: In the last couple of km, flip to vertical and use the sea level raptors to guide the ship to the tower
// Catch:       The tower catches the StarShip in Mechazilla for a safe return home

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Logfile
global log_see is "Telemetry/ss_edl_earth_log.csv".

// Define Boca Chica catch tower - long term get this from target info
// Target info: Geoposition = 25.9669602, -97.1418428 | heading_of_vector(SHIP:facing:vector). = 355.3
// Probably add 90 deg to the heading and add a short vector along that axis for the catch point
// Then remove 90 deg from the heading to get the entry direction

global pad is latlng(25.9669968, -97.1416771). // Tower Catch point - BC OLIT 1
global degPadEnt is 262.
global mAltWP1 is 400. // Waypoints - ship will travel through these altitudes - originally 600
global mAltWP2 is 250. // Originally 300
global mAltRad is 42. // Caught when SHIP:bounds:bottomaltradar is less than this value
global mAltAP1 is 300. // Aim points - ship will aim at these altitudes
global mAltAP2 is 230.
global mAltAP3 is 200.

// Positioning fuel between header and body for balanced EDL
global mRapA2COM is 23.9. // The distance from the vessel centre of mass to the Raptor 'A' engine for a balanced craft

// Long range pitch tracking
// Ship mass of 151 - Trying 88
// Ship mass of 131.7 - 86 works fine (Header tank only)
global cnsLrp is (11 * SHIP:mass / 60) + 73. // Jury is still out regarding this value - suspect will not work for high mass
//global cnsLrp is (SHIP:mass / 12) + 88. // 89 - original - 86 works better for low mass StarShip
global mLrpTrg is 12200.
global ratLrp is 0.011.
global qrcLrp is 0.

// Short range pitch tracking - multiple tests make 0.016 look like the best all rounder, masses from 130 - 160t
global cnsSrp is 0.016.
//global cnsSrp is (SHIP:mass / 20000) + 0.0095. // surface m gained per m lost in altitude for every degree of pitch forward
//global cnsSrp is 0.017. // surface m gained per m lost in altitude for every degree of pitch forward, 17 - original
global mSrpTrgDst is 200.
global mSrpTrgAlt is 1200.

// Set min/max ranges
global degPitMax is 80.
global degPitMin is 40.

// Set target values
global degPitTrg is 0.
global degYawTrg is 0.

// Stage thresholds
global mAltPitch is 250000. // Switch SAS mode to slowly pitch back at this altitude
global mAltOuter is 140000.
global mAltUpper is 100000.
global mAltTherm is 88000.
global kpaMeso is 0.5.
global mAltStrat is 50000.
global mpsTrop is 1600.

// PID controller values
global arrPitMeso is list (1.5, 0.1, 3).
global arrYawMeso is list (3, 0.001, 5).
global arrRolMeso is list (2, 0.001, 4).

global arrPitStrt is list (1.5, 0.1, 3).
global arrYawStrt is list (3, 0.001, 3).
global arrRolStrt is list (2, 0.001, 2).

global arrPitTrop is list (1.5, 0.1, 3.5).
global arrYawTrop is list (1.2, 0.001, 4).
global arrRolTrop is list (0.6, 0.1, 4).

global arrPitFlre is list (1.5, 0.1, 3.5).
global arrYawFlre is list (0.9, 0.001, 4).
global arrRolFlre is list (0.4, 0.1, 4).

global arrPitFlop is list (1, 0.1, 3.5).
global arrYawFlop is list (1.2, 0.001, 4).
global arrRolFlop is list (0.6, 0.001, 4).

global pidPit is pidLoop(0, 0, 0).
set pidPit:setpoint to 0.
global pidYaw is pidLoop(0, 0, 0).
set pidYaw:setpoint to 0.
global pidRol is pidLoop(0, 0, 0).
set pidRol:setpoint to 0.

// RCS PID controller for flip & burn
global pidRCS is pidLoop(1, 0.1, 2.5, -1, 1).
set pidRCS:setpoint to 0.

// Flaps initial trim and control deflections
global degFlpTrm is 45.
global degFL is 0.
global degFR is 0.
global degAL is 0.
global degAR is 0.
global degPitCsf is 0.
global degYawCsf is 0.
global degRolCsf is 0.

global arrSSFlaps is list().
global arrRaptorVac is list().

// Propulsive landing
global kNThrMin is 1500.
global degDflMax is 2. // 5 original
global mAltTrg is 0.
global pidThr is pidLoop(0.3, 0.2, 0, 0.01, 1).
set pidThr:setpoint to 0.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("SEP.S20.HEADER") { set ptSSHeader to pt. }
	if pt:name:startswith("SEP.S20.CREW") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.S20.TANKER") { set ptSSCommand to pt. }
	if pt:name:startswith("SEP.S20.BODY") { set ptSSBody to pt. }
	if pt:name:startswith("SEP.S20.FWD.LEFT") { set ptFlapFL to pt. }
	if pt:name:startswith("SEP.S20.FWD.RIGHT") { set ptFlapFR to pt. }
	if pt:name:startswith("SEP.S20.AFT.LEFT") { set ptFlapAL to pt. }
	if pt:name:startswith("SEP.S20.AFT.RIGHT") { set ptFlapAR to pt. }
	if pt:name:startswith("SEP.RAPTOR.VAC") { arrRaptorVac:add(pt). }
	if pt:name:startswith("SEP.RAPTOR.SL") {
		if vdot(ship:facing:topvector, pt:position) > 0 {
			set ptRaptorSLA to pt.
		} else {
			if vdot(ship:facing:starvector, pt:position) > 0 {
				set ptRaptorSLB to pt.
			} else {
				set ptRaptorSLC to pt.
			}
		}
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

lock headSS to vang(north:vector, SHIP:srfPrograde:vector).
lock vecPad to vxcl(up:vector, pad:position).
lock degBerPad to relative_bearing(headSS, pad:heading).
lock mPad to pad:distance.
lock mSrf to (vecPad - vxcl(up:vector, SHIP:geoposition:position)):mag.
lock kpaDynPrs to SHIP:q * constant:atmtokpa.
lock degPitAct to get_pit(srfprograde).
lock degYawAct to get_yaw(SHIP:up).
lock degRolAct to get_roll(SHIP:up).
lock mpsVrtTrg to 0.
if defined rsCMCH4 {
	lock klProp to rsHDCH4:amount + rsCMCH4:amount + rsBDCH4:amount.
} else {
	lock klProp to rsHDCH4:amount + rsBDCH4:amount.
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_see { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:" at (0, 0).
	print "----------------------------" at (0, 1).
	print "Altitude:                  m" at (0, 2).
	print "Dyn pressure:            kpa" at (0, 3).
	print "----------------------------" at (0, 4).
	print "Hrz speed:               m/s" at (0, 5).
	print "Vrt speed:               m/s" at (0, 6).
	print "Air speed:               m/s" at (0, 7).
	print "----------------------------" at (0, 8).
	print "Pad distance:             km" at (0, 9).
	print "Srf distance:              m" at (0, 10).
	print "Target pitch:            deg" at (0, 11).
	print "Actual pitch:            deg" at (0, 12).
	print "----------------------------" at (0, 13).
	print "Pad bearing:             deg" at (0, 14).
	print "Target yaw:              deg" at (0, 15).
	print "Actual yaw:              deg" at (0, 16).
	print "Actual roll:             deg" at (0, 17).
	print "----------------------------" at (0, 18).
	print "Propellant:                l" at (0, 19).
	print "Throttle:                  %" at (0, 20).
	print "Target VSpd:             mps" at (0, 21).

	deletePath(log_see).
	local logline is "Time,".
	set logline to logline + "Phase,".
	set logline to logline + "Altitude,".
	set logline to logline + "Dyn pressure,".
	set logline to logline + "Hrz speed,".
	set logline to logline + "Vrt speed,".
	set logline to logline + "Air speed,".
	set logline to logline + "Pad distance,".
	set logline to logline + "Srf distance,".
	set logline to logline + "Target pitch,".
	set logline to logline + "Actual pitch,".
	set logline to logline + "Pad bearing,".
	set logline to logline + "Target yaw,".
	set logline to logline + "Actual yaw,".
	set logline to logline + "Actual roll,".
	set logline to logline + "Propellant,".
	set logline to logline + "Throttle,".
	set logline to logline + "Target VSpd,".
	log logline to log_see.

}

function write_screen_see { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "        " at (7, 0).
	// print "----------------------------".
	print round(SHIP:altitude, 0) + "    " at (14, 2).
	print round(kpaDynPrs, 2) + "    " at (14, 3).
	// print "----------------------------".
	print round(SHIP:groundspeed, 0) + "    " at (14, 5).
	print round(SHIP:verticalspeed, 0) + "    " at (14, 6).
	print round(SHIP:airspeed, 0) + "    " at (14, 7).
	// print "----------------------------".
	print round(mPad / 1000, 0) + "    " at (14, 9).
	print round(mSrf, 0) + "    " at (14, 10).
	print round(degPitTrg, 2) + "    " at (14, 11).
	print round(degPitAct, 2) + "    " at (14, 12).
	// print "----------------------------".
	print round(degBerPad, 2) + "    " at (14, 14).
	print round(degYawTrg, 2) + "    " at (14, 15).
	print round(degYawAct, 2) + "    " at (14, 16).
	print round(degRolAct, 2) + "    " at (14, 17).
	// print "----------------------------".
	print round(klProp, 0) + "    " at (14, 19).
	print round(throttle * 100, 2) + "    " at (14, 20).
	print round(mpsVrtTrg, 0) + "    " at (14, 21).

	if writelog = true {
		local logline is time:seconds + ",".
		set logline to logline + phase + ",".
		set logline to logline + round(SHIP:altitude, 0) + ",".
		set logline to logline + round(kpaDynPrs, 2) + ",".
		set logline to logline + round(SHIP:groundspeed, 0) + ",".
		set logline to logline + round(SHIP:verticalspeed, 0) + ",".
		set logline to logline + round(SHIP:airspeed, 0) + ",".
		set logline to logline + round(mPad, 0) + ",".
		set logline to logline + round(mSrf, 0) + ",".
		set logline to logline + round(degPitTrg, 2) + ",".
		set logline to logline + round(degPitAct, 2) + ",".
		set logline to logline + round(degBerPad, 2) + ",".
		set logline to logline + round(degYawTrg, 2) + ",".
		set logline to logline + round(degYawAct, 2) + ",".
		set logline to logline + round(degRolAct, 2) + ",".
		set logline to logline + round(klProp, 0) + ",".
		set logline to logline + round(throttle * 100, 2) + ",".
		set logline to logline + round(mpsVrtTrg, 0) + ",".
		log logline to log_see.
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

function get_roll { // Get current roll
	parameter rDirection.
	local fcgShip is SHIP:facing.
	return 0 - arcTan2(-vDot(fcgShip:starvector, rDirection:forevector), vDot(fcgShip:topvector, rDirection:forevector)).
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

function calculate_lrp { // Calculate the desired pitch for long range tracking
	set mLrpTot to (mPad - mLrpTrg).
	set qrcLrp to 1000 * ((mLrpTot / (SHIP:groundspeed * (SHIP:altitude / 1000) * (SHIP:altitude / 1000))) - ((mLrpTot / 1000) * (ratLrp / 1000))).
	return max(min(cnsLrp - qrcLrp, degPitMax), degPitMin).
}

function calculate_srp { // Calculate the desired pitch for short range tracking
	set kmTotAlt to (SHIP:altitude - mSrpTrgAlt) / 1000.
	set knTotDst to (mSrf - mSrpTrgDst) / 1000.
	return max(min(90 - ((knTotDst / kmTotAlt) / cnsSrp), degPitMax), degPitMin).
}

function calculate_csf { // Calculate the pitch, yaw and roll control surface deflections
	set degPitCsf to pidPit:update(time:seconds, degPitAct - degPitTrg).
	set degYawCsf to pidYaw:update(time:seconds, degYawAct - degYawTrg).
	set degRolCsf to pidRol:update(time:seconds, degRolAct).
}

function set_flaps { // Sets the angle of the flaps combining the trim and the total control surface deflection
	// Set initial trim
	set degFL to degFlpTrm.
	set degFR to degFlpTrm.
	set degAL to degFlpTrm.
	set degAR to degFlpTrm.
	// Add pitch deflection
	set degFL to degFL - degPitCsf.
	set degFR to degFR - degPitCsf.
	set degAL to degAL + degPitCsf.
	set degAR to degAR + degPitCsf.
	// Add yaw deflection
	set degFL to degFL - degYawCsf.
	set degFR to degFR + degYawCsf.
	set degAL to degAL + degYawCsf.
	set degAR to degAR - degYawCsf.
	// Add roll deflection
	set degFL to degFL + degRolCsf.
	set degFR to degFR - degRolCsf.
	set degAL to degAL + degRolCsf.
	set degAR to degAR - degRolCsf.
	// Set final control surface deflection
	mdFlapFLCS:setfield("deploy angle", max(degFL, 0)).
	mdFlapFRCS:setfield("deploy angle", max(degFR, 0)).
	mdFlapALCS:setfield("deploy angle", max(degAL, 0)).
	mdFlapARCS:setfield("deploy angle", max(degAR, 0)).
}

function fill_header {
	local trnLOXCM is transfer("lqdOxygen", ptSSBody, ptSSHeader, rsBDLOX:amount).
	local trnCH4CM is transfer("LqdMethane", ptSSBody, ptSSHeader, rsBDCH4:amount).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
}

function empty_header {
	local trnLOXCM is transfer("lqdOxygen", ptSSHeader, ptSSBody, rsHDLOX:amount).
	local trnCH4CM is transfer("LqdMethane", ptSSHeader, ptSSBody, rsHDCH4:amount).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
}

function empty_command {
	local trnLOXCM is transfer("lqdOxygen", ptSSCommand, ptSSBody, rsHDLOX:amount).
	local trnCH4CM is transfer("LqdMethane", ptSSCommand, ptSSBody, rsHDCH4:amount).
	if (trnLOXCM:active = false) { set trnLOXCM:active to true. }
	if (trnCH4CM:active = false) { set trnCH4CM:active to true. }
}

function set_rcs_translate { // Set RCS translation values to target tower
	parameter mag.
	parameter deg.
	set SHIP:control:top to min(1, mag) * cos(deg - degPadEnt).
	set SHIP:control:starboard to 0 - min(1, mag) * sin(deg - degPadEnt).
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

// Switch off RCS
rcs off.

// Switch off SAS
sas off.

// Unlock steering
unlock steering.

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
ptRaptorSLA:shutdown.
ptRaptorSLB:shutdown.
ptRaptorSLC:shutdown.

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

write_console_see().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

// Stage: COAST TO ENTRY
set navMode to "Surface".
lock steering to lookDirUp(prograde:vector, up:vector).

until SHIP:altitude < mAltPitch {
	write_screen_see("Coast to entry", false).
}

// Stage: PITCH BACK
unlock steering.
set ag7 to false.
sas on.
wait 0.1.
set sasMode to "Stability".

until SHIP:altitude < mAltOuter {
	write_screen_see("Pitch back", false).
}

if SHIP:altitude > mAltUpper {
	// Stage: BALANCE FUEL
	empty_header().
	empty_command().

	local timeFuel is time:seconds + 5.
	until time:seconds > timeFuel {
		write_screen_see("Empty header", false).
	}
	until ptRaptorSLA:position:mag > mRapA2COM or round(rsHDLOX:capacity, 0) = round(rsHDLOX:amount, 0) or rsBDLOX:amount = 0 {
		write_screen_see("Fill header", false).
		set trnLOXB2H to transfer("lqdOxygen", ptSSBody, ptSSHeader, 57).
		if (trnLOXB2H:active = false) { set trnLOXB2H:active to true. }
		set trnCH4B2H to transfer("LqdMethane", ptSSBody, ptSSHeader, 43).
		if (trnCH4B2H:active = false) { set trnCH4B2H:active to true. }
		wait 0.1.
	}
	until ptRaptorSLA:position:mag > mRapA2COM or rsBDLOX:amount = 0 {
		write_screen_see("Fill command", false).
		set trnLOXB2H to transfer("lqdOxygen", ptSSBody, ptSSCommand, 57).
		if (trnLOXB2H:active = false) { set trnLOXB2H:active to true. }
		set trnCH4B2H to transfer("LqdMethane", ptSSBody, ptSSCommand, 43).
		if (trnCH4B2H:active = false) { set trnCH4B2H:active to true. }
		wait 0.1.
	}
}

// Stage: UPPER ATMOSPHERE
until SHIP:altitude < mAltTherm {
	write_screen_see("Upper atmos.", false).
}

// Stage: THERMOSPHERE
sas off.
for mdSSFlap in arrSSFlaps {
	// Disable manual control
	mdSSFlap:setfield("pitch", true).
	mdSSFlap:setfield("yaw", true).
	mdSSFlap:setfield("roll", true).
	// Set starting angles
	mdSSFlap:setfield("deploy angle", degFlpTrm).
	// deploy control surfaces
	mdSSFlap:setfield("deploy", true).
}
rcs on.
lock steering to lookdirup(heading(pad:heading, max(min(degPitTrg, degPitMax), degPitMin)):vector, SHIP:srfRetrograde:vector).

until kpaDynPrs > kpaMeso {
	write_screen_see("Thermosphere (RCS)", false).
	set degPitTrg to calculate_lrp().
}

// Stage: MESOSPHERE
rcs off.
unlock steering.
set pidPit to pidLoop(arrPitMeso[0], arrPitMeso[1], arrPitMeso[2]).
set pidYaw to pidLoop(arrYawMeso[0], arrYawMeso[1], arrYawMeso[2]).
set pidRol to pidLoop(arrRolMeso[0], arrRolMeso[1], arrRolMeso[2]).

until SHIP:altitude < mAltStrat {
	write_screen_see("Mesosphere (Flaps)", true).
	set degPitTrg to calculate_lrp().
	set degYawTrg to kpaDynPrs * (0 - degBerPad).
	calculate_csf().
	set_flaps().
}

// Stage: STRATOSPHERE
set pidPit to pidLoop(arrPitStrt[0], arrPitStrt[1], arrPitStrt[2]).
set pidYaw to pidLoop(arrYawStrt[0], arrYawStrt[1], arrYawStrt[2]).
set pidRol to pidLoop(arrRolStrt[0], arrRolStrt[1], arrRolStrt[2]).

until SHIP:groundspeed < mpsTrop {
	write_screen_see("Stratosphere (Flaps)", true).
	set degPitTrg to calculate_lrp().
	set degYawTrg to kpaDynPrs * (0 - degBerPad).
	calculate_csf().
	set_flaps().
}

// Stage: TROPOSPHERE
set pidPit to pidLoop(arrPitTrop[0], arrPitTrop[1], arrPitTrop[2]).
set pidYaw to pidLoop(arrYawTrop[0], arrYawTrop[1], arrYawTrop[2], -10, 10).
set pidRol to pidLoop(arrRolTrop[0], arrRolTrop[1], arrRolTrop[2], -10, 10).

until calculate_srp() > calculate_lrp() {
	write_screen_see("Troposphere (Flaps)", true).
	set degPitTrg to calculate_lrp().
	set degYawTrg to kpaDynPrs * (0 - degBerPad).
	calculate_csf().
	set_flaps().
}

// Stage: FLARE & DROP
lock degYawAct to get_yaw(SHIP:prograde).
set pidPit to pidLoop(arrPitFlre[0], arrPitFlre[1], arrPitFlre[2]).
set pidYaw to pidLoop(arrYawFlre[0], arrYawFlre[1], arrYawFlre[2], -10, 10).
set pidRol to pidLoop(arrRolFlre[0], arrRolFlre[1], arrRolFlre[2], -10, 10).

until abs(SHIP:groundspeed / SHIP:verticalspeed) < 0.58 {
	write_screen_see("Flare & Drop (Flaps)", true).
	set degPitTrg to calculate_srp().
	set degYawTrg to 0 - (degBerPad * 2).
	calculate_csf().
	set_flaps().
}

// Stage: BELLY FLOP
set degPitMax to 100.
set degPitMin to 60.
set pidPit to pidLoop(arrPitFlop[0], arrPitFlop[1], arrPitFlop[2]).
set pidYaw to pidLoop(arrYawFlop[0], arrYawFlop[1], arrYawFlop[2], -2, 2).
set pidRol to pidLoop(arrRolFlop[0], arrRolFlop[1], arrRolFlop[2], -10, 10).
lock mpsVrtTrg to (mAltTrg - SHIP:altitude) / 5.

until abs(SHIP:verticalspeed) > abs(mpsVrtTrg / 3) {
	write_screen_see("Bellyflop (Flaps)", true).
	set degPitTrg to calculate_srp().
	set degYawTrg to 0 - (degBerPad * 2).
	calculate_csf().
	set_flaps().
}

// Stage: FLIP & BURN
empty_header().
empty_command().
mdSSBDRCS:setfield("rcs", false).
rcs on.
set degPitTrg to 170.
ptRaptorSLA:activate.
ptRaptorSLB:activate.
ptRaptorSLC:activate.
lock throttle to 1.
set SHIP:control:yaw to 0.
set SHIP:control:roll to 0.

// set SHIP:control:pitch to 1.
until ptRaptorSLA:thrust > kNThrMin {
	write_screen_see("Flip & Burn", true).
	set SHIP:control:pitch to pidRCS:update(time:seconds, degPitAct - degPitTrg).
}

// Stage: LANDING BURN
set SHIP:control:pitch to 0.
mdFlapFLCS:setfield("deploy angle", 0).
mdFlapFRCS:setfield("deploy angle", 0).
mdFlapALCS:setfield("deploy angle", 90).
mdFlapARCS:setfield("deploy angle", 90).
set mAltTrg to mAltAP1.
lock degVAng to vAng(srfPrograde:vector, pad:position).
lock axsProDes to vcrs(srfPrograde:vector, pad:position).
lock rotProDes to angleAxis(max(0 - degDflMax, degVAng * (0 - 8) - 1), axsProDes).
lock steering to lookdirup(rotProDes * srfRetrograde:vector, heading(degPadEnt, 0):vector).

until SHIP:verticalspeed > mpsVrtTrg {
	write_screen_see("Landing Burn", true).
}

// Stage: BALANCE THROTTLE
lock steering to lookDirUp(srfRetrograde:vector, heading(degPadEnt, 0):vector).
lock mpsVrtTrg to (mAltTrg - SHIP:altitude) / 5.
lock throttle to max(0.4, pidThr:update(time:seconds, SHIP:verticalspeed - mpsVrtTrg)). // Attempt to hover at mAltTrg

until SHIP:altitude < mAltWP1 or SHIP:verticalspeed > -20 {
	write_screen_see("Balance Throttle", true).
}

// Stage: TOWER APPROACH
set mAltTrg to mAltAP2.
local mpsStart is SHIP:verticalspeed.
local mpsEnd is -5.
local mAltStart is SHIP:altitude.
lock mpsVrtTrg to mpsEnd + (mpsStart * ((SHIP:altitude - mAltTrg) / (mAltStart - mAltTrg))).
if SHIP:mass > 180 {
	ptRaptorSLA:shutdown.
} else {
	ptRaptorSLB:shutdown.
	ptRaptorSLC:shutdown.
}
lock vecSrfVel to vxcl(up:vector, SHIP:velocity:surface).
set sTTR to 0.01 + min(5, mSrf / 10).
lock vecThr to ((vecPad / sTTR) - vecSrfVel).
lock degThrHed to heading_of_vector(vecThr).
lock steering to lookdirup(vecThr + (300 * up:vector), heading(degPadEnt, 0):vector).
unlock rotProDes.
unlock axsProDes.
unlock degVAng.

until mSrf < 5 and SHIP:groundspeed < 3 and SHIP:altitude < mAltWP2 {
	write_screen_see("Tower Approach", true).
	set_rcs_translate(vecThr:mag, degThrHed).
}

// Stage: DESCENT
lock steering to lookDirUp(up:vector, heading(degPadEnt, 0):vector).
set mAltTrg to mAltAP3.
local B is SHIP:bounds. // get the :bounds suffix ONCE.

until B:bottomaltradar < mAltRad {
	write_screen_see("Descent", true).
	set_rcs_translate(vecThr:mag, degThrHed).
}

// Stage: TOWER CATCH
lock throttle to 0.
set SHIP:control:top to 0.
set SHIP:control:starboard to 0.
unlock steering.
rcs off.
ptRaptorSLA:shutdown.
ptRaptorSLB:shutdown.
ptRaptorSLC:shutdown.
write_screen_see("Tower Catch", true).

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
