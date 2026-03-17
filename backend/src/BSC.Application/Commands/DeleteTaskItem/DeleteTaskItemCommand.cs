using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Commands.DeleteTaskItem;

/// <summary>
/// Comando para eliminar una tarea (soft delete).
/// </summary>
public class DeleteTaskItemCommand : IRequest<ApiResponse<object>>
{
    public string Id { get; set; } = string.Empty;
}
