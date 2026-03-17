using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Colaboradores.Commands.Update;

public class UpdateColaboradorCommand : IRequest<ApiResponse<ColaboradorDto>>
{
    public string Id { get; set; } = string.Empty;
    public string NombreCompleto { get; set; } = string.Empty;
    public string Cedula { get; set; } = string.Empty;
    public string Area { get; set; } = string.Empty;
    public string Correo { get; set; } = string.Empty;
}
