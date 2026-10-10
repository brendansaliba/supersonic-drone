function results = evaluateEnginePerformance(engines, machGrid, altitudeGrid_m, cycle)
%EVALUATEENGINEPERFORMANCE Turbojet thrust, fuel flow, and TSFC versus Mach
% and altitude.
%
% Each engine is a one-point cycle at its catalog OPR, EGT, and air mass
% flow. Corrected flow and OPR hold at that point until inlet total
% temperature exceeds the sea-level static value, where the redline exponents
% pull them down. Net thrust is gross thrust minus ram drag, including the
% convergent-nozzle pressure term when the nozzle is choked.
%
% Sea-level static net thrust is then scaled to installed thrust, and fuel
% flow is scaled to the catalog fuel flow. When the fuel-flow column and
% SFC * max thrust disagree, SFC * max thrust is used. Published altitude and
% Mach limits are not applied.

arguments
    engines (1,:) struct
    machGrid (1,:) double {mustBeNonnegative}
    altitudeGrid_m (1,:) double {mustBeNonnegative}
    cycle (1,1) struct = designParameters().cycle
end

atmosphere = standardAtmosphere(altitudeGrid_m(:));
seaLevel = standardAtmosphere(0);
[machMesh, ~] = meshgrid(machGrid, altitudeGrid_m);
temperatureMap_K = repmat(atmosphere.Temperature_K, 1, numel(machGrid));
pressureMap_Pa = repmat(atmosphere.Pressure_Pa, 1, numel(machGrid));

results = repmat(localEmptyResult(), 1, numel(engines));

for iEngine = 1:numel(engines)
    engine = engines(iEngine);
    rated = localRatedPoint(engine, cycle);

    reference = localTurbojetCycle(0, seaLevel.Temperature_K, ...
        seaLevel.Pressure_Pa, rated, cycle, seaLevel.Temperature_K, ...
        seaLevel.Pressure_Pa);
    if ~reference.Valid || ~isfinite(reference.NetThrust_N) || ...
            reference.NetThrust_N <= 0 || ~isfinite(reference.FuelMassFlow_kg_s) || ...
            reference.FuelMassFlow_kg_s <= 0
        error("evaluateEnginePerformance:SeaLevelCycleFailed", ...
            "Sea-level static cycle for '%s' is not physical. Check OPR, EGT, mass flow, and cycle efficiencies.", ...
            engine.Name);
    end

    map = localTurbojetCycle(machMesh, temperatureMap_K, pressureMap_Pa, ...
        rated, cycle, seaLevel.Temperature_K, seaLevel.Pressure_Pa);

    thrustScale = rated.AnchorThrust_N / reference.NetThrust_N;
    fuelScale = rated.AnchorFuel_kg_s / reference.FuelMassFlow_kg_s;
    thrust_N = map.NetThrust_N .* thrustScale;
    fuelMassFlow_kg_s = map.FuelMassFlow_kg_s .* fuelScale;
    tsfc_kg_N_s = fuelMassFlow_kg_s ./ thrust_N;
    tsfc_kg_N_s(thrust_N <= 1 | ~map.Valid) = NaN;

    results(iEngine).Name = engine.Name;
    results(iEngine).Type = engine.Type;
    results(iEngine).Engine = engine;
    results(iEngine).Mach = machGrid;
    results(iEngine).Altitude_m = altitudeGrid_m;
    results(iEngine).Atmosphere = atmosphere;
    results(iEngine).Thrust_N = thrust_N;
    results(iEngine).GrossThrust_N = map.GrossThrust_N .* thrustScale;
    results(iEngine).RamDrag_N = map.RamDrag_N .* thrustScale;
    results(iEngine).TSFC_kg_N_s = tsfc_kg_N_s;
    results(iEngine).FuelMassFlow_kg_s = fuelMassFlow_kg_s;
    results(iEngine).AirMassFlow_kg_s = map.AirMassFlow_kg_s;
    results(iEngine).MassFlow_kg_s = map.AirMassFlow_kg_s;
    results(iEngine).FuelAirRatio = map.FuelAirRatio;
    results(iEngine).ExhaustVelocity_m_s = map.ExhaustVelocity_m_s;
    results(iEngine).TurbineInletTemperature_K = map.TurbineInletTemperature_K;
    results(iEngine).CompressorPressureRatio = map.CompressorPressureRatio;
    results(iEngine).ValidMask = map.Valid;
    results(iEngine).ModelParameters = struct( ...
        "AnchorThrust_N", rated.AnchorThrust_N, ...
        "AnchorFuel_kg_s", rated.AnchorFuel_kg_s, ...
        "AnchorFuelSource", rated.AnchorFuelSource, ...
        "CycleSeaLevelStaticThrust_N", reference.NetThrust_N, ...
        "CycleSeaLevelStaticFuel_kg_s", reference.FuelMassFlow_kg_s, ...
        "ThrustScale", thrustScale, ...
        "FuelScale", fuelScale, ...
        "ExhaustGasTemperature_K", rated.ExhaustGasTemperature_K, ...
        "RatingBasis", "EGT held at the catalog maximum. Corrected flow and OPR hold at the catalog point until inlet total temperature exceeds sea-level static, then the redline exponents reduce them. Published altitude and Mach limits are not applied.");
