using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Colaboradores.Commands.Delete;

public class DeleteColaboradorCommand : IRequest<ApiResponse<bool>>
{
    public string Id { get; set; } = string.Empty;
}
