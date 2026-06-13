using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;

namespace BSC.API.Authorization;

/// <summary>
/// Proveedor de policies dinamico: para cualquier policy con prefijo "MODULE:" genera
/// al vuelo una policy que exige el modulo correspondiente (via <see cref="ModuleRequirement"/>).
/// Esto evita tener que registrar manualmente una policy por cada modulo.
/// Para el resto de policies delega en el proveedor por defecto.
/// </summary>
public sealed class ModulePolicyProvider : IAuthorizationPolicyProvider
{
    private readonly DefaultAuthorizationPolicyProvider _fallback;

    public ModulePolicyProvider(IOptions<AuthorizationOptions> options)
    {
        _fallback = new DefaultAuthorizationPolicyProvider(options);
    }

    public Task<AuthorizationPolicy> GetDefaultPolicyAsync() => _fallback.GetDefaultPolicyAsync();

    public Task<AuthorizationPolicy?> GetFallbackPolicyAsync() => _fallback.GetFallbackPolicyAsync();

    public Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        if (policyName.StartsWith(RequireModuleAttribute.PolicyPrefix, StringComparison.Ordinal))
        {
            var module = policyName.Substring(RequireModuleAttribute.PolicyPrefix.Length);

            var policy = new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser()
                .AddRequirements(new ModuleRequirement(module))
                .Build();

            return Task.FromResult<AuthorizationPolicy?>(policy);
        }

        return _fallback.GetPolicyAsync(policyName);
    }
}
