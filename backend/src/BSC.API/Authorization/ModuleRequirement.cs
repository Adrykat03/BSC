using Microsoft.AspNetCore.Authorization;

namespace BSC.API.Authorization;

/// <summary>
/// Requisito de autorizacion que exige la presencia de un modulo en el claim "modules" del JWT.
/// </summary>
public sealed class ModuleRequirement : IAuthorizationRequirement
{
    public ModuleRequirement(string module)
    {
        Module = module;
    }

    public string Module { get; }
}
