
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
	if pt:name:startswith("SEP.RAPTOR.VAC") {
		if vdot(ship:facing:topvector, pt:position) < 0 {
			set ptRaptorVacA to pt.
		} else {
			if vdot(ship:facing:starvector, pt:position) < 0 {
				set ptRaptorVacB to pt.
			} else {
				set ptRaptorVacC to pt.
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

// Bind to module within StarShip Forward Left Flap
if defined ptFlapFL {
	set mdFlapFLCS to ptFlapFL:getmodule("ModuleSEPControlSurface").
}

// Bind to module within StarShip Forward Right Flap
if defined ptFlapFR {
	set mdFlapFRCS to ptFlapFR:getmodule("ModuleSEPControlSurface").
}

// Bind to module within StarShip Aft Left Flap
if defined ptFlapAL {
	set mdFlapALCS to ptFlapAL:getmodule("ModuleSEPControlSurface").
}

// Bind to module within StarShip Aft Right Flap
if defined ptFlapAR {
	set mdFlapARCS to ptFlapAR:getmodule("ModuleSEPControlSurface").
}

//---------------------------------------------------------------------------------------------------------------------
// #endregion
//---------------------------------------------------------------------------------------------------------------------

