namespace BSC.Domain.Entities;

public class Colaborador
{
    public string Id { get; set; } = string.Empty;

    public string NombreCompleto { get; set; } = string.Empty;

    public string Cedula { get; set; } = string.Empty;

    public string Area { get; set; } = string.Empty;

    public string Correo { get; set; } = string.Empty;

    public string RolId { get; set; } = string.Empty;

    public string PasswordHash { get; set; } = string.Empty;

    // Audit fields
    public DateTime CreatedAt { get; set; }

    public string CreatedBy { get; set; } = string.Empty;

    public DateTime? UpdatedAt { get; set; }

    public string? UpdatedBy { get; set; }

    public bool IsDeleted { get; set; }

    public DateTime? DeletedAt { get; set; }
}
