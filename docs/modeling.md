# Performance model

`performance.m` builds thrust and level-flight drag over a Mach–altitude grid for the engines and airframe in `designParameters.m`. Sweep angles in that file are degrees. The vehicle code converts them to radians.

Published engine altitude and Mach limits are not applied. A point stays in the maps whenever the cycle and the drag build-up return a number.

## Atmosphere

`standardAtmosphere` is the International Standard Atmosphere through the troposphere and an isothermal lower stratosphere. The current grid stays below the 11 km tropopause, so only the troposphere branch is used. Temperature, pressure, density, Sutherland viscosity, and the speed of sound come from that table. Dynamic pressure, Reynolds number, and the engine inlet state are all taken from it.

## Engines

Each engine is a one-point turbojet anchored to its catalog row in `engines/boom_prize_design_engines.csv`.

The cycle holds exhaust gas temperature at the catalog maximum. Corrected airflow and overall pressure ratio stay at the catalog point while the inlet is no hotter than sea-level static air. Above that temperature a fixed physical redline reduces them through `RedlineFlowExponent` and `RedlinePressureExponent`. Set both exponents to 0 to hold corrected flow and overall pressure ratio constant at every flight condition.

Net thrust is gross thrust minus ram drag. A choked convergent nozzle also contributes the exit pressure term. Sea-level static net thrust is then scaled to catalog installed thrust, and fuel flow is scaled to the catalog. Air mass flow is not scaled. For the PBS TJ40-G1 the fuel-flow column and the SFC column disagree, so the anchor uses SFC times maximum thrust.

The cycle efficiencies change the lapse with Mach and altitude. They do not change the sea-level static thrust or fuel flow, because those are forced back to the catalog.

## Mass

Level flight uses `MaximumTakeoffMass_kg` for every engine. That value is 25 kg. The model does not split the vehicle into airframe, fuel, and payload, and it does not change the flown weight when the engine mass changes. Mass fraction is outside this calculation. An engine whose installed mass is not below 25 kg stops the run.

There is no fuel-burn schedule, so the mass does not fall during the map.

## Drag

Level-flight drag uses \(C_L = W/(qS)\), with \(S\) the wing planform area. The coefficient build-up is

\[
C_D = C_{D,\mathrm{skin}} + C_{D,i} + C_{D,\mathrm{wave,wing}} + C_{D,\mathrm{wave,volume}}.
\]

Skin friction is the Raymer turbulent flat-plate line on the wing, fuselage, and tail, multiplied by form factors, interference factors, and `ExcrescenceFactor`. The compressible piece of the wing and tail form factors is capped at `FormFactorMachCap` so it is not added again as wave drag. Mean aerodynamic chord is computed from area, span, and taper.

Induced drag uses a constant Oswald efficiency at the level-flight lift coefficient. Low Mach and high altitude can demand a lift coefficient this wing will not produce. Those points remain in the maps.

Wing wave drag is a Korn drag-divergence Mach followed by a Lock rise, \(20(\Delta M)^4\), harmonically capped so the rise stays finite. Korn is a subsonic sweep correction. For the thin, highly swept wing in `designParameters.m` it returns a value above Mach 1. That means the wing has no subsonic drag divergence inside this grid, not that drag diverges at the printed number. The code limits the stored value to the range 0.30–1.80, so a supercritical result prints as 1.80 across the table. At an aspect ratio near 1 the infinite-wing assumption behind Korn does not apply.

Volume wave drag is `WaveDragFactor` times the Sears–Haack minimum drag area of the fuselage volume plus the wing volume,

\[
\frac{D}{q} = \mathrm{WaveDragFactor}\,\frac{128}{\pi}\left(\frac{V}{L^2}\right)^2.
\]

A smoothstep fairs that drag in between a fineness-based start Mach and `VolumeWaveMachFull`. Wing wave drag and volume wave drag are added. They are not a single area-ruled equivalent body.

## What the prize rules ask of this model

The rules in `docs/boom prize requirements.txt` are only partly visible to this calculation.

The model flies every engine at the 25 kg takeoff mass and estimates whether steady level flight above Mach 1 is possible. The summary reports the best excess thrust on the grid for Mach greater than 1, and the Mach and altitude where it occurs. A positive value is the level-flight part of the requirement to hold more than Mach 1. The model has no instrumentation error band on that Mach number. Climbing at a lower lift coefficient is not solved; at these flight conditions the level-flight lift coefficient is already small, so induced drag is a small part of the total.

Airbreathing propulsion is the turbojet cycle above. The model has no rocket branch and no jettisoned mass.

Takeoff and landing distances, a second flight the same day, remote-pilot abort, and the pitot or GPS verification method are not calculated.

## Running it

Edit `designParameters.m` and run `performance.m`.

The console prints, for each engine, the thrust and fuel calibration, the takeoff mass actually flown, geometry, and a table at the report Mach numbers and altitudes. It also prints whether level flight above Mach 1 has positive excess thrust.

The saved grids are `data/engine_results.mat` and `data/vehicle_drag_results.mat`.

The figures that remain are thrust surfaces for the engine set, a thrust-and-drag surface for each pair, and a drag surface for each vehicle. Excess thrust is printed in the table rather than plotted.
