using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Queries.GetRoleById;

/// <summary>
/// Query para obtener un rol por su ID.
/// </summary>
public class GetRoleByIdQuery : IRequest<ApiResponse<RoleDto>>
{
    public string Id { get; set; } = string.Empty;
}
