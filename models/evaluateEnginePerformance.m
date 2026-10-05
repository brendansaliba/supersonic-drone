function results = evaluateEnginePerformance(engines, machGrid, altitudeGrid_m)
%EVALUATEENGINEPERFORMANCE Build engine performance maps over Mach/altitude.
% This first-pass model estimates thrust, fuel flow, and TSFC from sea-level
% static engine data, Mach number, and standard-atmosphere pressure and
% temperature ratios.

arguments
    engines (1,:) struct
    machGrid (1,:) double {mustBeNonnegative}
    altitudeGrid_m (1,:) double {mustBeNonnegative}
end

atmosphere = standardAtmosphere(altitudeGrid_m(:));
[machMesh, ~] = meshgrid(machGrid, altitudeGrid_m);

pSeaLevel_Pa = 101325;
tSeaLevel_K = 288.15;
delta = atmosphere.Pressure_Pa ./ pSeaLevel_Pa;
theta = atmosphere.Temperature_K ./ tSeaLevel_K;
deltaMap = repmat(delta, 1, numel(machGrid));
thetaMap = repmat(theta, 1, numel(machGrid));

kMach = 0.35;
kRam = 0.05;
kFuelFlowMach = 0.20;
nuInlet = 1.00;
nuNozzle = 1.00;

results = repmat(localEmptyResult(), 1, numel(engines));

for iEngine = 1:numel(engines)
    engine = engines(iEngine);

    seaLevelThrust_N = engine.SeaLevelStaticThrust_N;
    seaLevelFuelMassFlow_kg_s = localSeaLevelFuelMassFlow(engine);

    machFactor = 1 - kMach .* machMesh + kRam .* machMesh.^2;
    thrust_N = seaLevelThrust_N .* deltaMap .* machFactor .* ...
        nuInlet .* nuNozzle;

    fuelMassFlow_kg_s = seaLevelFuelMassFlow_kg_s .* deltaMap .* ...
        sqrt(thetaMap) .* (1 + kFuelFlowMach .* machMesh);
    tsfc_kg_N_s = fuelMassFlow_kg_s ./ thrust_N;
    validMask = true(size(thrust_N));

    results(iEngine).Name = engine.Name;
    results(iEngine).Type = engine.Type;
    results(iEngine).Engine = engine;
    results(iEngine).Mach = machGrid;
    results(iEngine).Altitude_m = altitudeGrid_m;
    results(iEngine).Atmosphere = atmosphere;
    results(iEngine).Thrust_N = thrust_N;
    results(iEngine).TSFC_kg_N_s = tsfc_kg_N_s;
    results(iEngine).FuelMassFlow_kg_s = fuelMassFlow_kg_s;
    results(iEngine).MassFlow_kg_s = fuelMassFlow_kg_s;
    results(iEngine).ValidMask = validMask;
    results(iEngine).ModelParameters = struct( ...
        "PressureRatioDelta", delta, ...
        "TemperatureRatioTheta", theta, ...
        "MachThrustLossCoefficient", kMach, ...
        "RamRecoveryCoefficient", kRam, ...
        "FuelFlowMachCoefficient", kFuelFlowMach, ...
        "InletEfficiency", nuInlet, ...
        "NozzleEfficiency", nuNozzle);
end
end

function seaLevelFuelMassFlow_kg_s = localSeaLevelFuelMassFlow(engine)
seaLevelFuelMassFlow_kg_s = NaN;

if isfield(engine, "FuelFlow_kg_s") && isfinite(engine.FuelFlow_kg_s)
    seaLevelFuelMassFlow_kg_s = engine.FuelFlow_kg_s;
    return;
end

if isfield(engine, "SFC_kg_N_s") && isfinite(engine.SFC_kg_N_s) && ...
        isfield(engine, "SeaLevelStaticThrust_N") && ...
        isfinite(engine.SeaLevelStaticThrust_N)
    seaLevelFuelMassFlow_kg_s = engine.SFC_kg_N_s * ...
        engine.SeaLevelStaticThrust_N;
end
end

function result = localEmptyResult()
result = struct( ...
    "Name", "", ...
    "Type", "", ...
    "Engine", struct(), ...
    "Mach", [], ...
    "Altitude_m", [], ...
    "Atmosphere", table(), ...
    "Thrust_N", [], ...
    "TSFC_kg_N_s", [], ...
    "FuelMassFlow_kg_s", [], ...
    "MassFlow_kg_s", [], ...
    "ValidMask", [], ...
    "ModelParameters", struct());
end
