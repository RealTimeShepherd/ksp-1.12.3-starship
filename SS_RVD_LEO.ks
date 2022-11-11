
parameter dockTarget.
list targets in targs.
for targ in targs {
	if targ:name = dockTarget {
		set dockTrg to targ.
	}
}
//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Logfile
global log_srl is "Telemetry/ss_rvd_leo.csv".

global mDistRndv is 5000. // Distance for rendezvous
global mDistDock is 300. // Distance for docking

global vecHldNos is 0. // Vector to hold attitude when docking
global vecHldPrt is 0. // Vector to hold attitude when docking

// Arrays for flaps and engines
global arrSSFlaps_srl is list().
global arrRaptorVac_srl is list().
global arrRaptorSL_srl is list().
global arrSolarPanels_srl is list().
global arrSPModules_srl is list().

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
	if pt:name:startswith("SEP.RAPTOR.VAC") { arrRaptorVac_srl:add(pt). }
	if pt:name:startswith("SEP.RAPTOR.SL") { arrRaptorSL_srl:add(pt). }
	if pt:name:startswith("nfs-panel-deploying-blanket-arm-1") { arrSolarPanels_srl:add(pt). }
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
	arrSSFlaps_srl:add(mdFlapFLCS).
}
if defined ptFlapFR {
	set mdFlapFRCS to ptFlapFR:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_srl:add(mdFlapFRCS).
}
if defined ptFlapAL {
	set mdFlapALCS to ptFlapAL:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_srl:add(mdFlapALCS).
}
if defined ptFlapAR {
	set mdFlapARCS to ptFlapAR:getmodule("ModuleSEPControlSurface").
	arrSSFlaps_srl:add(mdFlapARCS).
}