end
end

function rated = localRatedPoint(engine, cycle)
if ~isfinite(engine.OverallPressureRatio) || engine.OverallPressureRatio <= 1
    error("evaluateEnginePerformance:MissingOPR", ...
        "Engine '%s' needs an overall pressure ratio above 1.", engine.Name);
end

if ~isfinite(engine.ReferenceMassFlow_kg_s) || engine.ReferenceMassFlow_kg_s <= 0
    error("evaluateEnginePerformance:MissingAirflow", ...
        "Engine '%s' needs a positive reference air mass flow.", engine.Name);
end

exhaustGasTemperature_K = engine.ExhaustGasTemperatureMax_K;
if ~isfinite(exhaustGasTemperature_K)
    exhaustGasTemperature_K = engine.ExhaustGasTemperatureContinuous_K;
end
if ~isfinite(exhaustGasTemperature_K) || exhaustGasTemperature_K < 400
    error("evaluateEnginePerformance:MissingEGT", ...
        "Engine '%s' needs an exhaust gas temperature.", engine.Name);
end

anchorThrust_N = engine.InstalledSeaLevelStaticThrust_N;
if ~isfinite(anchorThrust_N) || anchorThrust_N <= 0
    anchorThrust_N = engine.MaxThrust_N;
end
if ~isfinite(anchorThrust_N) || anchorThrust_N <= 0
    error("evaluateEnginePerformance:MissingThrust", ...
        "Engine '%s' needs a positive sea-level thrust.", engine.Name);
end

[anchorFuel_kg_s, anchorFuelSource] = localAnchorFuel(engine, cycle);

rated = struct( ...
    "Name", engine.Name, ...
    "OverallPressureRatio", engine.OverallPressureRatio, ...
    "ReferenceMassFlow_kg_s", engine.ReferenceMassFlow_kg_s, ...
    "ExhaustGasTemperature_K", exhaustGasTemperature_K, ...
    "AnchorThrust_N", anchorThrust_N, ...
    "AnchorFuel_kg_s", anchorFuel_kg_s, ...
    "AnchorFuelSource", anchorFuelSource);
end

function [fuel_kg_s, source] = localAnchorFuel(engine, cycle)
fuelFromColumn_kg_s = engine.FuelFlow_kg_s;
fuelFromSfc_kg_s = NaN;
if isfinite(engine.SFC_kg_N_s) && isfinite(engine.MaxThrust_N)
    fuelFromSfc_kg_s = engine.SFC_kg_N_s * engine.MaxThrust_N;
end

if isfinite(fuelFromColumn_kg_s) && isfinite(fuelFromSfc_kg_s)
    relativeGap = abs(fuelFromColumn_kg_s - fuelFromSfc_kg_s) / ...
        max(fuelFromSfc_kg_s, eps);
    if relativeGap > cycle.FuelFlowDisagreementTolerance
        fuel_kg_s = fuelFromSfc_kg_s;
        source = "SFC * max thrust (" + sprintf("%.3f", fuelFromSfc_kg_s * 60) + ...
            " kg/min). Fuel-flow column is " + ...
            sprintf("%.3f", fuelFromColumn_kg_s * 60) + " kg/min.";
        return;
    end

    fuel_kg_s = fuelFromColumn_kg_s;
    source = "Fuel-flow column";
    return;
