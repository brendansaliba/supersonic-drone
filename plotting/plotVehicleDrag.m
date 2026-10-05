function plotVehicleDrag(dragResults)
%PLOTVEHICLEDRAG Plot first-cut vehicle drag maps.

arguments
    dragResults (1,:) struct
end

for iVehicle = 1:numel(dragResults)
result = dragResults(iVehicle);

figure("Name", result.Name + " Drag", "Color", "w");
tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile;
localPlotMap(result, result.TotalDragCoefficient);
title("Total C_D");

nexttile;
localPlotMap(result, result.Drag_N);
title("Drag, N");

nexttile;
localPlotMap(result, result.LiftCoefficient);
title("Level-Flight C_L");

nexttile;
localPlotMap(result, result.WingWaveDragCoefficient + ...
    result.VolumeWaveDragCoefficient);
title("Wave Drag C_D");

figure("Name", result.Name + " Drag Surface", "Color", "w");
[machMesh, altitudeMesh_m] = meshgrid(result.Mach, result.Altitude_m);
surf(machMesh, altitudeMesh_m ./ 1000, result.Drag_N, ...
    "EdgeColor", "none");
colormap(gca, "turbo");
colorbar;
grid on;
box on;
view(135, 28);
title("Vehicle Drag Surface");
xlabel("Mach Number");
ylabel("Altitude, km");
zlabel("Drag, N");
end
end

function localPlotMap(result, values)
imagesc(result.Mach, result.Altitude_m ./ 1000, values);
set(gca, "YDir", "normal");
grid on;
colorbar;
xlabel("Mach Number");
ylabel("Altitude, km");
end
