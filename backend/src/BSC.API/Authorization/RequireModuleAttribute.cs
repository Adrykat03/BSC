using Microsoft.AspNetCore.Authorization;

namespace BSC.API.Authorization;

/// <summary>
/// Exige que el JWT del usuario contenga el modulo indicado en el claim "modules".
/// Basado en autorizacion por policy: el prefijo de la policy codifica la key del modulo.
/// Si el claim falta o el modulo no esta presente, se deniega el acceso (403).
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false, Inherited = true)]
public sealed class RequireModuleAttribute : AuthorizeAttribute
{
    public const string PolicyPrefix = "MODULE:";

    public RequireModuleAttribute(string module)
    {
        Module = module;
        Policy = $"{PolicyPrefix}{module}";
    }

    /// <summary>
    /// Key del modulo requerido (catalogo <see cref="BSC.Domain.Constants.Modules"/>).
    /// </summary>
    public string Module { get; }
}