end

if isfinite(fuelFromColumn_kg_s)
    fuel_kg_s = fuelFromColumn_kg_s;
    source = "Fuel-flow column";
    return;
end

if isfinite(fuelFromSfc_kg_s)
    fuel_kg_s = fuelFromSfc_kg_s;
    source = "SFC * max thrust";
    return;
end

error("evaluateEnginePerformance:MissingFuel", ...
    "Engine '%s' needs a fuel flow or an SFC.", engine.Name);
end

function point = localTurbojetCycle(mach, temperature_K, pressure_Pa, ...
    rated, cycle, seaLevelTemperature_K, seaLevelPressure_Pa)
gammaCold = cycle.ColdGamma;
gammaHot = cycle.HotGamma;
gasConstant = cycle.GasConstant_J_kgK;
cpCold = gammaCold * gasConstant / (gammaCold - 1);
cpHot = gammaHot * gasConstant / (gammaHot - 1);
exhaustTemperature_K = rated.ExhaustGasTemperature_K;

totalTemperatureRatio = 1 + 0.5 * (gammaCold - 1) .* mach.^2;
totalTemperature_K = temperature_K .* totalTemperatureRatio;
totalPressure_Pa = pressure_Pa .* ...
    totalTemperatureRatio .^ (gammaCold / (gammaCold - 1));

supersonic = mach > 1;
recoverySchedule = ones(size(mach));
recoverySchedule(supersonic) = 1 - cycle.SupersonicRecoveryCoefficient .* ...
    (mach(supersonic) - 1) .^ cycle.SupersonicRecoveryExponent;
inletRecovery = cycle.InletPressureRecovery .* recoverySchedule;
facePressure_Pa = totalPressure_Pa .* inletRecovery;

referenceFacePressure_Pa = seaLevelPressure_Pa * cycle.InletPressureRecovery;
correctedSpeedRatio = sqrt(seaLevelTemperature_K ./ totalTemperature_K);
redlineRatio = min(correctedSpeedRatio, 1);
pressureRatio = 1 + (rated.OverallPressureRatio - 1) .* ...
    redlineRatio .^ cycle.RedlinePressureExponent;
pressureRatio = max(pressureRatio, 1.01);
airMassFlow_kg_s = rated.ReferenceMassFlow_kg_s .* ...
    (facePressure_Pa ./ referenceFacePressure_Pa) .* ...
    sqrt(seaLevelTemperature_K ./ totalTemperature_K) .* ...
    redlineRatio .^ cycle.RedlineFlowExponent;

compressorTemperatureRatio = pressureRatio .^ ((gammaCold - 1) / gammaCold);
compressorExitTemperature_K = totalTemperature_K .* ...
    (1 + (compressorTemperatureRatio - 1) ./ cycle.CompressorIsentropicEfficiency);
compressorTemperatureRise_K = compressorExitTemperature_K - totalTemperature_K;

fuelDenominator = cycle.BurnerEfficiency * cycle.FuelHeatingValue_J_kg - ...
    cpHot * exhaustTemperature_K;
fuelRightHandSide = cpHot * exhaustTemperature_K + ...
    cpCold .* compressorTemperatureRise_K ./ cycle.MechanicalEfficiency - ...
    cpCold .* compressorExitTemperature_K;
fuelAirRatio = fuelRightHandSide ./ fuelDenominator;
fuelAirRatioSafe = max(fuelAirRatio, 0);
turbineInletTemperature_K = exhaustTemperature_K + ...
    cpCold .* compressorTemperatureRise_K ./ ...
    (cycle.MechanicalEfficiency .* (1 + fuelAirRatioSafe) .* cpHot);

turbineFacePressure_Pa = facePressure_Pa .* pressureRatio .* cycle.BurnerPressureRatio;
workFraction = (turbineInletTemperature_K - exhaustTemperature_K) ./ ...
    (cycle.TurbineIsentropicEfficiency .* turbineInletTemperature_K);
