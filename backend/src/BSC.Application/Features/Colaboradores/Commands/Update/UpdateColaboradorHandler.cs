using BSC.Application.DTOs;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Commands.Update;

public class UpdateColaboradorHandler : IRequestHandler<UpdateColaboradorCommand, ApiResponse<ColaboradorDto>>
{
    private readonly IColaboradorRepository _repository;
    private readonly IRoleRepository _roleRepository;
    private readonly ILogger<UpdateColaboradorHandler> _logger;

    public UpdateColaboradorHandler(
        IColaboradorRepository repository,
        IRoleRepository roleRepository,
        ILogger<UpdateColaboradorHandler> logger)
    {
        _repository = repository;
        _roleRepository = roleRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<ColaboradorDto>> Handle(UpdateColaboradorCommand request, CancellationToken cancellationToken)
    {
        var colaborador = await _repository.GetByIdAsync(request.Id);

        if (colaborador == null || colaborador.IsDeleted)
        {
            return ApiResponse<ColaboradorDto>.Fail("Colaborador no encontrado.");
        }

        // Validate all roles exist
        var roles = new List<Role>();
        foreach (var rolId in request.RolIds)
        {
            var role = await _roleRepository.GetByIdAsync(rolId);
            if (role == null || role.IsDeleted)
            {
                return ApiResponse<ColaboradorDto>.Fail($"El rol con ID '{rolId}' no existe.");
            }
            roles.Add(role);
        }

        // Validate Gerente exclusivity: if any role is Gerente, it must be the only one
        var roleNames = roles.Select(r => r.Name).ToList();
        if (roleNames.Any(n => n.Equals("Gerente", StringComparison.OrdinalIgnoreCase)) && roles.Count > 1)
        {
            return ApiResponse<ColaboradorDto>.Fail("El rol 'Gerente' es exclusivo y no puede combinarse con otros roles.");
        }

        // Check cedula uniqueness excluding current
        var existingByCedula = await _repository.GetByCedulaAsync(request.Cedula);
        if (existingByCedula != null && existingByCedula.Id != request.Id)
        {
            return ApiResponse<ColaboradorDto>.Fail("Ya existe otro colaborador con esa cédula.");
        }

        // Check correo uniqueness excluding current
        var existingByCorreo = await _repository.GetByCorreoAsync(request.Correo);
        if (existingByCorreo != null && existingByCorreo.Id != request.Id)
        {
            return ApiResponse<ColaboradorDto>.Fail("Ya existe otro colaborador con ese correo.");
        }

        colaborador.NombreCompleto = request.NombreCompleto;
        colaborador.Cedula = request.Cedula;
        colaborador.Area = request.Area;
        colaborador.Correo = request.Correo;
        colaborador.RolIds = request.RolIds;
        colaborador.UpdatedAt = DateTime.UtcNow;
        colaborador.UpdatedBy = "system";

        await _repository.UpdateAsync(colaborador);

        _logger.LogInformation("Colaborador actualizado: {Id} - {NombreCompleto}", colaborador.Id, colaborador.NombreCompleto);

        var dto = new ColaboradorDto
        {
            Id = colaborador.Id,
            NombreCompleto = colaborador.NombreCompleto,
            Cedula = colaborador.Cedula,
            Area = colaborador.Area,
            Correo = colaborador.Correo,
            RolIds = colaborador.RolIds,
            RolNames = roleNames,
            CreatedAt = colaborador.CreatedAt,
            UpdatedAt = colaborador.UpdatedAt
        };

        return ApiResponse<ColaboradorDto>.Ok(dto, "Colaborador actualizado exitosamente.");
    }
}
