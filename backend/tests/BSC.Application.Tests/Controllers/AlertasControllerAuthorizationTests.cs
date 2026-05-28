using System.Linq;
using System.Reflection;
using BSC.API.Controllers;
using BSC.Domain.Constants;
using FluentAssertions;
using Microsoft.AspNetCore.Authorization;
using Xunit;

namespace BSC.Application.Tests.Controllers;

/// <summary>
/// Cierre del Hallazgo Security A01 (IDOR sobre GET /api/alertas/{id}/historial).
///
/// Verifica que la autorizacion por rol del controlador AlertasController:
///   - Esta declarada (no solo [Authorize] simple).
///   - Incluye los roles administrativos/supervisores: Administrador, Gerente, Lider.
///   - NO incluye al rol Colaborador (que es el que permitiria enumerar emails de otros operadores).
///
/// La verificacion se hace por reflexion sobre los atributos del controlador.
/// Como ASP.NET Core aplica [Authorize(Roles=...)] en el pipeline antes de invocar la accion,
/// si la decoracion existe con los roles correctos, un usuario sin esos roles recibira 403.
/// </summary>
public class AlertasControllerAuthorizationTests
{
    private static AuthorizeAttribute GetClassAuthorizeAttribute()
    {
        var attr = typeof(AlertasController)
            .GetCustomAttributes<AuthorizeAttribute>(inherit: true)
            .FirstOrDefault();

        attr.Should().NotBeNull("AlertasController debe estar decorado con [Authorize(Roles=...)] " +
                                 "para evitar el IDOR descrito en el hallazgo Security A01.");
        return attr!;
    }

    [Fact]
    public void AlertasController_ShouldDeclareRolesAuthorization()
    {
        var attr = GetClassAuthorizeAttribute();

        attr.Roles.Should().NotBeNullOrWhiteSpace(
            "El [Authorize] del controlador debe especificar Roles=... para restringir el acceso.");
    }

    [Fact]
    public void AlertasController_ShouldIncludeAdministrativeRoles()
    {
        var attr = GetClassAuthorizeAttribute();
        var roles = (attr.Roles ?? string.Empty)
            .Split(',', System.StringSplitOptions.RemoveEmptyEntries | System.StringSplitOptions.TrimEntries)
            .ToList();

        roles.Should().Contain(TaskStateTransitions.RolAdministrador);
        roles.Should().Contain(TaskStateTransitions.RolGerente);
        roles.Should().Contain(TaskStateTransitions.RolLider);
    }

    [Fact]
    public void AlertasController_ShouldNotIncludeColaboradorRole()
    {
        var attr = GetClassAuthorizeAttribute();
        var roles = (attr.Roles ?? string.Empty)
            .Split(',', System.StringSplitOptions.RemoveEmptyEntries | System.StringSplitOptions.TrimEntries)
            .ToList();

        // El rol Colaborador no debe estar listado: permitiria a cualquier colaborador autenticado
        // leer emails de otros operadores en el historial (PII / IDOR).
        roles.Should().NotContain(TaskStateTransitions.RolColaborador,
            "Colaborador NO debe poder leer historiales de Alertas (hallazgo Security A01).");
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
                $"El metodo {method.Name} no debe tener [AllowAnonymous]; rompe la autorizacion por rol.");
        }
    }
}
