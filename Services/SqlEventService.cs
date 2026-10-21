using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using ShowChwanCheckIn.Common;
using ShowChwanCheckIn.Data;
using ShowChwanCheckIn.Models;

namespace ShowChwanCheckIn.Services;

public class SqlEventService : IEventService
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    public SqlEventService(IDbContextFactory<AppDbContext> dbFactory)
    {
        _dbFactory = dbFactory;
    }

    // --- Events ---

    public async Task<List<Event>> GetEventsAsync(string? ownerUsername = null, string role = "Admin")
    {
        try
        {
            await using var db = await _dbFactory.CreateDbContextAsync();
            var query = db.Events.AsQueryable();

            if (role == "Member" && !string.IsNullOrWhiteSpace(ownerUsername))
            {
                query = query.Where(e => e.OwnerUsername == ownerUsername || string.IsNullOrEmpty(e.OwnerUsername));
            }

            return await query
                .OrderByDescending(e => e.IsActive)
                .ThenByDescending(e => e.EventDate)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[SqlEventService] GetEventsAsync exception: {ex.Message}\n{ex.StackTrace}");
            throw;
        }
    }

    public async Task<Event?> GetEventByIdAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.Events.FirstOrDefaultAsync(e => e.EventId == eventId);
    }

    public async Task<Event> CreateEventAsync(Event newEvent)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        if (string.IsNullOrWhiteSpace(newEvent.EventId))
        {
            newEvent.EventId = $"event_{TaiwanTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid().ToString("N")[..6]}";
        }
        newEvent.CreatedAt = DateTime.UtcNow;
        db.Events.Add(newEvent);
        await db.SaveChangesAsync();
        return newEvent;
    }

    public async Task<bool> UpdateEventAsync(Event updatedEvent)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var existing = await db.Events.FirstOrDefaultAsync(e => e.EventId == updatedEvent.EventId);
        if (existing == null) return false;

        existing.EventName = updatedEvent.EventName;
        existing.EventDate = updatedEvent.EventDate;
        existing.Location = updatedEvent.Location;
        existing.Description = updatedEvent.Description;
        existing.IsActive = updatedEvent.IsActive;
        if (updatedEvent.RankRules != null)
        {
            existing.RankRules = updatedEvent.RankRules;
        }

        await db.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ArchiveEventAsync(string eventId, bool? targetStatus = null)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var existing = await db.Events.FirstOrDefaultAsync(e => e.EventId == eventId);
        if (existing == null) return false;

        existing.IsActive = targetStatus.HasValue ? targetStatus.Value : !existing.IsActive;
        await db.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteEventAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var ev = await db.Events.FirstOrDefaultAsync(e => e.EventId == eventId);
        if (ev != null)
        {
            db.Events.Remove(ev);
        }

        var guests = await db.Guests.Where(g => g.EventId == eventId).ToListAsync();
        if (guests.Count > 0)
        {
            db.Guests.RemoveRange(guests);
        }

        await db.SaveChangesAsync();
        return true;
    }

    public async Task<Event> CloneEventAsync(string sourceEventId, string newEventName, DateTime newEventDate, string? location, string? description, bool copyGuests, string? ownerUsername)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var sourceEv = await db.Events.FirstOrDefaultAsync(e => e.EventId == sourceEventId);

        var newId = $"event_{TaiwanTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid().ToString("N")[..6]}";
        var newEvent = new Event
        {
            EventId = newId,
            EventName = string.IsNullOrWhiteSpace(newEventName) ? $"[複製] {sourceEv?.EventName ?? "新活動"}" : newEventName,
            EventDate = newEventDate != default ? newEventDate : DateTime.UtcNow,
            Location = location ?? sourceEv?.Location ?? "大會國際會議廳",
            Description = description ?? sourceEv?.Description ?? string.Empty,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            OwnerUsername = ownerUsername,
            RankRules = sourceEv?.RankRules
        };

        db.Events.Add(newEvent);

        if (copyGuests)
        {
            var sourceGuests = await db.Guests.Where(g => g.EventId == sourceEventId).ToListAsync();
            var clonedGuests = sourceGuests.Select(g => new Guest
            {
                GuestId = g.GuestId,
                EventId = newId,
                Name = g.Name,
                Organization = g.Organization,
                Title = g.Title,
                RankWeight = g.RankWeight,
                TableNo = g.TableNo,
                IsCheckedIn = false,
                CheckedInAt = null,
                CheckedInBy = null,
                QrCodeHash = $"SC-{newId.Replace("event_", "")}-{g.GuestId}",
                Phone = g.Phone,
                Notes = g.Notes,
                CreatedAt = DateTime.UtcNow
            }).ToList();

            if (clonedGuests.Count > 0)
            {
                db.Guests.AddRange(clonedGuests);
            }
        }

        await db.SaveChangesAsync();
        return newEvent;
    }

    // --- Guests ---

    public async Task<List<Guest>> GetGuestsAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.Guests
            .Where(g => g.EventId == eventId)
            .OrderBy(g => g.RankWeight)
            .ThenBy(g => g.TableNo)
            .ThenBy(g => g.GuestId)
            .ToListAsync();
    }

    public async Task<Guest?> GetGuestByIdAsync(string eventId, string guestId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.Guests.FirstOrDefaultAsync(g => g.EventId == eventId && g.GuestId == guestId);
    }

    public async Task<Guest?> GetGuestByQrCodeAsync(string qrCodeOrId)
    {
        if (string.IsNullOrWhiteSpace(qrCodeOrId)) return null;
        var clean = qrCodeOrId.Trim();
        var stripped = clean.TrimStart('0');
        if (string.IsNullOrEmpty(stripped)) stripped = "0";

        await using var db = await _dbFactory.CreateDbContextAsync();
        var guest = await db.Guests.FirstOrDefaultAsync(g => 
            g.QrCodeHash == clean || 
            g.GuestId == clean || 
            g.GuestId == stripped || 
            g.Phone == clean);

        if (guest == null && stripped != clean)
        {
            var candidates = await db.Guests.Where(g => g.GuestId.EndsWith(stripped)).ToListAsync();
            guest = candidates.FirstOrDefault(g => g.GuestId.TrimStart('0') == stripped);
        }

        return guest;
    }

    public async Task<Guest> AddGuestAsync(Guest guest)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        if (string.IsNullOrWhiteSpace(guest.GuestId))
        {
            var count = await db.Guests.CountAsync(g => g.EventId == guest.EventId);
            guest.GuestId = $"G-{(count + 1):D3}";
        }
        if (string.IsNullOrWhiteSpace(guest.QrCodeHash))
        {
            guest.QrCodeHash = $"SC-{guest.EventId.Replace("event_", "")}-{guest.GuestId}";
        }
        guest.CreatedAt = DateTime.UtcNow;
        if (guest.IsCheckedIn)
        {
            guest.CheckedInAt ??= DateTime.UtcNow;
            if (string.IsNullOrWhiteSpace(guest.CheckedInBy))
            {
                guest.CheckedInBy = "現場新增報到";
            }
        }
        db.Guests.Add(guest);
        await db.SaveChangesAsync();
        return guest;
    }

    public async Task<List<Guest>> BatchAddGuestsAsync(string eventId, List<Guest> guests)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var existingList = await db.Guests.Where(g => g.EventId == eventId).ToListAsync();
        var existingMap = existingList.ToDictionary(g => g.GuestId, StringComparer.OrdinalIgnoreCase);

        var seenIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        int autoIndex = existingList.Count + 1;

        var resultList = new List<Guest>();

        foreach (var guest in guests)
        {
            guest.EventId = eventId;

            var id = guest.GuestId?.Trim();
            if (string.IsNullOrWhiteSpace(id) || seenIds.Contains(id))
            {
                while (existingMap.ContainsKey($"G-{autoIndex:D3}") || seenIds.Contains($"G-{autoIndex:D3}"))
                {
                    autoIndex++;
                }
                id = $"G-{autoIndex:D3}";
                autoIndex++;
            }

            guest.GuestId = id;
            seenIds.Add(id);

            if (string.IsNullOrWhiteSpace(guest.QrCodeHash))
            {
                guest.QrCodeHash = $"SC-{eventId.Replace("event_", "")}-{guest.GuestId}";
            }
            guest.CreatedAt = DateTime.UtcNow;

            if (existingMap.TryGetValue(guest.GuestId, out var existing))
            {
                existing.Name = guest.Name;
                existing.Organization = guest.Organization;
                existing.Title = guest.Title;
                existing.RankWeight = guest.RankWeight;
                existing.TableNo = guest.TableNo;
                existing.Phone = guest.Phone;
                existing.Notes = guest.Notes;
                resultList.Add(existing);
            }
            else
            {
                db.Guests.Add(guest);
                existingMap[guest.GuestId] = guest;
                resultList.Add(guest);
            }
        }

        await db.SaveChangesAsync();
        return resultList;
    }

    public async Task<bool> UpdateGuestAsync(Guest guest)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var existing = await db.Guests.FirstOrDefaultAsync(g => g.EventId == guest.EventId && g.GuestId == guest.GuestId);
        if (existing == null) return false;

        existing.Name = guest.Name;
        existing.Organization = guest.Organization;
        existing.Title = guest.Title;
        existing.RankWeight = guest.RankWeight;
        existing.TableNo = guest.TableNo;
        existing.Phone = guest.Phone;
        existing.Notes = guest.Notes;

        await db.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteGuestAsync(string eventId, string guestId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var existing = await db.Guests.FirstOrDefaultAsync(g => g.EventId == eventId && g.GuestId == guestId);
        if (existing != null)
        {
            db.Guests.Remove(existing);
            await db.SaveChangesAsync();
        }
        return true;
    }

    public async Task<bool> ClearAllGuestsAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var guests = await db.Guests.Where(g => g.EventId == eventId).ToListAsync();
        if (guests.Count > 0)
        {
            db.Guests.RemoveRange(guests);
            await db.SaveChangesAsync();
        }
        return true;
    }

    public async Task<Guest?> ToggleCheckInAsync(string eventId, string guestId, bool? targetStatus, string staffName)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var guest = await db.Guests.FirstOrDefaultAsync(g => g.EventId == eventId && g.GuestId == guestId);
        if (guest == null) return null;

        bool newStatus = targetStatus ?? !guest.IsCheckedIn;
        guest.IsCheckedIn = newStatus;
        if (newStatus)
        {
            guest.CheckedInAt = DateTime.UtcNow;
            guest.CheckedInBy = staffName;
        }
        else
        {
            guest.CheckedInAt = null;
            guest.CheckedInBy = null;
        }

        await db.SaveChangesAsync();
        return guest;
    }

    // --- Users / Members ---

    public async Task<List<MemberDto>> GetMembersAsync()
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var users = await db.Users
            .Where(u => u.Role != "Admin")
            .OrderByDescending(u => u.CreatedAt)
            .ToListAsync();

        var events = await db.Events
            .Where(e => !string.IsNullOrEmpty(e.OwnerUsername))
            .Select(e => e.OwnerUsername!)
            .ToListAsync();

        var eventCounts = events
            .GroupBy(u => u, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

        return users.Select(u => new MemberDto
        {
            UserId = u.UserId,
            Username = u.Username,
            Role = u.Role,
            DisplayName = u.DisplayName,
            Organization = u.Organization,
            PlanType = u.PlanType,
            ExpireAt = u.ExpireAt,
            MaxGuestsPerEvent = u.MaxGuestsPerEvent,
            MaxEvents = u.MaxEvents,
            IsActive = u.IsActive,
            CreatedAt = u.CreatedAt,
            Notes = u.Notes,
            EventCount = eventCounts.TryGetValue(u.Username, out var count) ? count : 0
        }).ToList();
    }

    public async Task<User?> GetUserByIdAsync(string userId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
    }

    public async Task<User?> GetUserByUsernameAsync(string username)
    {
        if (string.IsNullOrWhiteSpace(username)) return null;
        var clean = username.Trim();
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.Users.FirstOrDefaultAsync(u => u.Username == clean);
    }

    public async Task<User> CreateUserAsync(User user)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        if (string.IsNullOrWhiteSpace(user.UserId))
        {
            user.UserId = "user_" + Guid.NewGuid().ToString("N")[..12];
        }
        user.CreatedAt = DateTime.UtcNow;
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user;
    }

    public async Task<bool> UpdateUserAsync(User user)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var existing = await db.Users.FirstOrDefaultAsync(u => u.UserId == user.UserId);
        if (existing == null) return false;

        existing.DisplayName = user.DisplayName;
        existing.Organization = user.Organization;
        existing.PlanType = user.PlanType;
        existing.ExpireAt = user.ExpireAt;
        existing.MaxGuestsPerEvent = user.MaxGuestsPerEvent;
        existing.MaxEvents = user.MaxEvents;
        existing.IsActive = user.IsActive;
        existing.Notes = user.Notes;
        if (!string.IsNullOrWhiteSpace(user.PasswordHash))
        {
            existing.PasswordHash = user.PasswordHash;
        }

        await db.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteUserAsync(string userId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var user = await db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user != null)
        {
            if (user.Role == "Admin") return false;
            db.Users.Remove(user);
            await db.SaveChangesAsync();
            return true;
        }
        return false;
    }

    public async Task<bool> ToggleUserStatusAsync(string userId, bool? targetStatus = null)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var user = await db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return false;

        user.IsActive = targetStatus ?? !user.IsActive;
        await db.SaveChangesAsync();
        return true;
    }

    public async Task<bool> ResetUserPasswordAsync(string userId, string newPassword)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var user = await db.Users.FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return false;

        user.PasswordHash = InMemoryEventService.HashPassword(newPassword);
        await db.SaveChangesAsync();
        return true;
    }

    public async Task<int> GetUserEventCountAsync(string username)
    {
        if (string.IsNullOrWhiteSpace(username)) return 0;
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.Events.CountAsync(e => e.OwnerUsername == username);
    }

    // --- Stats, Export & AI ---

    public async Task<EventSummaryStats> GetEventStatsAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var guests = await db.Guests.Where(g => g.EventId == eventId).ToListAsync();

        var total = guests.Count;
        var checkedCount = guests.Count(g => g.IsCheckedIn);
        var pendingCount = total - checkedCount;
        var attRate = total > 0 ? Math.Round((double)checkedCount / total * 100, 1) : 0;

        var vips = guests.Where(g => g.RankWeight <= 2).ToList();
        var vipTotal = vips.Count;
        var vipChecked = vips.Count(g => g.IsCheckedIn);
        var vipRate = vipTotal > 0 ? Math.Round((double)vipChecked / vipTotal * 100, 1) : 0;

        return new EventSummaryStats
        {
            TotalGuests = total,
            CheckedInCount = checkedCount,
            PendingCount = pendingCount,
            AttendanceRate = attRate,
            VipTotal = vipTotal,
            VipCheckedIn = vipChecked,
            VipAttendanceRate = vipRate
        };
    }

    public async Task<string> ExportCsvAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var guests = await db.Guests
            .Where(g => g.EventId == eventId)
            .OrderBy(g => g.RankWeight)
            .ThenBy(g => g.TableNo)
            .ThenBy(g => g.GuestId)
            .ToListAsync();

        var ev = await db.Events.FirstOrDefaultAsync(e => e.EventId == eventId);
        var eventName = ev?.EventName ?? eventId;

        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"# 活動報到名冊 - {eventName}");
        sb.AppendLine($"# 匯出時間：{TaiwanTime.Now:yyyy/MM/dd HH:mm:ss}");
        sb.AppendLine("貴賓編號,姓名,服務單位,職稱,職級權重,桌次/座位,報到狀態,報到時間,經手人員,專屬QR碼,電話,備註");

        foreach (var g in guests)
        {
            var checkInStatus = g.IsCheckedIn ? "已報到" : "未報到";
            var checkInTime = g.CheckedInAt.HasValue ? g.CheckedInAt.ToTaiwanTimeString("yyyy/MM/dd HH:mm:ss") : "";
            var rankDesc = g.RankWeight switch
            {
                1 => "1-特級長官/院長",
                2 => "2-副院長/民代",
                3 => "3-科部主任/專家",
                _ => "4-一般貴賓"
            };

            sb.AppendLine($"\"{g.GuestId}\",\"{g.Name}\",\"{g.Organization}\",\"{g.Title}\",\"{rankDesc}\",\"{g.TableNo}\",\"{checkInStatus}\",\"{checkInTime}\",\"{g.CheckedInBy ?? ""}\",\"{g.QrCodeHash}\",\"{g.Phone ?? ""}\",\"{g.Notes ?? ""}\"");
        }

        return sb.ToString();
    }

    public async Task<List<Guest>> ParseRawGuestTextAsync(string eventId, string rawText)
    {
        var result = new List<Guest>();
        if (string.IsNullOrWhiteSpace(rawText)) return result;

        var lines = rawText.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
        int autoId = 1;

        foreach (var line in lines)
        {
            var trimmed = line.Trim();
            if (string.IsNullOrWhiteSpace(trimmed) || trimmed.StartsWith("#") || trimmed.StartsWith("//")) continue;

            var tokens = trimmed.Split(new[] { ',', '\t', '，', '、', '|' }, StringSplitOptions.TrimEntries);
            if (tokens.Length == 0) continue;

            string name = tokens[0];
            string org = tokens.Length > 1 ? tokens[1] : "受邀貴賓單位";
            string title = tokens.Length > 2 ? tokens[2] : "貴賓";
            string table = tokens.Length > 3 ? tokens[3] : "未排桌";

            int rank = 3;
            if (title.Contains("照專") && !title.Contains("督導"))
            {
                rank = 4;
            }
            else if (title.Contains("總裁") || title.Contains("院長") || title.Contains("部長") || title.Contains("局長") || title.Contains("董事長") || title.Contains("次長") || title.Contains("署長"))
            {
                rank = 1;
            }
            else if (title.Contains("副院長") || title.Contains("議員") || title.Contains("立委") || title.Contains("代表") || title.Contains("組長") || title.Contains("督導"))
            {
                rank = 2;
            }
            else if (title.Contains("主任") || title.Contains("教授") || title.Contains("醫師") || title.Contains("處長") || title.Contains("理事長") || title.Contains("學者") || title.Contains("專家") || title.Contains("講師"))
            {
                rank = 3;
            }
            else
            {
                rank = 4;
            }

            result.Add(new Guest
            {
                GuestId = $"IMP-{TaiwanTime.Now:HHmmss}-{autoId++:D2}",
                EventId = eventId,
                Name = name,
                Organization = org,
                Title = title,
                RankWeight = rank,
                TableNo = table,
                IsCheckedIn = false,
                QrCodeHash = $"SC-IMP-{Guid.NewGuid().ToString("N")[..8].ToUpper()}",
                CreatedAt = DateTime.UtcNow
            });
        }

        return await Task.FromResult(result);
    }

    public async Task<string> ProcessAiQueryAsync(string eventId, string query)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var guests = await db.Guests.Where(g => g.EventId == eventId).ToListAsync();
        var stats = await GetEventStatsAsync(eventId);

        var lower = query.ToLower();
        if (lower.Contains("vip") || lower.Contains("長官") || lower.Contains("貴賓") || lower.Contains("主桌"))
        {
            var vips = guests.Where(g => g.RankWeight <= 2).OrderBy(g => g.RankWeight).ToList();
            var checkedVips = vips.Where(g => g.IsCheckedIn).ToList();
            var pendingVips = vips.Where(g => !g.IsCheckedIn).ToList();

            var sb = new System.Text.StringBuilder();
            sb.AppendLine($"👑 **【VIP 與長官即時到場分析】**");
            sb.AppendLine($"- 總計應到 VIP：**{vips.Count}** 位");
            sb.AppendLine($"- 已完成報到：**{checkedVips.Count}** 位 (到場率 **{stats.VipAttendanceRate}%**)");
            sb.AppendLine($"- 尚待報到：**{pendingVips.Count}** 位\n");

            if (checkedVips.Count > 0)
            {
                sb.AppendLine($"🟢 **已到場貴賓：**");
                foreach (var g in checkedVips)
                {
                    sb.AppendLine($"- ✅ 【{g.Organization}】{g.Title} **{g.Name}**（桌次：{g.TableNo} / 報到時間：{g.CheckedInAt.ToTaiwanTimeString("HH:mm")}）");
                }
                sb.AppendLine();
            }

            if (pendingVips.Count > 0)
            {
                sb.AppendLine($"⏳ **尚未完成報到貴賓：**");
                foreach (var g in pendingVips)
                {
                    sb.AppendLine($"- ⚪ 【{g.Organization}】{g.Title} **{g.Name}**（安排桌次：{g.TableNo} / 備註：{g.Notes ?? "無"}）");
                }
            }

            return sb.ToString();
        }
        else if (lower.Contains("致詞") || lower.Contains("提詞") || lower.Contains("主持人") || lower.Contains("開場"))
        {
            var checkedInVips = guests.Where(g => g.IsCheckedIn && g.RankWeight <= 2).OrderBy(g => g.RankWeight).ToList();
            var sb = new System.Text.StringBuilder();
            sb.AppendLine($"🎤 **【主持人開場致詞提詞單（已到場長官清單）】**\n");
            sb.AppendLine("各位貴賓、長官、業界先進，大家早安！非常榮幸蒞臨本次活動盛會。在此特別向大家介紹今天親臨現場指導的尊榮長官與貴賓：\n");

            int idx = 1;
            foreach (var g in checkedInVips)
            {
                sb.AppendLine($"{idx++}. 歡迎 **{g.Organization} {g.Title} {g.Name}** 光臨指導！");
            }

            sb.AppendLine($"\n（目前現場出席率已達 **{stats.AttendanceRate}%**，氣氛熱烈，建議可準時宣布活動開始！）");
            return sb.ToString();
        }
        else
        {
            return $"📊 **【全場即時進度統計】**\n- 總應到人數：**{stats.TotalGuests}** 人\n- 已報到人數：**{stats.CheckedInCount}** 人\n- 目前出席率：**{stats.AttendanceRate}%**\n- VIP長官到場率：**{stats.VipAttendanceRate}%** ({stats.VipCheckedIn}/{stats.VipTotal})\n\n💡 *提示：您可以詢問「目前 VIP 到場情況」、「主桌還有誰沒到？」或「產出主持人開場致詞稿」。*";
        }
    }

    public async Task<object> GetStorageDiagnosticsAsync()
    {
        try
        {
            await using var db = await _dbFactory.CreateDbContextAsync();
            var canConnect = await db.Database.CanConnectAsync();
            var eventsCount = canConnect ? await db.Events.CountAsync() : 0;
            var guestsCount = canConnect ? await db.Guests.CountAsync() : 0;
            var usersCount = canConnect ? await db.Users.CountAsync() : 0;

            return new
            {
                serviceMode = "SqlEventService (Live SQL Server)",
                databaseType = "Microsoft SQL Server",
                serverTime = TaiwanTime.Now.ToString("yyyy/MM/dd HH:mm:ss"),
                machineName = Environment.MachineName,
                canConnect,
                provider = db.Database.ProviderName,
                tableEvents = "checkInEvents",
                tableGuests = "checkInGuests",
                tableUsers = "checkInUsers",
                eventsCount,
                guestsCount,
                usersCount
            };
        }
        catch (Exception ex)
        {
            return new
            {
                serviceMode = "SqlEventService (Error Connecting)",
                databaseType = "Microsoft SQL Server",
                serverTime = TaiwanTime.Now.ToString("yyyy/MM/dd HH:mm:ss"),
                machineName = Environment.MachineName,
                canConnect = false,
                errorMessage = ex.Message,
                errorDetails = ex.ToString()
            };
        }
    }

    // =========================================================================
    // LOTTERY ADDON MODULE (現場抽獎附加功能實作 - SQL)
    // =========================================================================

    public async Task<bool> HasLotteryAccessAsync(string? username, string eventId)
    {
        if (string.Equals(username, "admin", StringComparison.OrdinalIgnoreCase)) return true;

        await using var db = await _dbFactory.CreateDbContextAsync();
        var ev = await db.Events.FirstOrDefaultAsync(e => e.EventId == eventId);
        if (ev != null && ev.HasLotteryAddon) return true;

        if (!string.IsNullOrWhiteSpace(username))
        {
            var user = await db.Users.FirstOrDefaultAsync(u => u.Username == username);
            if (user != null && (user.Role == "Admin" || user.HasLotteryAddon)) return true;
        }

        return false;
    }

    public async Task<bool> AuthorizeLotteryAddonAsync(string username, string? eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        if (!string.IsNullOrWhiteSpace(username))
        {
            var user = await db.Users.FirstOrDefaultAsync(u => u.Username == username);
            if (user != null)
            {
                user.HasLotteryAddon = true;
                user.LotteryAuthorizedAt = DateTime.UtcNow;
            }
        }

        if (!string.IsNullOrWhiteSpace(eventId))
        {
            var ev = await db.Events.FirstOrDefaultAsync(e => e.EventId == eventId);
            if (ev != null)
            {
                ev.HasLotteryAddon = true;
            }
        }

        await db.SaveChangesAsync();
        return true;
    }

    public async Task<List<Guest>> GetEligibleLotteryGuestsAsync(string eventId, bool excludePreviousWinners = true)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        // 嚴格只針對現場已完成報到名單
        var query = db.Guests.Where(g => g.EventId == eventId && g.IsCheckedIn);

        if (excludePreviousWinners)
        {
            var winnerGuestIds = await db.LotteryWinners
                .Where(w => w.EventId == eventId && !w.IsRevoked)
                .Select(w => w.GuestId)
                .ToListAsync();

            if (winnerGuestIds.Count > 0)
            {
                query = query.Where(g => !winnerGuestIds.Contains(g.GuestId));
            }
        }

        return await query.ToListAsync();
    }

    public async Task<List<LotteryPrize>> GetLotteryPrizesAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.LotteryPrizes
            .Where(p => p.EventId == eventId)
            .OrderBy(p => p.DisplayOrder)
            .ThenBy(p => p.CreatedAt)
            .ToListAsync();
    }

    public async Task<LotteryPrize> CreateLotteryPrizeAsync(LotteryPrize prize)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        if (string.IsNullOrWhiteSpace(prize.PrizeId))
        {
            prize.PrizeId = $"prize_{TaiwanTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid().ToString("N")[..6]}";
        }
        prize.CreatedAt = DateTime.UtcNow;
        db.LotteryPrizes.Add(prize);
        await db.SaveChangesAsync();
        return prize;
    }

    public async Task<bool> DeleteLotteryPrizeAsync(string eventId, string prizeId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var item = await db.LotteryPrizes.FirstOrDefaultAsync(p => p.EventId == eventId && p.PrizeId == prizeId);
        if (item != null)
        {
            db.LotteryPrizes.Remove(item);
            await db.SaveChangesAsync();
            return true;
        }
        return false;
    }

    public async Task<List<LotteryWinner>> GetLotteryWinnersAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        return await db.LotteryWinners
            .Where(w => w.EventId == eventId)
            .OrderByDescending(w => w.WonAt)
            .ToListAsync();
    }

    public async Task<List<LotteryWinner>> DrawLotteryAsync(string eventId, string prizeName, int quantity, bool excludePreviousWinners = true, string? prizeId = null)
    {
        var eligibleGuests = await GetEligibleLotteryGuestsAsync(eventId, excludePreviousWinners);
        if (eligibleGuests.Count == 0 || quantity <= 0)
        {
            return new List<LotteryWinner>();
        }

        var shuffled = eligibleGuests.OrderBy(_ => Random.Shared.Next()).ToList();
        var selectedCount = Math.Min(quantity, shuffled.Count);
        var chosenGuests = shuffled.Take(selectedCount).ToList();

        var newWinners = new List<LotteryWinner>();
        await using var db = await _dbFactory.CreateDbContextAsync();

        foreach (var guest in chosenGuests)
        {
            var winner = new LotteryWinner
            {
                WinnerId = $"win_{TaiwanTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid().ToString("N")[..6]}",
                EventId = eventId,
                PrizeId = prizeId,
                PrizeName = prizeName,
                GuestId = guest.GuestId,
                GuestName = guest.Name,
                Organization = guest.Organization,
                Title = guest.Title,
                TableNo = guest.TableNo,
                WonAt = DateTime.UtcNow,
                IsRevoked = false
            };
            db.LotteryWinners.Add(winner);
            newWinners.Add(winner);
        }

        await db.SaveChangesAsync();
        return newWinners;
    }

    public async Task<bool> RevokeLotteryWinnerAsync(string eventId, string winnerId)
    {
        if (string.IsNullOrWhiteSpace(winnerId)) return false;
        await using var db = await _dbFactory.CreateDbContextAsync();
        
        LotteryWinner? item = null;
        if (!string.IsNullOrWhiteSpace(eventId))
        {
            item = await db.LotteryWinners.FirstOrDefaultAsync(w => w.EventId == eventId && w.WinnerId == winnerId);
        }
        if (item == null)
        {
            item = await db.LotteryWinners.FirstOrDefaultAsync(w => w.WinnerId == winnerId);
        }

        if (item != null)
        {
            item.IsRevoked = true;
            await db.SaveChangesAsync();
            return true;
        }
        return false;
    }

    public async Task<bool> ClearLotteryWinnersAsync(string eventId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync();
        var items = await db.LotteryWinners.Where(w => w.EventId == eventId).ToListAsync();
        if (items.Count > 0)
        {
            db.LotteryWinners.RemoveRange(items);
            await db.SaveChangesAsync();
        }
        return true;
    }
}
