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

    public async Task<List<TaskItem>> GetAllAsync(int page, int pageSize)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        var skip = (page - 1) * pageSize;

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetTotalCountAsync()
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        return (int)await _collection.CountDocumentsAsync(filter);
    }

    public async Task<List<TaskItem>> GetByLeaderEmailAsync(string email, int page, int pageSize)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & Builders<TaskItem>.Filter.Ne(t => t.Status, TaskStatuses.Completa);

        var skip = (page - 1) * pageSize;

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByLeaderEmailAsync(string email)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & Builders<TaskItem>.Filter.Ne(t => t.Status, TaskStatuses.Completa);

        return (int)await _collection.CountDocumentsAsync(filter);
    }

    public async Task<List<TaskItem>> GetByAssignedEmailAsync(string email, List<string> statuses, int page, int pageSize)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & Builders<TaskItem>.Filter.In(t => t.Status, statuses);

        var skip = (page - 1) * pageSize;

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByAssignedEmailAsync(string email, List<string> statuses)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & Builders<TaskItem>.Filter.In(t => t.Status, statuses);

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
}
