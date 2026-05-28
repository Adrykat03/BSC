using BSC.Application.Behaviors;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace BSC.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        var assembly = typeof(DependencyInjection).Assembly;

        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(assembly);
            // ValidationBehavior se registra como pipeline behavior global de MediatR.
            // Esto engancha automaticamente FluentValidation a TODOS los IRequest<T>
            // del assembly (incluido ChangeAlertaStatusCommand).
            cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
        });

        // Registra todos los AbstractValidator<T> del assembly (FluentValidation DI).
        services.AddValidatorsFromAssembly(assembly);

        return services;
    }
}
