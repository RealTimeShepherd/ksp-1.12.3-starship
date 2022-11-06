
function write_console {
	
	clearScreen.
	print "Phase:        " at (0, 0).
	print "----------------------------" at (0, 1).
	print "Targ altitude:" at (0, 2).
	print "Srf distance: " at (0, 3).
	print "----------------------------" at (0, 4).
	print "Geo Lat delta:" at(0, 5).
	print "Geo Lng delta:" at(0, 6).
	
}

function write_screen {

	parameter phase.
	// clearScreen.
	print phase + "        " at (14, 0).
	// print "----------------------------".
	print round(catch:altitude, 0) + "  " at (14, 2).
	print round(mDist, 0) + "	" at (14, 3).
	// print "----------------------------".
	print round(catch:geoposition:lat - pad:lat, 6) + "	" at(14, 5).
	print round(catch:geoposition:lng - pad:lng, 6) + "	" at(14, 6).
	
}

clearscreen.
print "Waiting for OLIT unpacking".

wait until ship:unpacked.

// Bind to MechaZilla
for pt in SHIP:parts {
	if pt:name:startswith("SLE.SS.OLIT.MZ") { set ptMZ to pt. }
	if pt:name:startswith("SLE.SS.OLP") { set ptOLP to pt. }
}

// Bind to modules within MechaZilla
if defined ptMZ {
	set mdVrtMove to ptMZ:getmodulebyindex(1).
	set mdArmMove to ptMZ:getmodulebyindex(6).
	set mdPshMove to ptMZ:getmodulebyindex(7).
	set mdStbMove to ptMZ:getmodulebyindex(8).
}
if mdArmMove:hasevent("open arms") { mdArmMove:doevent("open arms"). }

clearscreen.
print "Searching for catch target".

if SHIP:Name <> "Tanker StarShip" and SHIP:Name <> "Crew StarShip" {

	set catch to "NULL".
	until catch <> "NULL" {
		list targets in targs.
		for targ in targs {
			if targ:Name = "SuperHeavy" or targ:Name = "Tanker StarShip" or targ:Name = "Crew StarShip" {
				set catch to targ.
			}
		}
		wait 0.5.
	}

	lock vecCatch to vxcl(up:vector, catch:position).
	lock mDist to (vecCatch - vxcl(up:vector, SHIP:geoposition:position)):mag.
	global pad is latlng(25.9669968, -97.1416771).
	
	write_console().
	until mDist < 20 and catch:altitude < 280 { write_screen("Waiting to catch " + catch:Name). }

	mdArmMove:doevent("close arms").
	local secTCatch is 4.
	set timTCatch to time:seconds + secTCatch.
	until time:seconds > timTCatch { write_screen("Closing arms"). }

}

clearscreen.
print "Boot script has ended".
