using BSC.Application.DTOs;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Commands.Create;

public class CreateColaboradorHandler : IRequestHandler<CreateColaboradorCommand, ApiResponse<ColaboradorDto>>
{
    private readonly IColaboradorRepository _repository;
    private readonly IRoleRepository _roleRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ILogger<CreateColaboradorHandler> _logger;

    public CreateColaboradorHandler(
        IColaboradorRepository repository,
        IRoleRepository roleRepository,
        IPasswordHasher passwordHasher,
        ILogger<CreateColaboradorHandler> logger)
    {
        _repository = repository;
        _roleRepository = roleRepository;
        _passwordHasher = passwordHasher;
        _logger = logger;
    }

    public async Task<ApiResponse<ColaboradorDto>> Handle(CreateColaboradorCommand request, CancellationToken cancellationToken)
    {
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

        // Check cedula uniqueness
        var existingByCedula = await _repository.GetByCedulaAsync(request.Cedula);
        if (existingByCedula != null)
        {
            return ApiResponse<ColaboradorDto>.Fail("Ya existe un colaborador con esa cédula.");
        }

        // Check correo uniqueness
        var existingByCorreo = await _repository.GetByCorreoAsync(request.Correo);
        if (existingByCorreo != null)
        {
            return ApiResponse<ColaboradorDto>.Fail("Ya existe un colaborador con ese correo.");
        }

        var colaborador = new Colaborador
        {
            NombreCompleto = request.NombreCompleto,
            Cedula = request.Cedula,
            Area = request.Area,
            Correo = request.Correo,
            RolIds = request.RolIds,
            PasswordHash = _passwordHasher.HashPassword(request.Password),
            CreatedAt = DateTime.UtcNow,
            CreatedBy = "system",
            IsDeleted = false
        };

        await _repository.CreateAsync(colaborador);

        _logger.LogInformation("Colaborador creado: {Id} - {NombreCompleto}", colaborador.Id, colaborador.NombreCompleto);

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

        return ApiResponse<ColaboradorDto>.Ok(dto, "Colaborador creado exitosamente.");
    }
}
