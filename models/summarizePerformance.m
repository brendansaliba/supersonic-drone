function summarizePerformance(results, dragResults, reportMach, reportAltitude_m)
%SUMMARIZEPERFORMANCE Print calibration, geometry, and point performance.
% Report conditions use the nearest Mach and altitude on each map.

arguments
    results (1,:) struct
    dragResults (1,:) struct
    reportMach (1,:) double {mustBeNonnegative}
    reportAltitude_m (1,:) double {mustBeNonnegative}
end

fprintf("Edit designParameters.m and rerun performance.m.\n");
fprintf("Sweep angles in that file are degrees.\n\n");

for iPair = 1:numel(results)
    localPrintPair(results(iPair), dragResults(iPair), ...
        reportMach, reportAltitude_m);
end
end

function localPrintPair(engineResult, dragResult, reportMach, reportAltitude_m)
model = engineResult.ModelParameters;
vehicle = dragResult.Vehicle;

fprintf("%s\n", engineResult.Name);
fprintf("  Installed anchor %.1f N, cycle sea-level static %.1f N, thrust scale %.3f\n", ...
    model.AnchorThrust_N, model.CycleSeaLevelStaticThrust_N, model.ThrustScale);
fprintf("  Fuel anchor %.3f kg/min, cycle %.3f kg/min, fuel scale %.3f\n", ...
    model.AnchorFuel_kg_s * 60, model.CycleSeaLevelStaticFuel_kg_s * 60, ...
    model.FuelScale);
fprintf("  Fuel source: %s\n", model.AnchorFuelSource);
fprintf("  Takeoff mass %.2f kg. Engine installed mass %.2f kg.\n", ...
    vehicle.GrossMass_kg, vehicle.EngineInstalledMass_kg);
fprintf("  S %.3f m^2, span %.2f m, MAC %.3f m, sweep %.1f deg, body %.3f m x %.3f m, fineness %.2f\n", ...
    vehicle.ReferenceArea_m2, vehicle.WingSpan_m, ...
    vehicle.MeanAerodynamicChord_m, vehicle.WingQuarterChordSweep_deg, ...
    vehicle.FuselageLength_m, vehicle.FuselageDiameter_m, ...
    vehicle.FuselageFinenessRatio);
fprintf("  Asymptotic volume-wave drag area %.5f m^2 (CD %.4f on Sref)\n", ...
    dragResult.ModelParameters.AsymptoticWaveDragArea_m2, ...
    dragResult.ModelParameters.AsymptoticVolumeWaveDragCoefficient);

fprintf("  %s\n", sprintf("%4s %6s %8s %8s %8s %6s %6s %7s %6s %7s %7s %7s %7s %7s %5s", ...
    "Mach", "Alt_km", "ThrustN", "DragN", "ExcessN", "T/D", "L/D", ...
    "TSFCmg", "CL", "CD", "CDskin", "CDi", "CDww", "CDvol", "Mdd"));

for iMach = 1:numel(reportMach)
    machIndex = localNearest(engineResult.Mach, reportMach(iMach));
    for iAltitude = 1:numel(reportAltitude_m)
        altitudeIndex = localNearest(engineResult.Altitude_m, ...
            reportAltitude_m(iAltitude));
        localPrintPoint(engineResult, dragResult, altitudeIndex, machIndex);
    end
end

localPrintSupersonicSustain(engineResult, dragResult);
fprintf("\n");
end

function localPrintSupersonicSustain(engineResult, dragResult)
supersonic = engineResult.Mach > 1;
if ~any(supersonic)
    fprintf("  Level flight above Mach 1: the Mach grid does not extend above Mach 1.\n");
    return;
end

excess_N = engineResult.Thrust_N(:, supersonic) - dragResult.Drag_N(:, supersonic);
if ~any(isfinite(excess_N), "all")
    fprintf("  Level flight above Mach 1: no finite thrust-drag result.\n");
    return;
end

[bestExcess_N, linearIndex] = max(excess_N, [], "all", "omitnan");
[altitudeIndex, machIndex] = ind2sub(size(excess_N), linearIndex);
supersonicMach = engineResult.Mach(supersonic);
if bestExcess_N > 0
    verdict = "yes";
else
    verdict = "no";
end
fprintf("  Level flight above Mach 1: %s. Best excess thrust %.1f N at Mach %.2f and %.2f km.\n", ...
    verdict, bestExcess_N, supersonicMach(machIndex), ...
    engineResult.Altitude_m(altitudeIndex) / 1000);
end

function localPrintPoint(engineResult, dragResult, altitudeIndex, machIndex)
thrust_N = engineResult.Thrust_N(altitudeIndex, machIndex);
drag_N = dragResult.Drag_N(altitudeIndex, machIndex);
weight_N = dragResult.ModelParameters.Weight_N;
tsfc_mg = engineResult.TSFC_kg_N_s(altitudeIndex, machIndex) * 1e6;

fprintf("  %4.2f %6.2f %8.1f %8.1f %8.1f %6.2f %6.2f %7.1f %6.3f %7.4f %7.4f %7.4f %7.4f %7.4f %5.2f\n", ...
    engineResult.Mach(machIndex), ...
    engineResult.Altitude_m(altitudeIndex) / 1000, ...
    thrust_N, ...
    drag_N, ...
    thrust_N - drag_N, ...
    thrust_N / drag_N, ...
    weight_N / drag_N, ...
    tsfc_mg, ...
    dragResult.LiftCoefficient(altitudeIndex, machIndex), ...
    dragResult.TotalDragCoefficient(altitudeIndex, machIndex), ...
    dragResult.SkinDragCoefficient(altitudeIndex, machIndex), ...
    dragResult.InducedDragCoefficient(altitudeIndex, machIndex), ...
    dragResult.WingWaveDragCoefficient(altitudeIndex, machIndex), ...
    dragResult.VolumeWaveDragCoefficient(altitudeIndex, machIndex), ...
    dragResult.KornDragDivergenceMach(altitudeIndex, machIndex));
end

function index = localNearest(grid, value)
[~, index] = min(abs(grid(:) - value));
end
