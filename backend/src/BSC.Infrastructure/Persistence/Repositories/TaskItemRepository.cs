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
        if (string.IsNullOrWhiteSpace(status)) return filter;
        // Soporta CSV: "Asignada,Reasignada" → In(...). Un solo valor también pasa por In.
        if (status.Contains(','))
        {
            var values = status.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Distinct().ToList();
            if (values.Count > 0)
                filter &= Builders<TaskItem>.Filter.In(t => t.Status, values);
        }
        else
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

    private static List<string>? ParseCsvValues(string? csv)
    {
        if (string.IsNullOrWhiteSpace(csv)) return null;
        var values = csv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                        .Distinct()
                        .ToList();
        return values.Count == 0 ? null : values;
    }

    private static FilterDefinition<TaskItem> ApplyColumnFilters(FilterDefinition<TaskItem> filter, string? titleFilter, string? assignedToFilter, string? leaderFilter)
    {
        var titles = ParseCsvValues(titleFilter);
        if (titles != null)
        {
            filter &= Builders<TaskItem>.Filter.In(t => t.Title, titles);
        }
        var assigned = ParseCsvValues(assignedToFilter);
        if (assigned != null)
        {
            filter &= Builders<TaskItem>.Filter.In(t => t.AssignedToName, assigned);
        }
        var leaders = ParseCsvValues(leaderFilter);
        if (leaders != null)
        {
            filter &= Builders<TaskItem>.Filter.In(t => t.AssignedLeaderName, leaders);
        }
        return filter;
    }

    private IFindFluent<TaskItem, TaskItem> ApplySorting(IFindFluent<TaskItem, TaskItem> query, string? sortDueDate, string? sortBy = null, string? sortDir = null)
    {
        // Sort genérico por sortBy + sortDir tiene prioridad sobre el legado sortDueDate.
        if (!string.IsNullOrWhiteSpace(sortBy))
        {
            var asc = !string.Equals(sortDir, "desc", StringComparison.OrdinalIgnoreCase);
            return sortBy switch
            {
                "title" => asc ? query.SortBy(t => t.Title) : query.SortByDescending(t => t.Title),
                "description" => asc ? query.SortBy(t => t.Description) : query.SortByDescending(t => t.Description),
                "assignedTo" => asc ? query.SortBy(t => t.AssignedToName) : query.SortByDescending(t => t.AssignedToName),
                "leader" => asc ? query.SortBy(t => t.AssignedLeaderName) : query.SortByDescending(t => t.AssignedLeaderName),
                "status" => asc ? query.SortBy(t => t.Status) : query.SortByDescending(t => t.Status),
                "dueDate" => asc ? query.SortBy(t => t.DueDate) : query.SortByDescending(t => t.DueDate),
                "estimatedTime" => asc ? query.SortBy(t => t.EstimatedTime) : query.SortByDescending(t => t.EstimatedTime),
                "rating" => asc ? query.SortBy(t => t.Rating) : query.SortByDescending(t => t.Rating),
                "createdAt" => asc ? query.SortBy(t => t.CreatedAt) : query.SortByDescending(t => t.CreatedAt),
                _ => query.SortByDescending(t => t.CreatedAt),
            };
        }

        // Compatibilidad con el viejo sortDueDate.
        if (sortDueDate == "asc")
            return query.SortBy(t => t.DueDate);
        if (sortDueDate == "desc")
            return query.SortByDescending(t => t.DueDate);

        return query.SortByDescending(t => t.CreatedAt);
    }

    public async Task<List<TaskItem>> GetAllAsync(int page, int pageSize, string? search = null, string? status = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null, string? sortBy = null, string? sortDir = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, status);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        filter = ApplyColumnFilters(filter, titleFilter, assignedToFilter, leaderFilter);
        var skip = (page - 1) * pageSize;

        return await ApplySorting(_collection.Find(filter), sortDueDate, sortBy, sortDir)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetTotalCountAsync(string? search = null, string? status = null, string? dateFrom = null, string? dateTo = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, status);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        filter = ApplyColumnFilters(filter, titleFilter, assignedToFilter, leaderFilter);
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

    public async Task<List<TaskItem>> GetByLeaderEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null, string? sortBy = null, string? sortDir = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        filter = ApplyColumnFilters(filter, titleFilter, assignedToFilter, leaderFilter);

        var skip = (page - 1) * pageSize;

        return await ApplySorting(_collection.Find(filter), sortDueDate, sortBy, sortDir)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByLeaderEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        filter = ApplyColumnFilters(filter, titleFilter, assignedToFilter, leaderFilter);

        return (int)await _collection.CountDocumentsAsync(filter);
    }

    public async Task<List<TaskItem>> GetByAssignedEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null, string? sortBy = null, string? sortDir = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        filter = ApplyColumnFilters(filter, titleFilter, assignedToFilter, leaderFilter);

        var skip = (page - 1) * pageSize;

        return await ApplySorting(_collection.Find(filter), sortDueDate, sortBy, sortDir)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetCountByAssignedEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, email)
                   & BuildVisibilityFilter(statuses, conditionalStatuses, visibleBeforeDeadline);
        filter = ApplySearchFilter(filter, search);
        filter = ApplyStatusFilter(filter, statusFilter);
        filter = ApplyDateFilter(filter, dateFrom, dateTo);
        filter = ApplyColumnFilters(filter, titleFilter, assignedToFilter, leaderFilter);

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

    private static FilterDefinition<TaskItem> ApplyDashboardDateFilter(FilterDefinition<TaskItem> filter, DateTime? from, DateTime? to)
    {
        var ecuadorOffset = TimeSpan.FromHours(-5);

        if (from.HasValue)
        {
            var fromUtc = from.Value.Date.Add(-ecuadorOffset);
            filter &= Builders<TaskItem>.Filter.Gte(t => t.DueDate, fromUtc);
        }

        if (to.HasValue)
        {
            var toUtc = to.Value.Date.AddDays(1).Add(-ecuadorOffset);
            filter &= Builders<TaskItem>.Filter.Lt(t => t.DueDate, toUtc);
        }

        return filter;
    }

    public async Task<List<TaskItem>> GetAllForDashboardAsync(DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        filter = ApplyDashboardDateFilter(filter, from, to);

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetForDashboardByLeaderAsync(string leaderEmail, DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, leaderEmail);
        filter = ApplyDashboardDateFilter(filter, from, to);

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<TaskItem>> GetForDashboardByAssigneeAsync(string assigneeEmail, DateTime? from, DateTime? to)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false)
                   & Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, assigneeEmail);
        filter = ApplyDashboardDateFilter(filter, from, to);

        return await _collection
            .Find(filter)
            .SortByDescending(t => t.CreatedAt)
            .ToListAsync();
    }

    public async Task<List<string>> GetDistinctFieldValuesAsync(string field, string scope, string? scopeEmail, List<string>? statuses)
    {
        var filter = Builders<TaskItem>.Filter.Eq(t => t.IsDeleted, false);
        if (string.Equals(scope, "leader", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(scopeEmail))
        {
            filter &= Builders<TaskItem>.Filter.Eq(t => t.AssignedLeaderEmail, scopeEmail);
        }
        else if (string.Equals(scope, "assignee", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(scopeEmail))
        {
            filter &= Builders<TaskItem>.Filter.Eq(t => t.AssignedToEmail, scopeEmail);
        }
        if (statuses != null && statuses.Count > 0)
        {
            filter &= Builders<TaskItem>.Filter.In(t => t.Status, statuses);
        }

        FieldDefinition<TaskItem, string?> mongoField = field switch
        {
            "title" => "title",
            "assignedTo" => "assignedToName",
            "leader" => "assignedLeaderName",
            "status" => "status",
            _ => "title",
        };

        var values = await _collection.Distinct(mongoField, filter).ToListAsync();
        return values
            .Where(v => !string.IsNullOrWhiteSpace(v))
            .Select(v => v!)
            .OrderBy(v => v, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}