turbinePressureRatio = ones(size(mach));
turbineSolvable = workFraction > 0 & workFraction < 0.85;
turbinePressureRatio(turbineSolvable) = ...
    (1 - workFraction(turbineSolvable)) .^ (-gammaHot / (gammaHot - 1));
turbineExitPressure_Pa = turbineFacePressure_Pa ./ turbinePressureRatio;

flightSpeed_m_s = mach .* sqrt(gammaCold .* gasConstant .* temperature_K);
ramDrag_N = airMassFlow_kg_s .* flightSpeed_m_s;
gasMassFlow_kg_s = airMassFlow_kg_s .* (1 + fuelAirRatioSafe);

criticalPressureRatio = ((gammaHot + 1) / 2) ^ (gammaHot / (gammaHot - 1));
criticalExitPressure_Pa = turbineExitPressure_Pa ./ criticalPressureRatio;
choked = pressure_Pa <= criticalExitPressure_Pa & ...
    turbineExitPressure_Pa > pressure_Pa;

exitTemperature_K = exhaustTemperature_K * 2 / (gammaHot + 1);
chokedVelocity_m_s = sqrt(cycle.NozzleKineticEfficiency * gammaHot * ...
    gasConstant * exitTemperature_K);
massFlowParameter = sqrt(gammaHot / gasConstant) * ...
    (2 / (gammaHot + 1)) ^ ((gammaHot + 1) / (2 * (gammaHot - 1)));
exitArea_m2 = gasMassFlow_kg_s .* sqrt(exhaustTemperature_K) ./ ...
    (turbineExitPressure_Pa .* massFlowParameter);
grossChoked_N = gasMassFlow_kg_s .* chokedVelocity_m_s + ...
    (criticalExitPressure_Pa - pressure_Pa) .* exitArea_m2;

expansionRatio = max(pressure_Pa ./ turbineExitPressure_Pa, 1e-8);
unchokedVelocity_m_s = sqrt(max(0, 2 * cpHot * cycle.NozzleKineticEfficiency * ...
    exhaustTemperature_K .* (1 - expansionRatio .^ ((gammaHot - 1) / gammaHot))));
grossUnchoked_N = gasMassFlow_kg_s .* unchokedVelocity_m_s;

grossThrust_N = grossUnchoked_N;
exhaustVelocity_m_s = unchokedVelocity_m_s;
grossThrust_N(choked) = grossChoked_N(choked);
exhaustVelocity_m_s(choked) = chokedVelocity_m_s;

netThrust_N = grossThrust_N - ramDrag_N;
valid = turbineSolvable & fuelAirRatio > 0 & fuelAirRatio < 0.08 & ...
    turbineExitPressure_Pa > pressure_Pa & isfinite(netThrust_N) & ...
    airMassFlow_kg_s > 0;

netThrust_N(~valid) = NaN;
grossThrust_N(~valid) = NaN;
ramDrag_N(~valid) = NaN;
fuelAirRatio(~valid) = NaN;
exhaustVelocity_m_s(~valid) = NaN;
turbineInletTemperature_K(~valid) = NaN;
airMassFlow_kg_s(~valid) = NaN;

point = struct( ...
    "NetThrust_N", netThrust_N, ...
    "GrossThrust_N", grossThrust_N, ...
    "RamDrag_N", ramDrag_N, ...
    "FuelMassFlow_kg_s", airMassFlow_kg_s .* fuelAirRatio, ...
    "AirMassFlow_kg_s", airMassFlow_kg_s, ...
    "FuelAirRatio", fuelAirRatio, ...
    "ExhaustVelocity_m_s", exhaustVelocity_m_s, ...
    "TurbineInletTemperature_K", turbineInletTemperature_K, ...
    "CompressorPressureRatio", pressureRatio, ...
    "Valid", valid);
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
    "GrossThrust_N", [], ...
    "RamDrag_N", [], ...
    "TSFC_kg_N_s", [], ...
    "FuelMassFlow_kg_s", [], ...
    "AirMassFlow_kg_s", [], ...
    "MassFlow_kg_s", [], ...
    "FuelAirRatio", [], ...
    "ExhaustVelocity_m_s", [], ...
    "TurbineInletTemperature_K", [], ...
    "CompressorPressureRatio", [], ...
    "ValidMask", [], ...
    "ModelParameters", struct());
end
