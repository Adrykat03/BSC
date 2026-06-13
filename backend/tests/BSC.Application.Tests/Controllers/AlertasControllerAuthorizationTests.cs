using System.Linq;
using System.Reflection;
using BSC.API.Authorization;
using BSC.API.Controllers;
using BSC.Domain.Constants;
using FluentAssertions;
using Microsoft.AspNetCore.Authorization;
using Xunit;

namespace BSC.Application.Tests.Controllers;

/// <summary>
/// Cierre del Hallazgo Security A01 (IDOR sobre GET /api/alertas/{id}/historial), adaptado al
/// nuevo modelo de autorizacion por MODULO.
///
/// Verifica que el AlertasController:
///   - Exige autenticacion ([Authorize]).
///   - Esta restringido por el modulo "alertas-payroll" mediante [RequireModule].
///   - Ningun endpoint usa [AllowAnonymous] (no debe romper la autorizacion).
///
/// El acceso ya NO se controla por nombre de rol sino por la pertenencia del rol activo al
/// modulo "alertas-payroll" (claim "modules" del JWT). Como el rol Colaborador NO incluye ese
/// modulo en la matriz por defecto, sigue sin poder enumerar historiales (cierre del A01).
/// </summary>
public class AlertasControllerAuthorizationTests
{
    private static RequireModuleAttribute GetClassRequireModuleAttribute()
    {
        var attr = typeof(AlertasController)
            .GetCustomAttributes<RequireModuleAttribute>(inherit: true)
            .FirstOrDefault();

        attr.Should().NotBeNull("AlertasController debe estar decorado con [RequireModule] " +
                                 "para restringir el acceso por modulo (modelo de permisos por modulo).");
        return attr!;
    }

    [Fact]
    public void AlertasController_ShouldRequireAuthentication()
    {
        var authorize = typeof(AlertasController)
            .GetCustomAttributes<AuthorizeAttribute>(inherit: true)
            .ToList();

        authorize.Should().NotBeEmpty(
            "AlertasController debe exigir autenticacion ([Authorize] o [RequireModule], que hereda de AuthorizeAttribute).");
    }

    [Fact]
    public void AlertasController_ShouldRequireAlertasPayrollModule()
    {
        var attr = GetClassRequireModuleAttribute();

        attr.Module.Should().Be(Modules.AlertasPayroll,
            "el controlador de Alertas debe exigir el modulo 'alertas-payroll'.");
    }

    [Fact]
    public void RequireModule_ShouldMapToPolicyWithModulePrefix()
    {
        var attr = GetClassRequireModuleAttribute();

        attr.Policy.Should().Be(RequireModuleAttribute.PolicyPrefix + Modules.AlertasPayroll,
            "la policy debe codificar el modulo para que el IAuthorizationPolicyProvider la resuelva.");
    }

    [Fact]
    public void GetHistorial_ShouldNotOverrideAuthorizationWithAllowAnonymous()
    {
        // Defensa adicional: ningun endpoint del controlador debe tener [AllowAnonymous].
        var methods = typeof(AlertasController)
            .GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);

        foreach (var method in methods)
        {
            var allowAnonymous = method.GetCustomAttributes<AllowAnonymousAttribute>(inherit: true).Any();
            allowAnonymous.Should().BeFalse(
                $"El metodo {method.Name} no debe tener [AllowAnonymous]; rompe la autorizacion por modulo.");
        }
    }
}
