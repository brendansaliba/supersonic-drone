function vehicles = defineVehicle(engines, vehicleDesign)
%DEFINEVEHICLE Build one vehicle per engine from the design-parameter struct.
% User sweep angles are degrees. Derived geometry, including sweep in radians,
% is written onto each vehicle before the drag model runs. Every vehicle is
% flown at MaximumTakeoffMass_kg.

arguments
    engines (1,:) struct
    vehicleDesign (1,1) struct = designParameters().vehicle
end

vehicles = repmat(localBuildVehicle(vehicleDesign, engines(1)), 1, numel(engines));

for iVehicle = 1:numel(engines)
    vehicles(iVehicle) = localBuildVehicle(vehicleDesign, engines(iVehicle));
end
end

function vehicle = localBuildVehicle(design, engine)
vehicle = design;

engineDiameter_m = engine.OuterDiameter_m;
if ~isfinite(engineDiameter_m) || engineDiameter_m <= 0
    engineDiameter_m = 0.15;
end

engineCount = max(design.EngineCount, 1);
if isfinite(design.FuselageDiameter_m) && design.FuselageDiameter_m > 0
    fuselageDiameter_m = design.FuselageDiameter_m;
else
    fuselageDiameter_m = design.FuselageToEngineDiameterRatio * ...
        engineDiameter_m * sqrt(engineCount);
end

engineMass_kg = engine.InstalledMass_kg;
if ~isfinite(engineMass_kg)
    engineMass_kg = engine.DryMass_kg;
end
if ~isfinite(engineMass_kg)
    engineMass_kg = 0;
end

if ~isfinite(design.MaximumTakeoffMass_kg) || design.MaximumTakeoffMass_kg <= 0
    error("defineVehicle:BadTakeoffMass", ...
        "MaximumTakeoffMass_kg must be a positive mass.");
end
if engineMass_kg >= design.MaximumTakeoffMass_kg
    error("defineVehicle:EngineExceedsTakeoffMass", ...
        "%s installed mass is %.2f kg, which is not below the %.2f kg takeoff mass.", ...
        engine.Name, engineMass_kg, design.MaximumTakeoffMass_kg);
end

taperRatio = min(max(design.WingTaperRatio, 0.05), 1);
span_m = design.WingSpan_m;
referenceArea_m2 = design.ReferenceArea_m2;
rootChord_m = 2 * referenceArea_m2 / (span_m * (1 + taperRatio));
tipChord_m = taperRatio * rootChord_m;
meanAerodynamicChord_m = (2 / 3) * rootChord_m * ...
    (1 + taperRatio + taperRatio^2) / (1 + taperRatio);
aspectRatio = span_m^2 / referenceArea_m2;
geometricChord_m = referenceArea_m2 / span_m;

quarterChordSweep_rad = deg2rad(design.WingQuarterChordSweep_deg);
maxThicknessSweep_rad = localSweepAtChordFraction( ...
    quarterChordSweep_rad, aspectRatio, taperRatio, ...
    design.WingMaxThicknessLocationChord);

if isfinite(design.TailQuarterChordSweep_deg)
    tailQuarterChordSweep_deg = design.TailQuarterChordSweep_deg;
else
    tailQuarterChordSweep_deg = design.WingQuarterChordSweep_deg;
end
tailQuarterChordSweep_rad = deg2rad(tailQuarterChordSweep_deg);
tailMaxThicknessSweep_rad = localSweepAtChordFraction( ...
    tailQuarterChordSweep_rad, aspectRatio, taperRatio, ...
    design.TailMaxThicknessLocationChord);

exposedArea_m2 = referenceArea_m2 * design.WingExposedAreaFraction;
wingWettedArea_m2 = 2 * exposedArea_m2 * ...
    (1 + 0.25 * design.WingThicknessToChord);
tailWettedArea_m2 = design.TailToWingWettedRatio * wingWettedArea_m2;
frontalArea_m2 = pi * (fuselageDiameter_m / 2)^2;

vehicle.Name = "Vehicle with " + engine.Name;
vehicle.EngineName = engine.Name;
vehicle.EngineCount = engineCount;
vehicle.EngineOuterDiameter_m = engineDiameter_m;
vehicle.EngineInstalledMass_kg = engineMass_kg;
vehicle.GrossMass_kg = design.MaximumTakeoffMass_kg;
vehicle.FuselageDiameter_m = fuselageDiameter_m;
vehicle.FuselageFrontalArea_m2 = frontalArea_m2;
vehicle.FuselageFinenessRatio = design.FuselageLength_m / fuselageDiameter_m;
vehicle.FuselageWettedArea_m2 = pi * fuselageDiameter_m * design.FuselageLength_m;
vehicle.FuselageVolume_m3 = design.FuselageVolumeFill * frontalArea_m2 * ...
    design.FuselageLength_m;
vehicle.AspectRatio = aspectRatio;
vehicle.WingTaperRatio = taperRatio;
vehicle.WingRootChord_m = rootChord_m;
vehicle.WingTipChord_m = tipChord_m;
vehicle.MeanAerodynamicChord_m = meanAerodynamicChord_m;
vehicle.GeometricMeanChord_m = geometricChord_m;
vehicle.WingQuarterChordSweep_rad = quarterChordSweep_rad;
vehicle.WingMaxThicknessSweep_rad = maxThicknessSweep_rad;
vehicle.TailQuarterChordSweep_deg = tailQuarterChordSweep_deg;
vehicle.TailQuarterChordSweep_rad = tailQuarterChordSweep_rad;
vehicle.TailMaxThicknessSweep_rad = tailMaxThicknessSweep_rad;
vehicle.WingExposedArea_m2 = exposedArea_m2;
vehicle.WingWettedArea_m2 = wingWettedArea_m2;
vehicle.WingVolume_m3 = design.WingVolumeFill * exposedArea_m2 * ...
    design.WingThicknessToChord * geometricChord_m;
vehicle.TailWettedArea_m2 = tailWettedArea_m2;
vehicle.TailChord_m = design.TailChordOverMeanAerodynamicChord * ...
    meanAerodynamicChord_m;

if isfinite(engine.Length_m) && design.FuselageLength_m < engine.Length_m
    warning("defineVehicle:FuselageShorterThanEngine", ...
        "%s is %.3f m long and the fuselage is %.3f m long.", ...
        engine.Name, engine.Length_m, design.FuselageLength_m);
end
end

function sweep_rad = localSweepAtChordFraction( ...
    quarterChordSweep_rad, aspectRatio, taperRatio, chordFraction)
% Trapezoidal-wing sweep at a constant chord fraction.
spanLoading = (1 - taperRatio) / (1 + taperRatio);
tanSweep = tan(quarterChordSweep_rad) - ...
    (4 / aspectRatio) * (chordFraction - 0.25) * spanLoading;
sweep_rad = atan(tanSweep);
end
