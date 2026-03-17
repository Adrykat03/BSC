namespace BSC.Application.DTOs;

public class ColaboradorDto
{
    public string Id { get; set; } = string.Empty;
    public string NombreCompleto { get; set; } = string.Empty;
    public string Cedula { get; set; } = string.Empty;
    public string Area { get; set; } = string.Empty;
    public string Correo { get; set; } = string.Empty;
    public List<string> RolIds { get; set; } = new();
    public List<string> RolNames { get; set; } = new();
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}
