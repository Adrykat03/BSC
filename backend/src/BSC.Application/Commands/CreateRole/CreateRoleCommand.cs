using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.CreateRole;

/// <summary>
/// Comando para crear un nuevo rol.
/// </summary>
public class CreateRoleCommand : IRequest<ApiResponse<RoleDto>>
{
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public List<string> Modules { get; set; } = new();
}
