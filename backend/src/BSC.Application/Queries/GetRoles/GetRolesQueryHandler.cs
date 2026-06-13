using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Queries.GetRoles;

/// <summary>
/// Handler para la query de listado de roles.
/// </summary>
public class GetRolesQueryHandler : IRequestHandler<GetRolesQuery, ApiResponse<PaginatedResult<RoleDto>>>
{
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<GetRolesQueryHandler> _logger;

    public GetRolesQueryHandler(IRoleRepository roleRepository, ILogger<GetRolesQueryHandler> logger)
    {
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<PaginatedResult<RoleDto>>> Handle(GetRolesQuery request, CancellationToken cancellationToken)
    {
        // Limitar pageSize a maximo 100
        var pageSize = Math.Min(request.PageSize, 100);
        var page = Math.Max(request.Page, 1);

        var roles = await _roleRepository.GetAllAsync(page, pageSize);
        var totalCount = await _roleRepository.GetTotalCountAsync();

        var dtos = roles.Select(r => new RoleDto
        {
            Id = r.Id,
            Name = r.Name,
            Description = r.Description,
            Modules = r.Modules,
            CreatedAt = r.CreatedAt,
            UpdatedAt = r.UpdatedAt
        }).ToList();

        var result = new PaginatedResult<RoleDto>
        {
            Items = dtos,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };

        return ApiResponse<PaginatedResult<RoleDto>>.Ok(result);
    }
}
