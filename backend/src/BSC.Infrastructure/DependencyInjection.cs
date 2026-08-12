using BSC.Application.Interfaces;
using BSC.Domain.Interfaces;
using BSC.Infrastructure.Persistence;
using BSC.Infrastructure.Persistence.Repositories;
using BSC.Infrastructure.Repositories;
using BSC.Infrastructure.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace BSC.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        string jwtSecretKey,
        string jwtIssuer,
        string jwtAudience,
        int jwtExpirationMinutes)
    {
        var connectionString = configuration["MongoDbSettings:ConnectionString"]
            ?? "mongodb://localhost:27017";
        var databaseName = configuration["MongoDbSettings:DatabaseName"]
            ?? "bsc_db";

        // Configure MongoDB class maps
        MongoDbMappings.Configure();

        var mongoDbContext = new MongoDbContext(connectionString, databaseName);
        services.AddSingleton(mongoDbContext);

        // Repositories
        services.AddScoped<IRoleRepository, RoleRepository>();
        services.AddScoped<ITaskItemRepository, TaskItemRepository>();
        services.AddScoped<IColaboradorRepository, ColaboradorRepository>();
        services.AddScoped<IBscDashboardConfigRepository, BscDashboardConfigRepository>();
        services.AddScoped<IAlertaHistorialRepository, AlertaHistorialRepository>();
        services.AddScoped<IAlertaAdjuntoRepository, AlertaAdjuntoRepository>();

        // Services
        services.AddSingleton<IPasswordHasher, BcryptPasswordHasher>();
        services.AddSingleton<IJwtTokenService>(
            new JwtTokenService(jwtSecretKey, jwtIssuer, jwtAudience, jwtExpirationMinutes));

        // Utilerias Payroll API (proxy de descarga de adjuntos)
        var utileriasBase = Environment.GetEnvironmentVariable("UTILERIAS_API_BASE")
            ?? configuration["UtileriasPayroll:BaseUrl"]
            ?? "https://utileriaspayroll.azurewebsites.net/api/Documentos/";
        var utileriasToken = Environment.GetEnvironmentVariable("UTILERIAS_TOKEN")
            ?? configuration["UtileriasPayroll:Token"]
            ?? string.Empty;

        // BaseAddress de HttpClient debe terminar en "/" para que las URIs relativas concatenen bien.
        if (!utileriasBase.EndsWith('/'))
        {
            utileriasBase += "/";
        }

        services.AddSingleton(new UtileriasPayrollOptions
        {
            BaseUrl = utileriasBase,
            Token = utileriasToken,
        });

        services.AddHttpClient<IUtileriasPayrollClient, UtileriasPayrollClient>(client =>
        {
            client.BaseAddress = new Uri(utileriasBase);
            client.Timeout = TimeSpan.FromSeconds(60);
        });

        // Data API Builder (DAB) - REST sobre Avisos.notificacionesConsolidadas.
        // Soporta override por env (DAB_BASE_URL) y fallback al setting de appsettings.
        var dabBase = Environment.GetEnvironmentVariable("DAB_BASE_URL")
            ?? configuration["DabSettings:BaseUrl"]
            ?? "http://bsc_dab:5000";
        if (!dabBase.EndsWith('/'))
        {
            dabBase += "/";
        }

        services.AddSingleton(new DabSettings { BaseUrl = dabBase });

        services.AddHttpClient<IDabAlertasClient, DabAlertasClient>(client =>
        {
            client.BaseAddress = new Uri(dabBase);
            client.Timeout = TimeSpan.FromSeconds(60);
        });

        // Cache en memoria (singleton, compartido entre requests) usado por
        // DabAlertasClient para no repetir el listado completo de alertas en
        // cada carga/auto-refresh de todos los usuarios conectados.
        services.AddMemoryCache();

        return services;
    }
}
