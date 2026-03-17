using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.SwitchRole;

/// <summary>
/// Comando para cambiar el rol activo del usuario autenticado.
/// </summary>
public class SwitchRoleCommand : IRequest<ApiResponse<LoginResponseDto>>
{
    /// <summary>
    /// Nombre del rol al que se desea cambiar.
    /// </summary>
    public string Role { get; set; } = string.Empty;

    /// <summary>
    /// ID del usuario autenticado (extraido del JWT por el controller).
    /// </summary>
    public string UserId { get; set; } = string.Empty;

    /// <summary>
    /// Nombre del usuario autenticado (extraido del JWT por el controller).
    /// </summary>
    public string UserName { get; set; } = string.Empty;

    /// <summary>
    /// Email del usuario autenticado (extraido del JWT por el controller).
    /// </summary>
    public string UserEmail { get; set; } = string.Empty;

    /// <summary>
    /// Lista de roles del usuario (extraida del JWT por el controller).
    /// </summary>
    public List<string> UserRoles { get; set; } = new();
}
