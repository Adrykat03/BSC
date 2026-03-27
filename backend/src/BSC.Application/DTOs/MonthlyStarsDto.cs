namespace BSC.Application.DTOs;

/// <summary>
/// DTO con las estrellas mensuales del colaborador.
/// </summary>
public class MonthlyStarsDto
{
    public int Stars { get; set; }
    public string Phrase { get; set; } = string.Empty;
    public string? BonusPhrase { get; set; }
    public double AvgRating { get; set; }
    public int TaskCount { get; set; }
    public bool HasTasks { get; set; }
}