// Bind to modules within solar panels
for ptSolarPanel in arrSolarPanels_srl {
	arrSPModules_srl:add(ptSolarPanel:getmodule("ModuleDeployableSolarPanel")).
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

lock vecSS2Trg to SHIP:velocity:orbit - dockTrg:velocity:orbit.
lock vecTrg2SS to dockTrg:velocity:orbit - SHIP:velocity:orbit.
lock degRelTrg to vAng(vecSS2Trg, dockTrg:position).
lock sOPSelf to abs(orbit:eta:apoapsis - orbit:eta:periapsis) * 2.
lock sOPTarg to abs(dockTrg:orbit:eta:apoapsis - dockTrg:orbit:eta:periapsis) * 2.
lock degTrgNos to vAng(SHIP:facing:vector, dockTrg:facing:vector).
lock mDockDltX to 0. // X delta - used for docking
lock mDockDltY to 0. // Y delta - used for docking
lock mDockDltZ to 0. // Z delta - used for docking

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console_srl { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:        " at (0, 0).
	print "----------------------------" at (0, 1).
	print "Relative vel:            mps" at (0, 2).
	print "Relative ang:            deg" at (0, 3).
	print "Target dist:               s" at (0, 4).
	print "----------------------------" at (0, 5).
	print "Dock Port X:               m" at (0, 6).
	print "Dock Port Y:               m" at (0, 7).
	print "Dock Port Z:               m" at (0, 8).

	deletePath(log_srl).
	local logline is "MET,".
	set logline to logline + "Phase,".
	set logline to logline + "Relative vel,".
	set logline to logline + "Relative ang,".
	set logline to logline + "Target dist,".
	set logline to logline + "Dock Port X,".
	set logline to logline + "Dock Port Y,".
	set logline to logline + "Dock Port Z,".
	log logline to log_srl.
}

function write_screen_srl { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "        " at (14, 0).
	// print "----------------------------".
	print round(vecSS2Trg:mag, 1) + "    " at (14, 2).
	print round(degRelTrg, 2) + "    " at (14, 3).
	print round(dockTrg:distance, 0) + "    " at (14, 4).
	print round(mDockDltX, 2) + "    " at (14, 6).
	print round(mDockDltY, 2) + "    " at (14, 7).
	print round(mDockDltZ, 2) + "    " at (14, 8).

	if writelog = true {
		local logline is round(missionTime, 1) + ",".
		set logline to logline + phase + ",".
		set logline to logline + round(vecSS2Trg:mag, 1) + ",".
		set logline to logline + round(degRelTrg, 2) + ",".
		set logline to logline + round(dockTrg:distance, 0) + ",".
		log logline to log_srl.
	}
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

// Enable main fuel tanks - disable header tanks
if defined rsHDLOX { set rsHDLOX:enabled to false. }
if defined rsHDCH4 { set rsHDCH4:enabled to false. }
if defined rsCMLOX { set rsCMLOX:enabled to true. }
if defined rsCMCH4 { set rsCMCH4:enabled to true. }
if defined rsBDLOX { set rsBDLOX:enabled to true. }
if defined rsBDCH4 { set rsBDCH4:enabled to true. }

// Kill throttle
lock throttle to 0.

// Shut down sea level Raptors
for ptRaptorSL in arrRaptorSL_srl { ptRaptorSL:shutdown. }

// Shut down vacuum Raptors
for ptRaptorVac in arrRaptorVac_srl { ptRaptorVac:shutdown. }

// Set flaps to default position
for mdSSFlap in arrSSFlaps_srl {
	// Disable manual control
	mdSSFlap:setfield("pitch", true).
	mdSSFlap:setfield("yaw", true).
	mdSSFlap:setfield("roll", true).
	// Set starting angles
	mdSSFlap:setfield("deploy angle", 0).
	// deploy control surfaces
	mdSSFlap:setfield("deploy", true).
}

write_console_srl().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

// Activate vacuum Raptors
for ptRaptorVac in arrRaptorVac_srl { ptRaptorVac:activate. }

if dockTrg:distance > mDistRndv {

	// Stage: Wait for node
	lock degIncDlt to SHIP:orbit:lan - dockTrg:orbit:lan.
	set degOldID to degIncDlt.
	wait 1.
	if degIncDlt > degOldID {
		// Inclination delta is increasing
		until degIncDlt < degOldID {
			write_screen_srl("Waiting for node", true).
			set degOldID to degIncDlt.
			wait 1.
		}
	} else {
		// Inclination delta is decreasing
		until degIncDlt > degOldID {
			write_screen_srl("Waiting for node", true).
			set degOldID to degIncDlt.
			wait 1.
		}
	}

	// Stage: INTERCEPT
	rcs on.
	set navMode to "orbit".
	local sTrgDlt is dockTrg:distance / dockTrg:velocity:orbit:mag.

	if vang(dockTrg:position, SHIP:prograde:vector) < vang(dockTrg:position, SHIP:retrograde:vector) {
		// Target is ahead
		lock steering to lookDirUp(retrograde:vector, up:vector).
		// Wait for orientation
		until vAng(SHIP:facing:vector, retrograde:vector) < 0.5 {
			write_screen_srl("Facing retrograde", true).
		}
		lock throttle to 0.4.
		until sOPSelf < (sOPTarg - sTrgDlt) * 1.0001 {
			write_screen_srl("Intercept (burn)", true).
		}
	} else {
		// Target is behind
		lock steering to lookDirUp(prograde:vector, up:vector).
		// Wait for orientation
		until vAng(SHIP:facing:vector, prograde:vector) < 0.5 {
			write_screen_srl("Facing prograde", true).
		}
		lock throttle to 0.4.
		until sOPSelf > (sOPTarg + sTrgDlt) * 0.9999 {
			write_screen_srl("Intercept (burn)", true).
		}
	}

	lock throttle to 0.
	rcs off.
	unlock steering.
	sas on.
	wait 0.1.
	set sasmode to "prograde".

	local timIntcpt is time:seconds + sOPSelf.
	until time:seconds > timIntcpt and dockTrg:distance > mDistRndv {
		write_screen_srl("Intercept (" + round(time:seconds - timIntcpt, 0) + ")", true).
	}

}

// Stage: CLOSING
rcs on.
set SHIP:control:fore to 0.

until dockTrg:distance < mDistDock {

	set SHIP:control:fore to 0.
	lock throttle to 0.
	lock steering to vecTrg2SS.
	until vAng(SHIP:facing:vector, vecTrg2SS) < 1 {
		write_screen_srl("Facing Rel:retro", true).
	}
	lock throttle to 0.4.
	until vecSS2Trg:mag < 1 {
		write_screen_srl("Matching velocity", true).
	}

	lock throttle to 0.
	lock steering to dockTrg:position.
	until vAng(SHIP:facing:vector, dockTrg:position) < 1 {
		write_screen_srl("Facing target", true).
	}
	set SHIP:control:fore to 1.
	until vecSS2Trg:mag > 10 or dockTrg:distance < mDistDock {
		write_screen_srl("Closing (RCS)", true).
	}

	rcs off.
	until degRelTrg > 90 or dockTrg:distance < mDistDock {
		write_screen_srl("Closing (coast)", true).
	}
	rcs on.

}

// Stage: ALIGN BODY
for ptRaptorVac in arrRaptorVac_srl { ptRaptorVac:shutdown. }

set SHIP:control:fore to 0.
lock steering to vecSS2Trg.
until vAng(SHIP:facing:vector, vecSS2Trg) < 1 {
	write_screen_srl("Facing Rel:retro", true).
}
set SHIP:control:fore to -1.
until vecSS2Trg:mag < 0.5 {
	write_screen_srl("Matching velocity", true).
}
set SHIP:control:fore to 0.

lock axsTrgFac to vcrs(dockTrg:position, dockTrg:facing:vector).
lock rotTrgFac to angleAxis(90, axsTrgFac).
lock steering to lookDirUp(rotTrgFac * dockTrg:position, dockTrg:position).

for pt in dockTrg:parts {
	if pt:name:startswith("SEP.RAPTOR.VAC") { set ptTrgVac to pt. }
}

// Set up vectors for alignment
lock vecRaptors to (ptTrgVac:position - arrRaptorVac_srl[0]:position).
lock vecXPort to vxcl(dockTrg:facing:vector, SHIP:facing:starvector).
lock vecXTarg to vxcl(dockTrg:facing:vector, dockTrg:position).
lock degXPort to vAng(vecXPort, vecXTarg).
lock vecYPort to vxcl(dockTrg:facing:starvector, SHIP:facing:forevector).
lock vecYTarg to vxcl(dockTrg:facing:starvector, vecRaptors).
lock degYPort to vAng(vecYPort, vecYTarg).

until degTrgNos < 0.5 {
	write_screen_srl("Aligning body", true).
}

until abs(degXPort - 90) < 0.5 {
	write_screen_srl("Rotating dock port", true).
}

// Stage: DOCKING
set vecHldNos to SHIP:facing:vector.
set vecHldPrt to SHIP:facing:topvector.
lock steering to lookDirUp(vecHldNos, vecHldPrt). // Hold current attitude

// Lock XYZ values for docking
lock mDockDltX to dockTrg:distance * tan(degXPort - 90).
lock mDockDltY to dockTrg:distance * tan(degYPort - 90).
lock mDockDltZ to dockTrg:distance - 8.98.

set pidX to pidLoop(0.2, 0.001, 3, -1, 1).
set pidX:setpoint to 0.
set pidY to pidLoop(0.2, 0.001, 3, -1, 1).
set pidY:setpoint to 0.
set pidZ to pidLoop(0.1, 0.001, 2, -1, 1).
set pidZ:setpoint to 0.

local tCurMass is SHIP:mass.

until SHIP:mass > tCurMass {
	write_screen_srl("Final approach", true).
	set SHIP:control:starboard to pidX:update(time:seconds, mDockDltX).
	set SHIP:control:fore to pidY:update(time:seconds, mDockDltY).
	set SHIP:control:top to 0 - pidZ:update(time:seconds, mDockDltZ).
}

// Stage: Fuel transfer
unlock steering.
rcs off.
until false {
	write_screen_srl("Fuel transfer", true).
}
