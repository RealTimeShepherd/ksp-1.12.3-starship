
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Set landing target of SpaceX Boca Chica catch tower
global pad is latlng(26.0385053, -97.1530816). // Aim point - BC
global degPadEnt is 262.

// Variables for long range pitch tracking
global mLrpTrg is 12000.
// 105 worked for 264 starting mass - 95 worked for 144 starting mass
// Solution is to make cnsLrp = (Mass / 12) + 83
global cnsLrp is (SHIP:mass / 12) + 83.
global ratLrp is 0.011.
global qrcLrp is 0.

// Set min/max ranges
global degPitMax is 80.
global degPitMin is 40.

global degPitTrg is 0.
global degYawTrg is 0.

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
	set mdSSCommand to ptSSCommand:getmodule("ModuleCommand").
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
if defined ptFlapFL { set mdFlapFLCS to ptFlapFL:getmodule("ModuleSEPControlSurface"). }
if defined ptFlapFR { set mdFlapFRCS to ptFlapFR:getmodule("ModuleSEPControlSurface"). }
if defined ptFlapAL { set mdFlapALCS to ptFlapAL:getmodule("ModuleSEPControlSurface"). }
if defined ptFlapAR { set mdFlapARCS to ptFlapAR:getmodule("ModuleSEPControlSurface"). }

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
lock remHDProp to (rsHDCH4:amount / rsHDCH4:capacity) * 100.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console {

		clearScreen.
		print "Phase:        " at (0, 0).
		print "----------------------------" at (0, 1).
		print "Altitude:     " at (0, 2).
		print "Dyn pressure: " at (0, 3).
		print "----------------------------" at (0, 4).
		print "Hrz speed:    " at (0, 5).
		print "Vrt speed:    " at (0, 6).
		print "Air speed:    " at (0, 7).
		print "----------------------------" at (0, 8).
		print "Pad distance: " at (0, 9).
		print "Srf distance: " at (0, 10).
		print "Target pitch: " at (0, 11).
		print "Actual pitch: " at (0, 12).
		print "----------------------------" at (0, 13).
		print "Pad bearing:  " at (0, 14).
		print "Target yaw:   " at (0, 15).
		print "Actual yaw:   " at (0, 16).
		print "Actual roll:  " at (0, 17).
		print "----------------------------" at (0, 18).
		print "Header prop:  " at (0, 19).
		print "Throttle:     " at (0, 20).

}

function write_screen {

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
		print round(mPad, 0) + "    " at (14, 9).
		print round(mSrf, 0) + "    " at (14, 10).
		print round(degPitTrg, 2) + "    " at (14, 11).
		print round(degPitAct, 2) + "    " at (14, 12).
		// print "----------------------------".
		print round(degBerPad, 2) + "    " at (14, 14).
		print round(degYawTrg, 2) + "    " at (14, 15).
		print round(degYawAct, 2) + "    " at (14, 16).
		print round(degRolAct, 2) + "    " at (14, 17).
		// print "----------------------------".
		print round(remHDProp, 2) + "    " at (14, 19).
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
		set logline to logline + round(remHDProp, 2) + ",".
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

function relative_bearing {
		parameter headA.
		parameter headB.
		local delta is headB - headA.
		if delta > 180 { return delta - 360. }
		if delta < -180 { return delta + 360. }
		return delta.
}

function calculate_lrp {
	set mLrpTot to (mPad - mLrpTrg).
	set qrcLrp to 1000 * ((mLrpTot / (SHIP:groundspeed * (SHIP:altitude / 1000) * (SHIP:altitude / 1000))) - ((mLrpTot / 1000) * (ratLrp / 1000))).
	set degPitTrg to cnsLrp - qrcLrp.
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

// Disable manual control of flaps
mdFlapFLCS:setfield("pitch", true).
mdFlapFRCS:setfield("pitch", true).
mdFlapALCS:setfield("pitch", true).
mdFlapARCS:setfield("pitch", true).
mdFlapFLCS:setfield("yaw", true).
mdFlapFRCS:setfield("yaw", true).
mdFlapALCS:setfield("yaw", true).
mdFlapARCS:setfield("yaw", true).
mdFlapFLCS:setfield("roll", true).
mdFlapFRCS:setfield("roll", true).
mdFlapALCS:setfield("roll", true).
mdFlapARCS:setfield("roll", true).

// Set starting angles
mdFlapFLCS:setfield("deploy angle", 0).
mdFlapFRCS:setfield("deploy angle", 0).
mdFlapALCS:setfield("deploy angle", 0).
mdFlapARCS:setfield("deploy angle", 0).

// deploy control surfaces
mdFlapFLCS:setfield("deploy", true).
mdFlapFRCS:setfield("deploy", true).
mdFlapALCS:setfield("deploy", true).
mdFlapARCS:setfield("deploy", true).

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

write_console().

// Stage THERMOSPHERE
rcs on.
lock steering to lookdirup(heading(pad:heading, max(min(degPitTrg, degPitMax), degPitMin)):vector, SHIP:srfRetrograde:vector).

until kpaDynPrs > 100 {
	write_screen("Thermosphere (RCS)").
	calculate_lrp().
}
