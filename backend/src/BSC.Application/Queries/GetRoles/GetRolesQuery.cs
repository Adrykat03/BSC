using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Queries.GetRoles;

/// <summary>
/// Query para obtener la lista paginada de roles.
/// </summary>
public class GetRolesQuery : IRequest<ApiResponse<PaginatedResult<RoleDto>>>
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}
