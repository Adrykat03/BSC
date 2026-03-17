using BSC.Application.DTOs;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Commands.Create;

public class CreateColaboradorHandler : IRequestHandler<CreateColaboradorCommand, ApiResponse<ColaboradorDto>>
{
    private readonly IColaboradorRepository _repository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ILogger<CreateColaboradorHandler> _logger;

    public CreateColaboradorHandler(
        IColaboradorRepository repository,
        IPasswordHasher passwordHasher,
        ILogger<CreateColaboradorHandler> logger)
    {
        _repository = repository;
        _passwordHasher = passwordHasher;
        _logger = logger;
    }

    public async Task<ApiResponse<ColaboradorDto>> Handle(CreateColaboradorCommand request, CancellationToken cancellationToken)
    {
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
            CreatedAt = colaborador.CreatedAt,
            UpdatedAt = colaborador.UpdatedAt
        };

        return ApiResponse<ColaboradorDto>.Ok(dto, "Colaborador creado exitosamente.");
    }
}
