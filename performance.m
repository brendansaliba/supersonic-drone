%PERFORMANCE Propulsion and drag maps for the design in designParameters.m.
% Edit designParameters.m, then run this script. Sweep angles there are
% degrees. Calculated points are kept past any published engine envelope.

clear; clc;
format shortG; format compact;

projectRoot = fileparts(mfilename("fullpath"));
addpath(projectRoot);
addpath(fullfile(projectRoot, "engines"));
addpath(fullfile(projectRoot, "atmosphere"));
addpath(fullfile(projectRoot, "models"));
addpath(fullfile(projectRoot, "plotting"));
addpath(fullfile(projectRoot, "vehicles"));

params = designParameters();
engines = defineEngines(params.engineNames);
% Keep the printed report conditions on the map even if the linspace misses them.
machGrid = reshape(unique([params.machGrid(:); params.reportMach(:)]), 1, []);
altitudeGrid_m = reshape(unique([params.altitudeGrid_m(:); params.reportAltitude_m(:)]), 1, []);

results = evaluateEnginePerformance( ...
    engines, machGrid, altitudeGrid_m, params.cycle);
vehicles = defineVehicle(engines, params.vehicle);
dragResults = evaluateVehicleDrag(vehicles, machGrid, altitudeGrid_m);

dataDir = fullfile(projectRoot, "data");
if ~exist(dataDir, "dir")
    mkdir(dataDir);
end

save(fullfile(dataDir, "engine_results.mat"), ...
    "results", "engines", "machGrid", "altitudeGrid_m", "params");
save(fullfile(dataDir, "vehicle_drag_results.mat"), ...
    "dragResults", "vehicles", "machGrid", "altitudeGrid_m", "params");

summarizePerformance(results, dragResults, ...
    params.reportMach, params.reportAltitude_m);

plotThrustSurfaces(results);
plotVehicleDrag(dragResults);
plotThrustDragComparison(results, dragResults);
