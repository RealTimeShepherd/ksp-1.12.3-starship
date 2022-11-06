
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Logfile
global log is "Telemetry/ss_edl_earth_log.csv".

// Define Boca Chica catch tower - long term get this from target info
global pad is latlng(25.9669968, -97.1416771). // Tower Catch point - BC OLIT 1
global degPadEnt is 262.
global mAltWP1 is 600. // Waypoints - ship will travel through these altitudes
global mAltWP2 is 300.
global mAltWP4 is 200.5. // Tower Catch altitude - BC OLIT 1
global mAltAP1 is 300. // Aim points - ship will aim at these altitudes
global mAltAP2 is 230.
global mAltAP3 is 200.

// Ratio of fuel between header and body for balanced EDL
global ratFlHDBD is 0.1.

// Long range pitch tracking
global cnsLrp is (SHIP:mass / 12) + 89.
global mLrpTrg is 12200.
global ratLrp is 0.011.
global qrcLrp is 0.

// Short range pitch tracking
global cnsSrp is 0.017. // surface m gained per m lost in altitude for every degree of pitch forward
global mSrpTrgDst is 200.
global mSrpTrgAlt is 1200.

// Set min/max ranges
global degPitMax is 80.
global degPitMin is 40.

// Set target values
global degPitTrg is 0.
global degYawTrg is 0.

// stage thresholds
global kpaMeso is 0.5.
global mAltStrt is 50000.
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
global mAltFnB is 2400.
global kNThrMin is 1500.
global degDflMax is 5.
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

function write_console { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:        " at (0, 0).
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

	deletePath(log).
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
	log logline to log.
}

function write_screen { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "        " at (14, 0).
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
		log logline to log.
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
ptRaptorSLA:shutdown.
ptRaptorSLB:shutdown.
ptRaptorSLC:shutdown.

// Shut down vacuum Raptors
for ptRaptorVac in arrRaptorVac { ptRaptorVac:shutdown. }

// Set flaps to entry position
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

write_console().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

// Stage: BALANCE FUEL
until ((abs((rsHDLOX:amount / rsBDLOX:amount) - ratFlHDBD) < 0.01) and (abs((rsHDCH4:amount / rsBDCH4:amount) - ratFlHDBD) < 0.01)) {
	write_screen("Balance fuel", false).
	if (rsHDLOX:amount / rsBDLOX:amount) > ratFlHDBD {
		set trnLOXH2B to transfer("lqdOxygen", ptSSHeader, ptSSBody, rsHDLOX:amount / 20).
		if (trnLOXH2B:active = false) { set trnLOXH2B:active to true. }
	} else {
		set trnLOXB2H to transfer("lqdOxygen", ptSSBody, ptSSHeader, rsHDLOX:amount / 20).
		if (trnLOXB2H:active = false) { set trnLOXB2H:active to true. }
	}
	if (rsHDCH4:amount / rsBDCH4:amount) > ratFlHDBD {
		set trnCH4H2B to transfer("LqdMethane", ptSSHeader, ptSSBody, rsHDCH4:amount / 20).
		if (trnCH4H2B:active = false) { set trnCH4H2B:active to true. }
	} else {
		set trnCH4B2H to transfer("LqdMethane", ptSSBody, ptSSHeader, rsHDCH4:amount / 20).
		if (trnCH4B2H:active = false) { set trnCH4B2H:active to true. }
	}
}

// Stage: THERMOSPHERE
rcs on.
lock steering to lookdirup(heading(pad:heading, max(min(degPitTrg, degPitMax), degPitMin)):vector, SHIP:srfRetrograde:vector).

until kpaDynPrs > kpaMeso {
	write_screen("Thermosphere (RCS)", false).
	set degPitTrg to calculate_lrp().
}

// Stage: MESOSPHERE
rcs off.
unlock steering.
set pidPit to pidLoop(arrPitMeso[0], arrPitMeso[1], arrPitMeso[2]).
set pidYaw to pidLoop(arrYawMeso[0], arrYawMeso[1], arrYawMeso[2]).
set pidRol to pidLoop(arrRolMeso[0], arrRolMeso[1], arrRolMeso[2]).

until SHIP:altitude < mAltStrt {
	write_screen("Mesosphere (Flaps)", true).
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
	write_screen("Stratosphere (Flaps)", true).
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
	write_screen("Troposphere (Flaps)", true).
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
	write_screen("Flare & Drop (Flaps)", true).
	set degPitTrg to calculate_srp().
	set degYawTrg to 0 - (degBerPad * 2).
	calculate_csf().
	set_flaps().
}

// Stage: BELLY FLOP
set pidPit to pidLoop(arrPitFlop[0], arrPitFlop[1], arrPitFlop[2]).
set pidYaw to pidLoop(arrYawFlop[0], arrYawFlop[1], arrYawFlop[2], -2, 2).
set pidRol to pidLoop(arrRolFlop[0], arrRolFlop[1], arrRolFlop[2], -10, 10).

until SHIP:altitude < mAltFnB {
	write_screen("Bellyflop (Flaps)", true).
	set degPitTrg to calculate_srp().
	set degYawTrg to 0 - (degBerPad * 2).
	calculate_csf().
	set_flaps().
}

// Stage: FLIP & BURN
mdSSBDRCS:setfield("rcs", false).
rcs on.
set degPitTrg to 170.
ptRaptorSLA:activate.
ptRaptorSLB:activate.
ptRaptorSLC:activate.
lock throttle to 1.
set SHIP:control:yaw to 0.
set SHIP:control:roll to 0.

until ptRaptorSLA:thrust > kNThrMin {
	write_screen("Flip & Burn", true).
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
lock mpsVrtTrg to (mAltTrg - SHIP:altitude) / 5.

until SHIP:verticalspeed > mpsVrtTrg {
	write_screen("Landing Burn", true).
}

// Stage: BALANCE THROTTLE
lock mpsVrtTrg to (mAltTrg - SHIP:altitude) / 5.
lock throttle to max(0.0001, pidThr:update(time:seconds, SHIP:verticalspeed - mpsVrtTrg)). // Attempt to hover at mAltTrg

until SHIP:altitude < mAltWP1 {
	write_screen("Balance Throttle", true).
}

// Stage: TOWER APPROACH
set mAltTrg to mAltAP2.
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
	write_screen("Tower Approach", true).
	set_rcs_translate(vecThr:mag, degThrHed).
}

// Stage: DESCENT
lock steering to lookDirUp(up:vector, heading(degPadEnt, 0):vector).
set mAltTrg to mAltAP3.

until SHIP:altitude < mAltWP4 {
	write_screen("Descent", true).
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
write_screen("Tower Catch", true).

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
