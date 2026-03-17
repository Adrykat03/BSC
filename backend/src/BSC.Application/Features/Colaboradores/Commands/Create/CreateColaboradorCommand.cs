using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Colaboradores.Commands.Create;

public class CreateColaboradorCommand : IRequest<ApiResponse<ColaboradorDto>>
{
    public string NombreCompleto { get; set; } = string.Empty;
    public string Cedula { get; set; } = string.Empty;
    public string Area { get; set; } = string.Empty;
    public string Correo { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public List<string> RolIds { get; set; } = new();
}
