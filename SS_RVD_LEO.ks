
parameter dockTrg.
set target to dockTrg.

//---------------------------------------------------------------------------------------------------------------------
// #region GLOBALS
//---------------------------------------------------------------------------------------------------------------------

// Logfile
global log is "Telemetry/ss_rvd_leo.csv".

global mOldTDist is 0. // Old target distance, used to detect if we are approaching or departing target

// Arrays for flaps and engines
global arrSSFlaps is list().
global arrRaptorVac is list().
global arrRaptorSL is list().
global arrSolarPanels is list().
global arrSPModules is list().

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
	if pt:name:startswith("SEP.RAPTOR.SL") { arrRaptorSL:add(pt). }
	if pt:name:startswith("nfs-panel-deploying-blanket-arm-1") { arrSolarPanels:add(pt). }
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
	set mdSSCommand to ptSSCommand:getmodule("ModuleCommand").
	// Bind to command tanks
	for rsc in ptSSCommand:resources {
		if rsc:name = "LqdOxygen" { set rsCMLOX to rsc. }
		if rsc:name = "LqdMethane" { set rsCMCH4 to rsc. }
	}
}

// Bind to modules & resources within StarShip Body
if defined ptSSBody {
	set mdSSBDRCS to ptSSBody:getmodule("ModuleRCSFX").
	set mdSSBDDN to ptSSBody:getmodule("ModuleDockingNode").
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

// Bind to modules within solar panels
for ptSolarPanel in arrSolarPanels {
	arrSPModules:add(ptSolarPanel:getmodule("ModuleDeployableSolarPanel")).
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region LOCKS
//---------------------------------------------------------------------------------------------------------------------

lock vecSS2Trg to SHIP:velocity:orbit - target:velocity:orbit.
lock degRelTrg to vAng(vecSS2Trg, target:position).
lock sOPSelf to abs(orbit:eta:apoapsis - orbit:eta:periapsis) * 2.
lock sOPTarg to abs(target:orbit:eta:apoapsis - target:orbit:eta:periapsis) * 2.

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------

function write_console { // Write unchanging display elements and header line of new CSV file
	clearScreen.
	print "Phase:        " at (0, 0).
	print "----------------------------" at (0, 1).
	print "Relative vel:            mps" at (0, 2).
	print "Relative ang:            deg" at (0, 3).
	print "Target dist:               s" at (0, 4).

	deletePath(log).
	local logline is "MET,".
	set logline to logline + "Phase,".
	set logline to logline + "Relative vel,".
	set logline to logline + "Relative ang,".
	set logline to logline + "Target dist,".
	log logline to log.
}

function write_screen { // Write dynamic display elements and write telemetry to logfile
	parameter phase.
	parameter writelog.
	print phase + "        " at (14, 0).
	// print "----------------------------".
	print round(vecSS2Trg:mag, 1) + "    " at (14, 2).
	print round(degRelTrg, 2) + "    " at (14, 3).
	print round(target:distance, 0) + "    " at (14, 4).

	if writelog = true {
		local logline is round(missionTime, 1) + ",".
		set logline to logline + phase + ",".
		set logline to logline + round(vecSS2Trg:mag, 1) + ",".
		set logline to logline + round(degRelTrg, 2) + ",".
		set logline to logline + round(target:distance, 0) + ",".
		log logline to log.
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
for ptRaptorSL in arrRaptorSL { ptRaptorSL:shutdown. }

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

write_console().

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------
// #region FLIGHT
//---------------------------------------------------------------------------------------------------------------------

rcs on.

if target:distance > 10000 {

	// Stage: INTERCEPT
	
	// Really should wait until AN or DN before intercept burn

	// Activate vacuum Raptors
	for ptRaptorVac in arrRaptorVac { ptRaptorVac:activate. }

	// How many seconds ahead or behind is target
	local sTrgDlt is target:distance / target:velocity:orbit:mag.

	if vang(target:position, SHIP:prograde:vector) < vang(target:position, SHIP:retrograde:vector) {
		// Target is ahead
		lock steering to lookDirUp(retrograde:vector, up:vector).
		// Wait for orientation
		until vAng(SHIP:facing:vector, retrograde:vector) < 0.5 {
			write_screen("Face Retrograde", true).
		}
		lock throttle to 0.4.
		until sOPSelf < (sOPTarg - sTrgDlt) * 1.0001 {
			write_screen("Intercept burn", true).
		}
	} else {
		// Target is behind
		lock steering to lookDirUp(prograde:vector, up:vector).
		// Wait for orientation
		until vAng(SHIP:facing:vector, prograde:vector) < 0.5 {
			write_screen("Face Prograde", true).
		}
		lock throttle to 0.4.
		until sOPSelf > (sOPTarg + sTrgDlt) * 0.9999 {
			write_screen("Intercept burn", true).
		}
	}
	lock throttle to 0.
	rcs off.
	unlock steering.
	set navMode to "orbit".
	wait 0.1.
	sas on.
	wait 0.1.
	set sasmode to "prograde".

	local timIntcpt is time:seconds + sOPSelf.
	until time:seconds > timIntcpt {
		write_screen("Coast to intercept", false).
	}

}

// Stage: MATCHING VELOCITY
set navMode to "target".

// Stage: CLOSING DISTANCE
set SHIP:control:fore to 0.
lock axsRelTrg to vcrs(vecSS2Trg, target:position).
set mOldTDist to target:distance.

until target:distance < 300 {

	lock steering to vecSS2Trg.
	set SHIP:control:fore to -1.
	until vecSS2Trg:mag < 2 {
		write_screen("Matching velocity", true).
	}

	lock rotRelTrg to angleAxis(degRelTrg, axsRelTrg).
	lock steering to rotRelTrg * prograde:vector.
	until vAng(SHIP:facing:vector, rotRelTrg * prograde:vector) < 1 {
		write_screen("Adjusting attitude", true).
	}
	set SHIP:control:fore to 1.
	until vecSS2Trg:mag > 20 or target:distance < 300 {
		write_screen("Closing distance", true).
	}

	set SHIP:control:fore to 0.
	lock rotRelTrg to angleAxis(0 - degRelTrg, axsRelTrg).
	until vAng(SHIP:facing:vector, rotRelTrg * prograde:vector) < 1 {
		write_screen("Adjusting attitude", true).
	}
	set SHIP:control:fore to -1.
	until vecSS2Trg:mag < 12 or target:distance < 300 {
		write_screen("Closing distance", true).
	}

	rcs off.
	until target:distance > mOldTDist or target:distance < 300 {
		write_screen("Coasting", true).
		set mOldTDist to target:distance.
	}
	rcs on.

}

lock steering to vecSS2Trg.
set SHIP:control:fore to -1.
until vecSS2Trg:mag < 0.2 {
	write_screen("Matching velocity", true).
}

set SHIP:control:fore to 0.

lock axsTrgFac to vcrs(target:position, target:facing:vector).
lock rotTrgFac to angleAxis(90, axsTrgFac).
lock steering to lookDirUp(rotTrgFac * target:position, target:position).

until vAng(SHIP:facing:vector, rotTrgFac * target:position) < 1 {
	write_screen("Adjusting attitude", true).
}

set SHIP:control:top to 1.
until vecSS2Trg:mag > 2 {
	write_screen("Final approach", true).
}
set SHIP:control:top to 0.

// until target:distance < 50 {
// 	write_screen("Final approach", true).
// }

until false {
	write_screen("Final approach", true).
}