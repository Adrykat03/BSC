using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.UpdateRole;

/// <summary>
/// Comando para actualizar un rol existente.
/// </summary>
public class UpdateRoleCommand : IRequest<ApiResponse<RoleDto>>
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public List<string> Modules { get; set; } = new();
}
