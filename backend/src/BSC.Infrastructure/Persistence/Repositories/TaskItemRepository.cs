using System.Text.RegularExpressions;
using BSC.Domain.Constants;
using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
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

    private static FilterDefinition<TaskItem> ApplyStatusFilter(FilterDefinition<TaskItem> filter, string? status)
    {
        if (!string.IsNullOrWhiteSpace(status))
        {
            filter &= Builders<TaskItem>.Filter.Eq(t => t.Status, status);
        }
        return filter;
    }

    private static FilterDefinition<TaskItem> ApplyDateFilter(FilterDefinition<TaskItem> filter, string? dateFrom, string? dateTo)
    {
        var ecuadorOffset = TimeSpan.FromHours(-5);

        if (!string.IsNullOrWhiteSpace(dateFrom) && DateTime.TryParse(dateFrom, out var from))
        {
            var fromUtc = from.Date.Add(-ecuadorOffset);
            filter &= Builders<TaskItem>.Filter.Gte(t => t.DueDate, fromUtc);
        }

        if (!string.IsNullOrWhiteSpace(dateTo) && DateTime.TryParse(dateTo, out var to))
        {
            var toUtc = to.Date.AddDays(1).Add(-ecuadorOffset);
            filter &= Builders<TaskItem>.Filter.Lt(t => t.DueDate, toUtc);
        }

        return filter;
    }

    private IFindFluent<TaskItem, TaskItem> ApplySorting(IFindFluent<TaskItem, TaskItem> query, string? sortDueDate)
    {
        if (sortDueDate == "asc")
            return query.SortBy(t => t.DueDate);
        if (sortDueDate == "desc")
            return query.SortByDescending(t => t.DueDate);
        return query.SortBy(t => t.CreatedAt);
    }

    public async Task<List<TaskItem>> GetAllAsync(int page, int pageSize, string? search = null, string? status = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, status);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        var skip = (page - 1) * pageSize;

        return await ApplySorting(_collection.Find(filter), sortDueDate)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetTotalCountAsync(string? search = null, string? status = null, string? dateFrom = null, string? dateTo = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, status);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        return (int)await _collection.CountDocumentsAsync(filter);
    }

    /// <summary>
    /// Construye el filtro de visibilidad:
    /// - alwaysVisibleStatuses: se muestran siempre.
    /// - conditionalStatuses: solo se muestran si DueDate >= ahora.
    /// </summary>
    private static FilterDefinition<TaskItem> BuildVisibilityFilter(List<string> alwaysVisibleStatuses, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null)
    {
        var alwaysFilter = Builders<TaskItem>.Filter.In(t => t.Status, alwaysVisibleStatuses);

        if (conditionalStatuses != null && conditionalStatuses.Count > 0 && visibleBeforeDeadline.HasValue)
        {
            var conditionalStatusFilter = Builders<TaskItem>.Filter.In(t => t.Status, conditionalStatuses);
            var deadlineFilter = Builders<TaskItem>.Filter.Gte(t => t.DueDate, visibleBeforeDeadline.Value);
            var conditionalFilter = Builders<TaskItem>.Filter.And(conditionalStatusFilter, deadlineFilter);
            return Builders<TaskItem>.Filter.Or(alwaysFilter, conditionalFilter);
        }

        return alwaysFilter;
    }

    public async Task<List<TaskItem>> GetByLeaderEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);

        var skip = (page - 1) * pageSize;

        return await ApplySorting(_collection.Find(filter), sortDueDate)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByLeaderEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);

        return (int)await _collection.CountDocumentsAsync(filter);
    }

    public async Task<List<TaskItem>> GetByAssignedEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);

        var skip = (page - 1) * pageSize;

        return await ApplySorting(_collection.Find(filter), sortDueDate)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByAssignedEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);

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

    public async Task BulkDeleteAsync(List<string> ids)
    {
        var filter = Builders<TaskItem>.Filter.In(t => t.Id, ids);
        var update = Builders<TaskItem>.Update
            .Set(t => t.IsDeleted, true)
            .Set(t => t.DeletedAt, DateTime.UtcNow);
        await _collection.UpdateManyAsync(filter, update);
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

    public async Task<List<TaskItem>> GetByCollaboratorWithHistoricStatusAsync(string collaboratorName, string historicStatus, DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToName, collaboratorName)
                   & Builders<TaskItem>.Filter.ElemMatch(t => t.StatusHistory,
                       Builders<StatusChange>.Filter.Eq(sc => sc.ToStatus, historicStatus));

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
