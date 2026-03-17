using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Features.Colaboradores.Commands.Delete;

public class DeleteColaboradorHandler : IRequestHandler<DeleteColaboradorCommand, ApiResponse<bool>>
{
    private readonly IColaboradorRepository _repository;
    private readonly ILogger<DeleteColaboradorHandler> _logger;

    public DeleteColaboradorHandler(IColaboradorRepository repository, ILogger<DeleteColaboradorHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<ApiResponse<bool>> Handle(DeleteColaboradorCommand request, CancellationToken cancellationToken)
    {
        var colaborador = await _repository.GetByIdAsync(request.Id);

        if (colaborador == null || colaborador.IsDeleted)
        {
            return ApiResponse<bool>.Fail("Colaborador no encontrado.");
        }

        colaborador.IsDeleted = true;
        colaborador.DeletedAt = DateTime.UtcNow;

        await _repository.UpdateAsync(colaborador);

        _logger.LogInformation("Colaborador eliminado (soft delete): {Id} - {NombreCompleto}", colaborador.Id, colaborador.NombreCompleto);

        return ApiResponse<bool>.Ok(true, "Colaborador eliminado exitosamente.");
    }
}
