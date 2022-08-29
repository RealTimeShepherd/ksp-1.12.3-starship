
// Bind to main sections
if SHIP:partstagged("SEP.B4.INTER"):length = 1 {
    set ptBInter to SHIP:partstagged("SEP.B4.INTER")[0].
    // Bind to Module Command
    set mdCommand to ptBInter:getmodule("ModuleCommand").
    set mdDecouple to ptBInter:getmodule("ModuleDecouple").
}

if SHIP:partstagged("SEP.B4.CORE"):length = 1 {
    set ptBCore to SHIP:partstagged("SEP.B4.CORE")[0].
}
