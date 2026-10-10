namespace ShowChwanCheckIn.Models;

public class Event
{
    public string EventId { get; set; } = string.Empty;
    public string EventName { get; set; } = string.Empty;
    public DateTime EventDate { get; set; }
    public string Location { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string? OwnerUsername { get; set; } // 所屬會員帳號 / 建立者 (管理者為 null 或 "admin")
}

public class Guest
{
    public string GuestId { get; set; } = string.Empty;
    public string EventId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Organization { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    /// <summary>
    /// 職級權重：數字愈小排序愈高 (1=院長/局長/特級貴賓, 2=副院長/民代/督導, 3=科部主任/專家/學者/講師, 4=一般貴賓/同仁)
    /// </summary>
    public int RankWeight { get; set; } = 3;
    public string TableNo { get; set; } = string.Empty;
    public bool IsCheckedIn { get; set; } = false;
    public DateTime? CheckedInAt { get; set; }
    public string? CheckedInBy { get; set; }
    public string QrCodeHash { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class User
{
    public string UserId { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Role { get; set; } = "Member"; // "Admin" or "Member"
    public string DisplayName { get; set; } = string.Empty;
    public string Organization { get; set; } = string.Empty;
    /// <summary>
    /// 方案類型: "SingleEvent" (單場活動), "AnnualOrg" (機構年度), "Unlimited" (管理員)
    /// </summary>
    public string PlanType { get; set; } = "SingleEvent";
    public DateTime? ExpireAt { get; set; } // 會員有效期限
    public int MaxGuestsPerEvent { get; set; } = 500; // 單場活動 500 人 / 機構年度 1500 人
    public int MaxEvents { get; set; } = 1; // 單場活動 1 場 / 機構年度 -1 (無限制)
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string? Notes { get; set; }
}

public record UserSession(
    string UserId,
    string Username,
    string Role,
    string DisplayName,
    string Organization,
    string PlanType,
    DateTime? ExpireAt,
    int MaxGuestsPerEvent,
    int MaxEvents,
    DateTime LoggedInAt
);

public class MemberDto
{
    public string UserId { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string Role { get; set; } = "Member";
    public string DisplayName { get; set; } = string.Empty;
    public string Organization { get; set; } = string.Empty;
    public string PlanType { get; set; } = "SingleEvent";
    public DateTime? ExpireAt { get; set; }
    public int MaxGuestsPerEvent { get; set; } = 500;
    public int MaxEvents { get; set; } = 1;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public string? Notes { get; set; }
    public int EventCount { get; set; } = 0;
    public bool IsExpired => ExpireAt.HasValue && ExpireAt.Value < DateTime.UtcNow;
    public int RemainingDays => ExpireAt.HasValue ? (int)Math.Max(0, (ExpireAt.Value - DateTime.UtcNow).TotalDays) : 9999;
}

public class CreateMemberRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Organization { get; set; } = string.Empty;
    public string PlanType { get; set; } = "SingleEvent"; // "SingleEvent" or "AnnualOrg"
    public DateTime? ExpireAt { get; set; }
    public int? ExpireDays { get; set; }
    public int? MaxGuestsPerEvent { get; set; }
    public string? Notes { get; set; }
}

public class UpdateMemberRequest
{
    public string DisplayName { get; set; } = string.Empty;
    public string Organization { get; set; } = string.Empty;
    public string PlanType { get; set; } = "SingleEvent";
    public DateTime? ExpireAt { get; set; }
    public int? MaxGuestsPerEvent { get; set; }
    public bool IsActive { get; set; } = true;
    public string? Password { get; set; }
    public string? Notes { get; set; }
}

public class ResetMemberPasswordRequest
{
    public string NewPassword { get; set; } = string.Empty;
}

public class CloneEventRequest
{
    public string SourceEventId { get; set; } = string.Empty;
    public string NewEventName { get; set; } = string.Empty;
    public DateTime NewEventDate { get; set; } = DateTime.UtcNow;
    public string? Location { get; set; }
    public string? Description { get; set; }
    public bool CopyGuests { get; set; } = false;
    public string? OwnerUsername { get; set; }
}

public class CheckInToggleRequest
{
    public bool? IsCheckedIn { get; set; }
    public string? StaffName { get; set; }
}

public class ToggleCheckInDirectRequest
{
    public string EventId { get; set; } = string.Empty;
    public string GuestId { get; set; } = string.Empty;
    public bool? IsCheckedIn { get; set; }
    public string? StaffName { get; set; }
}

public class DeleteEventRequest
{
    public string EventId { get; set; } = string.Empty;
    public string? Password { get; set; }
}

public class ToggleEventActiveRequest
{
    public string EventId { get; set; } = string.Empty;
    public bool? IsActive { get; set; }
    public string? Password { get; set; }
}

public class CreateEventRequest
{
    public string? EventId { get; set; }
    public string EventName { get; set; } = string.Empty;
    public DateTime EventDate { get; set; } = DateTime.UtcNow;
    public string Location { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public string? Password { get; set; }
}

public class DeleteGuestRequest
{
    public string EventId { get; set; } = string.Empty;
    public string GuestId { get; set; } = string.Empty;
}

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string Role { get; set; } = "Member"; // "Admin" or "Member"
}

public class LoginResponse
{
    public bool Success { get; set; }
    public string Token { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Organization { get; set; } = string.Empty;
    public string PlanType { get; set; } = string.Empty;
    public DateTime? ExpireAt { get; set; }
    public int MaxGuestsPerEvent { get; set; } = 500;
    public int MaxEvents { get; set; } = 1;
    public bool IsExpired { get; set; } = false;
    public int RemainingDays { get; set; } = 0;
    public string? Message { get; set; }
}

public class AiParseRequest
{
    public string RawText { get; set; } = string.Empty;
    public string EventId { get; set; } = string.Empty;
}

public class AiQueryRequest
{
    public string Query { get; set; } = string.Empty;
    public string EventId { get; set; } = string.Empty;
}

public class EventSummaryStats
{
    public int TotalGuests { get; set; }
    public int CheckedInCount { get; set; }
    public int PendingCount { get; set; }
    public double AttendanceRate { get; set; }
    public int VipTotal { get; set; }
    public int VipCheckedIn { get; set; }
    public double VipAttendanceRate { get; set; }
    public int MaxGuestsAllowed { get; set; } = 500;
    public bool IsFull => TotalGuests >= MaxGuestsAllowed;
}

public class SelfCheckInRequest
{
    public string Token { get; set; } = string.Empty;
    public long Ts { get; set; } = 0;
    public string Identifier { get; set; } = string.Empty;
    public string? GuestName { get; set; }
}
