using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Colaboradores.Queries.GetById;

public class GetColaboradorByIdQuery : IRequest<ApiResponse<ColaboradorDto>>
{
    public string Id { get; set; } = string.Empty;
}
