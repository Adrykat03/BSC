using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

public interface IColaboradorRepository
{
    Task<List<Colaborador>> GetAllAsync();
    Task<Colaborador?> GetByIdAsync(string id);
    Task<Colaborador?> GetByCedulaAsync(string cedula);
    Task<Colaborador?> GetByCorreoAsync(string correo);
    Task CreateAsync(Colaborador colaborador);
    Task UpdateAsync(Colaborador colaborador);
    Task DeleteAsync(string id);
}
