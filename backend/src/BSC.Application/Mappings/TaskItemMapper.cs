using BSC.Application.DTOs;
using BSC.Domain.Entities;

namespace BSC.Application.Mappings;

/// <summary>
/// Mapper centralizado para convertir TaskItem a TaskItemDto.
/// </summary>
public static class TaskItemMapper
{
    public static TaskItemDto ToDto(TaskItem taskItem)
    {
        return new TaskItemDto
        {
            Id = taskItem.Id,
            Title = taskItem.Title,
            Description = taskItem.Description,
            Status = taskItem.Status,
            AssignedLeaderId = taskItem.AssignedLeaderId,
            AssignedLeaderName = taskItem.AssignedLeaderName,
            AssignedLeaderEmail = taskItem.AssignedLeaderEmail,
            AssignedToId = taskItem.AssignedToId,
            AssignedToName = taskItem.AssignedToName,
            AssignedToEmail = taskItem.AssignedToEmail,
            DueDate = taskItem.DueDate,
            EstimatedTime = taskItem.EstimatedTime,
            ActualTime = taskItem.ActualTime,
            Insumos = taskItem.Insumos,
            InsumoFiles = taskItem.InsumoFiles?.Select(f => new FileAttachmentDto
            {
                Id = f.Id,
                FileName = f.FileName,
                UploadedAt = f.UploadedAt
            }).ToList() ?? new List<FileAttachmentDto>(),
            EvidenceFiles = taskItem.EvidenceFiles?.Select(f => new FileAttachmentDto
            {
                Id = f.Id,
                FileName = f.FileName,
                UploadedAt = f.UploadedAt
            }).ToList() ?? new List<FileAttachmentDto>(),
            EvidenceText = taskItem.EvidenceText,
            Observations = taskItem.Observations,
            StatusHistory = taskItem.StatusHistory?.Select(sh => new StatusChangeDto
            {
                FromStatus = sh.FromStatus,
                ToStatus = sh.ToStatus,
                ChangedById = sh.ChangedById,
                ChangedByName = sh.ChangedByName,
                ChangedByEmail = sh.ChangedByEmail,
                ChangedAt = sh.ChangedAt,
                Comment = sh.Comment
            }).ToList() ?? new List<StatusChangeDto>(),
            CreatedAt = taskItem.CreatedAt,
            CreatedBy = taskItem.CreatedBy,
            UpdatedAt = taskItem.UpdatedAt
        };
    }
}
