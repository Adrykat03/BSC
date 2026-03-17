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
        // Validate role exists
        var role = await _roleRepository.GetByIdAsync(request.RolId);
        if (role == null || role.IsDeleted)
        {
            return ApiResponse<ColaboradorDto>.Fail("El rol especificado no existe.");
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
            RolId = request.RolId,
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
            RolId = colaborador.RolId,
            RolName = role.Name,
            CreatedAt = colaborador.CreatedAt,
            UpdatedAt = colaborador.UpdatedAt
        };

        return ApiResponse<ColaboradorDto>.Ok(dto, "Colaborador creado exitosamente.");
    }
}
