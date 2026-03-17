using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Features.Colaboradores.Queries.GetAll;

public class GetAllColaboradoresQuery : IRequest<ApiResponse<List<ColaboradorDto>>>
{
}
