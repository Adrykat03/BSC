using BSC.Infrastructure.Persistence;
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

        var mongoDbContext = new MongoDbContext(connectionString, databaseName);
        services.AddSingleton(mongoDbContext);

        return services;
    }
}
