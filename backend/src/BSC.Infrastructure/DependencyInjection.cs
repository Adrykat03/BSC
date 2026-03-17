using BSC.Domain.Interfaces;
using BSC.Infrastructure.Persistence;
using BSC.Infrastructure.Repositories;
using BSC.Infrastructure.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BSC.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
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
        services.AddScoped<IColaboradorRepository, ColaboradorRepository>();

        // Services
        services.AddSingleton<IPasswordHasher, BcryptPasswordHasher>();

        return services;
    }
}
