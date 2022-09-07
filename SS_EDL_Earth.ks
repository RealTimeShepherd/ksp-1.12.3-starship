
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Set landing target of SpaceX Boca Chica catch tower
global pad is latlng(26.966961, -97.141841). // Aim point - BC
//global pad is latlng(26.0385053, -97.1530816). // Aim point - BC
global degPadEnt is 262.

// Ratio of fuel between header and body for balanced EDL
global ratFlHDBD is 0.2.

// Long range pitch tracking
// 105 worked for 264 starting mass - 95 worked for 144 starting mass
// Solution is to make cnsLrp = (Mass / 12) + 83
global cnsLrp is (SHIP:mass / 12) + 83.
global mLrpTrg is 12000.
global ratLrp is 0.011.
global qrcLrp is 0.

// Short range pitch tracking
global cnsSrp is 0.017. // surface m gained per m lost in altitude for every degree of pitch forward
global mSrpTrgDst is 0.
global mSrpTrgAlt is 1200.

// Set min/max ranges
global degPitMax is 80.
global degPitMin is 40.

// Set target values
global degPitTrg is 0.
global degYawTrg is 0.

// Dynamic pressure thresholds
global kpaMeso is 0.5.
global kpaStrt is 8.88.

// PID controller values
global arrPitMeso is list (1.5, 0.1, 3).
global arrYawMeso is list (3, 0.001, 5).
global arrRolMeso is list (2, 0.001, 4).

global arrPitStrt is list (1.5, 0.1, 3).
global arrYawStrt is list (3, 0.001, 5).
global arrRolStrt is list (2, 0.001, 4).

global arrPitTrop is list (1.5, 0.1, 3.5).
global arrYawTrop is list (1.2, 0.001, 2).
global arrRolTrop is list (0.6, 0.1, 1).

global pidPit is pidLoop(0, 0, 0).
set pidPit:setpoint to 0.
global pidYaw is pidLoop(0, 0, 0).
set pidYaw:setpoint to 0.
global pidRol is pidLoop(0, 0, 0).
set pidRol:setpoint to 0.

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

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region BINDINGS
//---------------------------------------------------------------------------------------------------------------------

// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("SEP.S20.HEADER") { set ptSSHeader to pt. }
	if pt:name:startswith("SEP.S20.CREW") { set ptSSCommand to pt. }
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

lock headSS to heading_of_vector(SHIP:srfprograde:vector).
lock vecPad to vxcl(up:vector, pad:position).
lock degBerPad to relative_bearing(headSS, pad:heading).
lock mPad to pad:distance.
lock mSrf to (vecPad - vxcl(up:vector, SHIP:geoposition:position)):mag.
lock kpaDynPrs to SHIP:q * constant:atmtokpa.
lock degPitAct to get_pit(srfprograde).
lock degYawAct to get_yawnose(SHIP:up).
lock degRolAct to get_rollnose(SHIP:up).
lock pctHDProp to (rsHDCH4:amount / rsHDCH4:capacity) * 100.

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
		print "Srf distance:             km" at (0, 10).
		print "Target pitch:            deg" at (0, 11).
		print "Actual pitch:            deg" at (0, 12).
		print "----------------------------" at (0, 13).
		print "Pad bearing:             deg" at (0, 14).
		print "Target yaw:              deg" at (0, 15).
		print "Actual yaw:              deg" at (0, 16).
		print "Actual roll:             deg" at (0, 17).
		print "----------------------------" at (0, 18).
		print "Header prop:               %" at (0, 19).
		print "Throttle:" at (0, 20).

		deletePath(ss_edl_earth_log.csv).
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
		set logline to logline + "Header prop,".
		set logline to logline + "Throttle,".
		log logline to Earth_edl_log.
}

