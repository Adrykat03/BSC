using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;

namespace BSC.API.Authorization;

/// <summary>
/// Handler que evalua el <see cref="ModuleRequirement"/> leyendo el claim "modules" del JWT.
/// El claim "modules" es un array JSON serializado de keys de modulo (mismo patron que "roles").
///
/// Override a nivel de accion: si el endpoint declara un <see cref="RequireModuleAttribute"/> a
/// nivel de accion (metodo), ese modulo PREVALECE sobre el declarado a nivel de controlador.
/// Asi, p.ej. TasksController exige "tareas" pero la accion GetDashboard exige unicamente
/// "dashboard" (y no ambos), respetando el contrato.
///
/// Defensa en profundidad: si el claim falta o el modulo efectivo no esta presente, NO se cumple
/// el requisito y la autorizacion falla (la API responde 403).
/// </summary>
public sealed class ModuleAuthorizationHandler : AuthorizationHandler<ModuleRequirement>
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public ModuleAuthorizationHandler(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ModuleRequirement requirement)
    {
        var effectiveModule = ResolveEffectiveModule(requirement.Module);

        var modules = ReadModulesClaim(context.User);
        if (modules == null)
        {
            // Sin claim de modulos o claim malformado => denegar explicitamente.
            return Task.CompletedTask;
        }

        if (modules.Contains(effectiveModule))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }

    /// <summary>
    /// Si el endpoint actual tiene un <see cref="RequireModuleAttribute"/> declarado a nivel de
    /// accion, ese modulo prevalece sobre el del requisito (que pudo originarse en el controlador).
    /// </summary>
    private string ResolveEffectiveModule(string requirementModule)
    {
        var endpoint = _httpContextAccessor.HttpContext?.GetEndpoint();
        var actionDescriptor = endpoint?.Metadata
            .GetMetadata<Microsoft.AspNetCore.Mvc.Controllers.ControllerActionDescriptor>();

        if (actionDescriptor != null)
        {
            var actionLevel = actionDescriptor.MethodInfo
                .GetCustomAttributes(typeof(RequireModuleAttribute), inherit: true)
                .Cast<RequireModuleAttribute>()
                .FirstOrDefault();

            if (actionLevel != null)
            {
                return actionLevel.Module;
            }
        }

        return requirementModule;
    }

    private static List<string>? ReadModulesClaim(System.Security.Claims.ClaimsPrincipal user)
    {
        var modulesClaim = user.FindFirst("modules")?.Value;
        if (string.IsNullOrWhiteSpace(modulesClaim))
        {
            return null;
        }

        try
        {
            return JsonSerializer.Deserialize<List<string>>(modulesClaim);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
