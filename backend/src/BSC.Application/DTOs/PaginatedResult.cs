namespace BSC.Application.DTOs;

/// <summary>
/// Resultado paginado generico para listados.
/// </summary>
/// <typeparam name="T">Tipo de los elementos en la lista.</typeparam>
public class PaginatedResult<T>
{
    public List<T> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
}
