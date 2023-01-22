
local mDstBse is 250000. // Original 7000
// Note the order is important.  set unload BEFORE load,
// and pack before unpack.  Otherwise the protections in
// place to prevent invalid values will deny your attempt
// to change some of the values:
// In-flight
set kuniverse:defaultloaddistance:flying:unload TO mDstBse.
set kuniverse:defaultloaddistance:flying:load TO mDstBse - 500.
wait 0.001.
set kuniverse:defaultloaddistance:flying:pack TO mDstBse - 1.
set kuniverse:defaultloaddistance:flying:unpack TO mDstBse - 1000.
wait 0.001.

// Parked on the ground:
set kuniverse:defaultloaddistance:landed:unload TO mDstBse.
set kuniverse:defaultloaddistance:landed:load TO mDstBse - 500.
wait 0.001.
set kuniverse:defaultloaddistance:landed:pack TO mDstBse - 1.
set kuniverse:defaultloaddistance:landed:unpack TO mDstBse - 1000.
wait 0.001.

// Parked in the sea:
set kuniverse:defaultloaddistance:splashed:unload TO mDstBse.
set kuniverse:defaultloaddistance:splashed:load TO mDstBse - 500.
wait 0.001.
set kuniverse:defaultloaddistance:splashed:pack TO mDstBse - 1.
set kuniverse:defaultloaddistance:splashed:unpack TO mDstBse - 1000.
wait 0.001.

// On the launchpad or runway
set kuniverse:defaultloaddistance:prelaunch:unload TO mDstBse.
set kuniverse:defaultloaddistance:prelaunch:load TO mDstBse - 500.
wait 0.001.
set kuniverse:defaultloaddistance:prelaunch:pack TO mDstBse - 1.
set kuniverse:defaultloaddistance:prelaunch:unpack TO mDstBse - 1000.
wait 0.001.

// In orbit
set kuniverse:defaultloaddistance:orbit:unload TO mDstBse.
set kuniverse:defaultloaddistance:orbit:load TO mDstBse - 500.
wait 0.001.
set kuniverse:defaultloaddistance:orbit:pack TO mDstBse - 1.
set kuniverse:defaultloaddistance:orbit:unpack TO mDstBse - 1000.
wait 0.001.
