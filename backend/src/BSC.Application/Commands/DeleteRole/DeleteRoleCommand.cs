using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.DeleteRole;

/// <summary>
/// Comando para eliminar un rol (soft delete).
/// </summary>
public class DeleteRoleCommand : IRequest<ApiResponse<object>>
{
    public string Id { get; set; } = string.Empty;
}
