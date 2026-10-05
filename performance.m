%PERFORMANCE Generate first-cut propulsion and drag maps.
% This script is the top-level entry point for sweeping engines and a
% placeholder vehicle over Mach number and altitude.

clear; clc;
format shortG; format compact;

projectRoot = fileparts(mfilename("fullpath"));
addpath(fullfile(projectRoot, "engines"));
addpath(fullfile(projectRoot, "atmosphere"));
addpath(fullfile(projectRoot, "models"));
addpath(fullfile(projectRoot, "plotting"));
addpath(fullfile(projectRoot, "vehicles"));

engineNames = [
    "PBS TJ40-G1"
    "AMT Olympus 23"
    "AMT NL NIKE HP"
    "AMT NL Pegasus HP"
    "AMT Olympus HP"
    ].';
engines = defineEngines(engineNames);

machGrid = linspace(0, 1.1, 60);
altitudeGrid_m = linspace(0, 10000, 25);

results = evaluateEnginePerformance(engines, machGrid, altitudeGrid_m);
vehicles = definePlaceholderVehicle(engines);
dragResults = evaluateVehicleDrag(vehicles, machGrid, altitudeGrid_m);

dataDir = fullfile(projectRoot, "data");
if ~exist(dataDir, "dir")
    mkdir(dataDir);
end

save(fullfile(dataDir, "engine_results.mat"), ...
    "results", "engines", "machGrid", "altitudeGrid_m");
save(fullfile(dataDir, "vehicle_drag_results.mat"), ...
    "dragResults", "vehicles", "machGrid", "altitudeGrid_m");

plotEnginePerformance(results);
plotThrustSurfaces(results);
plotVehicleDrag(dragResults);
plotThrustDragComparison(results, dragResults);
