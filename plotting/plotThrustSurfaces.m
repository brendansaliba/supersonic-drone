function plotThrustSurfaces(results)
%PLOTTHRUSTSURFACES Plot thrust surfaces over Mach number and altitude.

arguments
    results (1,:) struct
end

figure("Name", "Engine Thrust Surfaces", "Color", "w");
tiledlayout("flow", "TileSpacing", "compact", "Padding", "compact");

for iEngine = 1:numel(results)
    result = results(iEngine);
    [machMesh, altitudeMesh_m] = meshgrid(result.Mach, result.Altitude_m);

    nexttile;
    surf(machMesh, altitudeMesh_m ./ 1000, result.Thrust_N ./ 1000, ...
        "EdgeColor", "none");
    colormap(gca, "turbo");
    colorbar;
    grid on;
    box on;
    view(135, 28);

    title(result.Name, "Interpreter", "none");
    xlabel("Mach Number");
    ylabel("Altitude, km");
    zlabel("Thrust, kN");
end
end
