function plotVehicleDrag(dragResults)
%PLOTVEHICLEDRAG Plot level-flight drag over Mach and altitude.

arguments
    dragResults (1,:) struct
end

for iVehicle = 1:numel(dragResults)
    result = dragResults(iVehicle);
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
