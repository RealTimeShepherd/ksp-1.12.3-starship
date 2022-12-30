^f::
Send, function heading_of_vector {{}{Enter}
Send, parameter vecT.{Enter}
Send, local east IS VCRS(SHIP:UP:VECTOR, SHIP:NORTH:VECTOR).{Enter}
Send, local trig_x IS VDOT(SHIP:NORTH:VECTOR, vecT).{Enter}
Send, local trig_y IS VDOT(east, vecT).{Enter}
Send, local result IS ARCTAN2(trig_y, trig_x).{Enter}
Send, if result < 0 {{} return 360 {+} result. {}} else {{} return result. {}}.{Enter}
Send, {}}
Send, {Enter}
Send, function relative_bearing {{}{Enter}
Send, parameter headA.{Enter}
Send, parameter headB.{Enter}
Send, local delta is headB - headA.{Enter}
Send, if delta > 180 {{} return delta - 360. {}}.{Enter}
Send, if delta < -180 {{} return delta {+} 360. {}}.{Enter}
Send, return delta.{Enter}
Send, {}}
Send, {Enter}
return