
print "Waiting for ship to unpack.".
wait until SHIP:unpacked.
print "Ship is now unpacked.".

if SHIP:status = "PRELAUNCH" {
	print "Still on ground, boot script exiting.".
} else {

	list targets in targs.
	for targ in targs {
		if targ:distance < 10000 {
			set docker to targ.
		}
	}

	lock degTrgNos to vAng(SHIP:facing:vector, docker:facing:vector).
	lock vecXPort to vxcl(docker:facing:vector, SHIP:facing:topvector).
	lock vecXTarg to vxcl(docker:facing:vector, docker:position).
	lock degXPort to vAng(vecXPort, vecXTarg).

	function write_console_sdb { // Write unchanging display elements
		clearScreen.
		print "Phase:        " at (0, 0).
		print "----------------------------" at (0, 1).
		print "Nose angle:              deg" at (0, 2).
		print "Port angle:              deg" at (0, 3).
		print "Target dist:               m" at (0, 4).
	}

	function write_screen_sdb { // Write dynamic display elements
		parameter phase.
		print phase + "        " at (14, 0).
		// print "----------------------------".
		print round(degTrgNos, 2) + "    " at (14, 2).
		print round(degXPort, 2) + "    " at (14, 3).
		print round(docker:distance, 0) + "    " at (14, 4).
	}

	// Nullify RCS control values
	set SHIP:control:pitch to 0.
	set SHIP:control:yaw to 0.
	set SHIP:control:roll to 0.

	// Switch off RCS and SAS
	rcs off.
	sas off.

	// Kill throttle
	lock throttle to 0.

	write_console_sdb().

	until docker:distance < 500 {
		write_screen_sdb("Waiting").
	}

	set ag8 to true.
	rcs on.
	lock steering to lookDirUp(docker:facing:vector, docker:position).

	until degTrgNos < 0.5 {
		write_screen_sdb("Aligning body").
	}

	until degXPort < 0.5 {
		write_screen_sdb("Rotating dock port").
	}

	local tCurMass is SHIP:mass.
	until SHIP:mass > tCurMass {
		write_screen_sdb("Holding station").
	}

}

// end script