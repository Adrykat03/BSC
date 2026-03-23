using System.Text.RegularExpressions;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MongoDB.Driver;

namespace BSC.Infrastructure.Persistence.Repositories;

/// <summary>
/// Implementacion del repositorio de tareas con MongoDB.
/// </summary>
public class TaskItemRepository : ITaskItemRepository
{
    private readonly IMongoCollection<TaskItem> _collection;

    public TaskItemRepository(MongoDbContext context)
    {
        _collection = context.GetCollection<TaskItem>("TaskItems");
    }

    private static FilterDefinition<TaskItem> ApplySearchFilter(FilterDefinition<TaskItem> filter, string? search)
    {
        if (!string.IsNullOrWhiteSpace(search))
        {
            var escaped = Regex.Escape(search);
            var searchFilter = Builders<TaskItem>.Filter.Or(
                Builders<TaskItem>.Filter.Regex(t => t.Title, new MongoDB.Bson.BsonRegularExpression(escaped, "i")),
                Builders<TaskItem>.Filter.Regex(t => t.Description, new MongoDB.Bson.BsonRegularExpression(escaped, "i")),
                Builders<TaskItem>.Filter.Regex(t => t.AssignedToName, new MongoDB.Bson.BsonRegularExpression(escaped, "i")),
                Builders<TaskItem>.Filter.Regex(t => t.AssignedLeaderName, new MongoDB.Bson.BsonRegularExpression(escaped, "i"))
            );
            filter &= searchFilter;
        }
        return filter;
    }

    public async Task<List<TaskItem>> GetAllAsync(int page, int pageSize, string? search = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        filter = ApplySearchFilter(filter, search);
        var skip = (page - 1) * pageSize;

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetTotalCountAsync(string? search = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        filter = ApplySearchFilter(filter, search);
        return (int)await _collection.CountDocumentsAsync(filter);
    }

    /// <summary>
    /// Construye el filtro de visibilidad: si visibleBeforeDeadline tiene valor,
    /// muestra tareas cuya DueDate >= ahora (cualquier estado) O que esten en los estados permitidos.
    /// </summary>
    private static FilterDefinition<TaskItem> BuildVisibilityFilter(List<string> statuses, DateTime? visibleBeforeDeadline)
    {
        var statusFilter = Builders<TaskItem>.Filter.In(t => t.Status, statuses);

        if (visibleBeforeDeadline.HasValue)
        {
            var deadlineFilter = Builders<TaskItem>.Filter.Gte(t => t.DueDate, visibleBeforeDeadline.Value);
            return Builders<TaskItem>.Filter.Or(deadlineFilter, statusFilter);
        }

        return statusFilter;
    }

    public async Task<List<TaskItem>> GetByLeaderEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, DateTime? visibleBeforeDeadline = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & BuildVisibilityFilter(statuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);

        var skip = (page - 1) * pageSize;

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByLeaderEmailAsync(string email, List<string> statuses, string? search = null, DateTime? visibleBeforeDeadline = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & BuildVisibilityFilter(statuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);

        return (int)await _collection.CountDocumentsAsync(filter);
    }

    public async Task<List<TaskItem>> GetByAssignedEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, DateTime? visibleBeforeDeadline = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & BuildVisibilityFilter(statuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);

        var skip = (page - 1) * pageSize;

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByAssignedEmailAsync(string email, List<string> statuses, string? search = null, DateTime? visibleBeforeDeadline = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & BuildVisibilityFilter(statuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);

        return (int)await _collection.CountDocumentsAsync(filter);
    }

    public async Task<TaskItem?> GetByIdAsync(string id)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.Id, id)
                   & Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        return await _collection.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<TaskItem> CreateAsync(TaskItem taskItem)
    {
        await _collection.InsertOneAsync(taskItem);
        return taskItem;
    }

    public async Task<TaskItem> UpdateAsync(TaskItem taskItem)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.Id, taskItem.Id);
        await _collection.ReplaceOneAsync(filter, taskItem);
        return taskItem;
    }

    public async Task DeleteAsync(string id)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.Id, id);
        var update = Builders<TaskItem>.Update
            .Set(t => t.IsDeleted, true)
            .Set(t => t.DeletedAt, DateTime.UtcNow);
        await _collection.UpdateOneAsync(filter, update);
    }

    public async Task<List<TaskItem>> GetByCollaboratorNameAsync(string collaboratorName, string? status, DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToName, collaboratorName);

        if (!string.IsNullOrEmpty(status))
            filter &= Builders<TaskItem>.Filter.Eq(t => t.Status, status);

        if (from.HasValue)
            filter &= Builders<TaskItem>.Filter.Gte(t => t.CreatedAt, from.Value);

        if (to.HasValue)
            filter &= Builders<TaskItem>.Filter.Lte(t => t.CreatedAt, to.Value);

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetAllForDashboardAsync(DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);

        if (from.HasValue)
            filter &= Builders<TaskItem>.Filter.Gte(t => t.CreatedAt, from.Value);

        if (to.HasValue)
            filter &= Builders<TaskItem>.Filter.Lte(t => t.CreatedAt, to.Value);

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetForDashboardByLeaderAsync(string leaderEmail, DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, leaderEmail);

        if (from.HasValue)
            filter &= Builders<TaskItem>.Filter.Gte(t => t.CreatedAt, from.Value);

        if (to.HasValue)
            filter &= Builders<TaskItem>.Filter.Lte(t => t.CreatedAt, to.Value);

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetForDashboardByAssigneeAsync(string assigneeEmail, DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, assigneeEmail);

        if (from.HasValue)
            filter &= Builders<TaskItem>.Filter.Gte(t => t.CreatedAt, from.Value);

        if (to.HasValue)
            filter &= Builders<TaskItem>.Filter.Lte(t => t.CreatedAt, to.Value);

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync();
    }
}
