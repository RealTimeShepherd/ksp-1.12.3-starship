
// Bind to ship parts
for pt in SHIP:parts {
	if pt:name:startswith("SEP.S20.CREW") { set ptSSCommand to pt. }

	if defined ptSSCommand {
		set mdSSCommand to ptSSCommand:getmodule("ModuleCommand").
		set mdSSRCS to ptSSCommand:getmodule("ModuleRCSFX").
	}
}