function write_screen { // Write dynamic display elements and write telemetry to logfile
		parameter phase.
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
		print round(mSrf / 1000, 0) + "    " at (14, 10).
		print round(degPitTrg, 2) + "    " at (14, 11).
		print round(degPitAct, 2) + "    " at (14, 12).
		// print "----------------------------".
		print round(degBerPad, 2) + "    " at (14, 14).
		print round(degYawTrg, 2) + "    " at (14, 15).
		print round(degYawAct, 2) + "    " at (14, 16).
		print round(degRolAct, 2) + "    " at (14, 17).
		// print "----------------------------".
		print round(pctHDProp, 2) + "    " at (14, 19).
		print round(throttle, 2) + "    " at (14, 20).

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
		set logline to logline + round(degRolAct, 2) + ",".
		set logline to logline + round(pctHDProp, 2) + ",".
		set logline to logline + round(throttle, 2) + ",".
		log logline to ss_edl_earth_log.csv.
}

function get_pit {
		parameter rTarget.
		local fcgShip is SHIP:facing.

		local svlPit is vxcl(fcgShip:starvector, rTarget:forevector):normalized.
		local dirPit is vDot(fcgShip:topvector, svlPit).
		local degPit is vAng(fcgShip:forevector, svlPit).

		if dirPit < 0 { return degPit. } else { return (0 - degPit). }
}

function get_yawdock {
		parameter rTarget.
		local fcgShip is SHIP:facing.

		local svlYaw is vxcl(fcgShip:topvector, rTarget:forevector):normalized.
		local dirYaw is vDot(fcgShip:starvector, svlYaw).
		local degYaw is vAng(fcgShip:forevector, svlYaw).

		if dirYaw < 0 { return degYaw. } else { return (0 - degYaw). }
}

function get_rolldock {
		parameter rDirection.
		local fcgShip is SHIP:facing.
		return arcTan2(-vDot(fcgShip:starvector, rDirection:forevector), vDot(fcgShip:topvector, rDirection:forevector)).
}

function get_yawnose {
		parameter rTarget.
		local fcgShip is SHIP:facing.

		local svlRol is vxcl(fcgShip:topvector, rTarget:forevector):normalized.
		local dirRol is vDot(fcgShip:starvector, svlRol).
		local degRol is vAng(fcgShip:forevector, svlRol).

		if dirRol > 0 { return degRol. } else { return (0 - degRol). }
}

function get_rollnose {
		parameter rDirection.
		local fcgShip is SHIP:facing.
		return 0 - arcTan2(-vDot(fcgShip:starvector, rDirection:forevector), vDot(fcgShip:topvector, rDirection:forevector)).
}

function heading_of_vector { // Returns the heading of the vector (number range 0 to 360)
		parameter vecT.
		local east IS vcrs(SHIP:UP:VECTOR, SHIP:NORTH:VECTOR).
		local trig_x IS vdot(SHIP:NORTH:VECTOR, vecT).
		local trig_y IS vdot(east, vecT).
		local result IS arctan2(trig_y, trig_x).
		if result < 0 { return 360 + result. } else { return result. }
}

function relative_bearing { // Returns the delta angle between two supplied headings
		parameter headA.
		parameter headB.
		local delta is headB - headA.
		if delta > 180 { return delta - 360. }
		if delta < -180 { return delta + 360. }
		return delta.
}

function calculate_lrp { // Calculate the desired pitch for long range tracking
	set mLrpTot to (mPad - mLrpTrg).
	set qrcLrp to 1000 * ((mLrpTot / (SHIP:groundspeed * (SHIP:altitude / 1000) * (SHIP:altitude / 1000))) - ((mLrpTot / 1000) * (ratLrp / 1000))).
	set degPitTrg to cnsLrp - qrcLrp.
}

