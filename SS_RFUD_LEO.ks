
//---------------------------------------------------------------------------------------------------------------------
// #region HEADER
//---------------------------------------------------------------------------------------------------------------------

// Title:       SS_RFUD_LEO
// Translation: StarShip - Refuel and undock - Low Earth orbit
// Description: This script takes a docked Tanker StarShip in low Earth orbit through the following stages
// Wait:        Wait for the StarShip to line up with the OLIT tower below - orient for undocking
// Transfer:    Moments before release, move fuel from the tanker to the depot, keeping just enough for EDL
// Undock:      Detach from the Depot StarShip
// Lower PE:    Fire the vac raptors to lower the PE to just the right amount
// Run script:  Launch the SS_EDL_Earth script to guide the tanker safely back to base

if mdSSBDDock:hasevent("undock") {

	// STAGE: ORIENT FOR UNDOCK
	rcs on.
	lock steering to lookDirUp(retrograde:vector, up:vector).
	local timOrient is time:seconds + 30.
	until time:seconds > timOrient {
		write_screen_see("Orient for undock", true).
	}
	unlock steering.
	rcs off.
	sas on.
	wait 0.2.
	set sasMode to "Retrograde".

	// Stage: WAIT FOR UNDOCK
	until mPad > 13000000 {
		write_screen_see("Tower: " + round((mPad / 1000), 0) + " km", false).
	}

	// STAGE: FUEL TRANSFER
	

}
