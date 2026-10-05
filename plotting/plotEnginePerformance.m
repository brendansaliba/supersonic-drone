function plotEnginePerformance(results)
%PLOTENGINEPERFORMANCE Plot core performance maps for each engine.

arguments
    results (1,:) struct
end

for iEngine = 1:numel(results)
    result = results(iEngine);

    figure("Name", result.Name + " Performance", "Color", "w");
    tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");

    nexttile;
    localPlotMap(result, result.Thrust_N ./ 1000);
    title("Thrust, kN");

    nexttile;
    localPlotMap(result, result.TSFC_kg_N_s .* 1e6);
    title("TSFC, mg/(N s)");

    nexttile;
    localPlotMap(result, result.FuelMassFlow_kg_s);
    title("Fuel Mass Flow, kg/s");

    nexttile;
    localPlotMap(result, double(result.ValidMask));
    title("Calculated Region");
    clim([0 1]);
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