function calculate_srp {
	set kmTotAlt to (SHIP:altitude - mSrpTrgAlt) / 1000.
	set knTotDst to (mSrf - mSrpTrgDst) / 1000.
	set degPitTrg to 90 - ((knTotDst / kmTotAlt) / cnsSrp).
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

// Shut down sea level Raptors
ptRaptorSLA:shutdown.
ptRaptorSLB:shutdown.
ptRaptorSLC:shutdown.

// Shut down vaccuum Raptors
for ptRaptorVac in arrRaptorVac { ptRaptorVac:shutdown. }

// Set flaps
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

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

write_console().

// Stage BALANCE FUEL
local ltrLOXTot is 0.
if defined rsHDLOX { set ltrLOXTot to ltrLOXTot + rsHDLOX:amount. }
if defined rsCMLOX { set ltrLOXTot to ltrLOXTot + rsCMLOX:amount. }
if defined rsBDLOX { set ltrLOXTot to ltrLOXTot + rsBDLOX:amount. }
local ltrCH4Tot is 0.
if defined rsHDCH4 { set ltrCH4Tot to ltrCH4Tot + rsHDCH4:amount. }
if defined rsCMCH4 { set ltrCH4Tot to ltrCH4Tot + rsCMCH4:amount. }
if defined rsBDCH4 { set ltrCH4Tot to ltrCH4Tot + rsBDCH4:amount. }

until ((abs((rsHDLOX:amount / rsBDLOX:amount) - ratFlHDBD) < 0.01) and (abs((rsHDCH4:amount / rsBDCH4:amount) - ratFlHDBD) < 0.01)) {
	write_screen("Balance fuel").
	if (rsHDLOX:amount / rsBDLOX:amount) > ratFlHDBD {
		set trnLOXH2B to transfer("lqdOxygen", ptSSHeader, ptSSBody, rsHDLOX:amount / 20).
		set trnLOXH2B:active to true.
	} else {
		set trnLOXB2H to transfer("lqdOxygen", ptSSBody, ptSSHeader, rsHDLOX:amount / 20).
		set trnLOXB2H:active to true.
	}
	if (rsHDCH4:amount / rsBDCH4:amount) > ratFlHDBD {
		set trnCH4H2B to transfer("LqdMethane", ptSSHeader, ptSSBody, rsHDCH4:amount / 20).
		set trnCH4H2B:active to true.
	} else {
		set trnCH4B2H to transfer("LqdMethane", ptSSBody, ptSSHeader, rsHDCH4:amount / 20).
		set trnCH4B2H:active to true.
	}
}


// Stage THERMOSPHERE
rcs on.
lock steering to lookdirup(heading(pad:heading, max(min(degPitTrg, degPitMax), degPitMin)):vector, SHIP:srfRetrograde:vector).

until kpaDynPrs > kpaMeso {
	write_screen("Thermosphere (RCS)").
	calculate_lrp().
}

// Stage MESOSPHERE
rcs off.
unlock steering.
set pidPit to pidLoop(arrPitMeso[0], arrPitMeso[1], arrPitMeso[2]).
set pidYaw to pidLoop(arrYawMeso[0], arrYawMeso[1], arrYawMeso[2]).
set pidPit to pidLoop(arrRolMeso[0], arrRolMeso[1], arrRolMeso[2]).

until kpaDynPrs > kpaStrt {
	write_screen("Mesosphere (Flaps)").
	calculate_lrp().
	calculate_csf().
	set degYawTrg to kpaDynPrs * (0 - degBerPad).
	set_flaps().
}

// Stage STRATOSPHERE
set pidPit to pidLoop(arrPitStrt[0], arrPitStrt[1], arrPitStrt[2]).
set pidYaw to pidLoop(arrYawStrt[0], arrYawStrt[1], arrYawStrt[2]).
set pidPit to pidLoop(arrRolStrt[0], arrRolStrt[1], arrRolStrt[2]).

until mSrf < mLrpTrg {
	write_screen("Stratosphere (Flaps)").
	calculate_lrp().
	calculate_csf().
	set degYawTrg to kpaDynPrs * (0 - degBerPad).
	set_flaps().
}

// Stage TROPOSPHERE
set pidPit to pidLoop(arrPitTrop[0], arrPitTrop[1], arrPitTrop[2]).
set pidYaw to pidLoop(arrYawTrop[0], arrYawTrop[1], arrYawTrop[2]).
set pidPit to pidLoop(arrRolTrop[0], arrRolTrop[1], arrRolTrop[2]).

until SHIP:altitude < mSrpTrgAlt {
	write_screen("Troposphere (Flaps)").
	calculate_srp().
	calculate_csf().
	set degYawTrg to get_yawnose(SHIP:north).
	set_flaps().
}

