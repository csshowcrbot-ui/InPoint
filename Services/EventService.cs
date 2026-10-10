using System.Collections.Concurrent;
using System.Text.Json;
using System.Text.RegularExpressions;
using ShowChwanCheckIn.Models;

namespace ShowChwanCheckIn.Services;

public interface IEventService
{
    // Events
    Task<List<Event>> GetEventsAsync(string? ownerUsername = null, string role = "Admin");
    Task<Event?> GetEventByIdAsync(string eventId);
    Task<Event> CreateEventAsync(Event newEvent);
    Task<bool> UpdateEventAsync(Event updatedEvent);
    Task<bool> ArchiveEventAsync(string eventId, bool? targetStatus = null);
    Task<bool> DeleteEventAsync(string eventId);
    Task<Event> CloneEventAsync(string sourceEventId, string newEventName, DateTime newEventDate, string? location, string? description, bool copyGuests, string? ownerUsername);

    // Guests
    Task<List<Guest>> GetGuestsAsync(string eventId);
    Task<Guest?> GetGuestByIdAsync(string eventId, string guestId);
    Task<Guest?> GetGuestByQrCodeAsync(string qrCodeOrId);
    Task<Guest> AddGuestAsync(Guest guest);
    Task<List<Guest>> BatchAddGuestsAsync(string eventId, List<Guest> guests);
    Task<bool> UpdateGuestAsync(Guest guest);
    Task<bool> DeleteGuestAsync(string eventId, string guestId);
    Task<bool> ClearAllGuestsAsync(string eventId);
    Task<Guest?> ToggleCheckInAsync(string eventId, string guestId, bool? targetStatus, string staffName);

    // Members / Users
    Task<List<MemberDto>> GetMembersAsync();
    Task<User?> GetUserByIdAsync(string userId);
    Task<User?> GetUserByUsernameAsync(string username);
    Task<User> CreateUserAsync(User user);
    Task<bool> UpdateUserAsync(User user);
    Task<bool> DeleteUserAsync(string userId);
    Task<bool> ToggleUserStatusAsync(string userId, bool? targetStatus = null);
    Task<bool> ResetUserPasswordAsync(string userId, string newPassword);
    Task<int> GetUserEventCountAsync(string username);

    // Stats, Export & AI
    Task<EventSummaryStats> GetEventStatsAsync(string eventId);
    Task<string> ExportCsvAsync(string eventId);
    Task<List<Guest>> ParseRawGuestTextAsync(string eventId, string rawText);
    Task<string> ProcessAiQueryAsync(string eventId, string query);
    Task<object> GetStorageDiagnosticsAsync();
}

public class InMemoryEventService : IEventService
{
    private readonly ConcurrentDictionary<string, Event> _events = new();
    private readonly ConcurrentDictionary<string, ConcurrentDictionary<string, Guest>> _guests = new();
    private readonly ConcurrentDictionary<string, User> _users = new();
    private readonly List<string> _storageDirs = new();
    private readonly object _fileLock = new();

    public InMemoryEventService()
    {
        InitStorageDirs();

        if (!LoadDataFromDisk())
        {
            SeedInitialData();
            SaveDataToDisk();
        }
    }

    private void InitStorageDirs()
    {
        var dirs = new List<string>
        {
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "data"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "ShowChwanCheckIn", "data"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ShowChwanCheckIn", "data"),
            Path.Combine(Path.GetTempPath(), "ShowChwanCheckIn_data")
        };

        foreach (var dir in dirs)
        {
            try
            {
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                _storageDirs.Add(dir);
            }
            catch {}
        }
        if (_storageDirs.Count == 0)
        {
            _storageDirs.Add(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "data"));
        }
    }

    private void SaveDataToDisk()
    {
        lock (_fileLock)
        {
            try
            {
                var eventsList = _events.Values.ToList();
                var jsonEvents = JsonSerializer.Serialize(eventsList, new JsonSerializerOptions { WriteIndented = true });

                var allGuests = new Dictionary<string, List<Guest>>();
                foreach (var kvp in _guests)
                {
                    allGuests[kvp.Key] = kvp.Value.Values.ToList();
                }
                var jsonGuests = JsonSerializer.Serialize(allGuests, new JsonSerializerOptions { WriteIndented = true });

                var usersList = _users.Values.ToList();
                var jsonUsers = JsonSerializer.Serialize(usersList, new JsonSerializerOptions { WriteIndented = true });

                foreach (var dir in _storageDirs)
                {
                    try
                    {
                        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                        File.WriteAllText(Path.Combine(dir, "events.json"), jsonEvents);
                        File.WriteAllText(Path.Combine(dir, "guests.json"), jsonGuests);
                        File.WriteAllText(Path.Combine(dir, "users.json"), jsonUsers);
                    }
                    catch {}
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"SaveDataToDisk error: {ex.Message}");
            }
        }
    }

    private bool LoadDataFromDisk()
    {
        lock (_fileLock)
        {
            try
            {
                foreach (var dir in _storageDirs)
                {
                    var evPath = Path.Combine(dir, "events.json");
                    var gPath = Path.Combine(dir, "guests.json");
                    var uPath = Path.Combine(dir, "users.json");

                    if (File.Exists(evPath))
                    {
                        var jsonEvents = File.ReadAllText(evPath);
                        var eventsList = JsonSerializer.Deserialize<List<Event>>(jsonEvents);
                        if (eventsList != null)
                        {
                            _events.Clear();
                            foreach (var ev in eventsList)
                            {
                                _events[ev.EventId] = ev;
                            }

                            _guests.Clear();
                            if (File.Exists(gPath))
                            {
                                var jsonGuests = File.ReadAllText(gPath);
                                var allGuests = JsonSerializer.Deserialize<Dictionary<string, List<Guest>>>(jsonGuests);
                                if (allGuests != null)
                                {
                                    foreach (var kvp in allGuests)
                                    {
                                        var map = new ConcurrentDictionary<string, Guest>();
                                        foreach (var g in kvp.Value)
                                        {
                                            map[g.GuestId] = g;
                                        }
                                        _guests[kvp.Key] = map;
                                    }
                                }
                            }

                            _users.Clear();
                            if (File.Exists(uPath))
                            {
                                var jsonUsers = File.ReadAllText(uPath);
                                var usersList = JsonSerializer.Deserialize<List<User>>(jsonUsers);
                                if (usersList != null)
                                {
                                    foreach (var u in usersList)
                                    {
                                        _users[u.UserId] = u;
                                    }
                                }
                            }

                            // Ensure default admin exists
                            EnsureDefaultAdmin();
                            return true;
                        }
                    }
                }
                return false;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"LoadDataFromDisk warning: {ex.Message}");
                return false;
            }
        }
    }

    private void EnsureDefaultAdmin()
    {
        if (!_users.Values.Any(u => u.Username.Equals("admin", StringComparison.OrdinalIgnoreCase)))
        {
            var admin = new User
            {
                UserId = "user_admin",
                Username = "admin",
                PasswordHash = HashPassword("ZiEiHrpPq@"),
                Role = "Admin",
                DisplayName = "系統總管理員",
                Organization = "InPoint 核心管理中心",
                PlanType = "Unlimited",
                ExpireAt = null,
                MaxGuestsPerEvent = 99999,
                MaxEvents = -1,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                Notes = "系統預設最高權限管理員"
            };
            _users[admin.UserId] = admin;
        }
    }

    private void SeedInitialData()
    {
        EnsureDefaultAdmin();

        // Seed demo members
        var singleMember = new User
        {
            UserId = "user_single_demo",
            Username = "single_demo",
            PasswordHash = HashPassword("123456"),
            Role = "Member",
            DisplayName = "陳專員 (單場活動試用)",
            Organization = "前瞻生醫研發中心",
            PlanType = "SingleEvent",
            ExpireAt = DateTime.UtcNow.AddDays(7),
            MaxGuestsPerEvent = 500,
            MaxEvents = 1,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            Notes = "單場活動 7 天授權體驗帳號"
        };
        _users[singleMember.UserId] = singleMember;

        var annualMember = new User
        {
            UserId = "user_annual_demo",
            Username = "annual_demo",
            PasswordHash = HashPassword("123456"),
            Role = "Member",
            DisplayName = "林主任 (機構年度專案)",
            Organization = "秀傳醫療體系 - 營運管理部",
            PlanType = "AnnualOrg",
            ExpireAt = DateTime.UtcNow.AddYears(1),
            MaxGuestsPerEvent = 1500,
            MaxEvents = -1,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            Notes = "機構年度方案完整功能帳號"
        };
        _users[annualMember.UserId] = annualMember;

        // Default Event
        var ev = new Event
        {
            EventId = "event_2026_annual",
            EventName = "2026 年度智慧醫療與科技高峰研討會",
            EventDate = new DateTime(2026, 8, 28, 9, 0, 0),
            Location = "醫療大樓 9F 國際會議廳",
            Description = "邀請衛生主管機關、醫療體系長官及產官學各界專家蒞臨交流指導。",
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            OwnerUsername = "admin"
        };
        _events[ev.EventId] = ev;

        var guestList = new List<Guest>
        {
            new Guest { GuestId = "00601441", EventId = ev.EventId, Name = "邱部長", Organization = "衛生福利部", Title = "部長", RankWeight = 1, TableNo = "VIP-1 主桌", IsCheckedIn = false, QrCodeHash = "SC-2026-00601441", Phone = "0912-345-678", Notes = "特邀致詞貴賓" },
            new Guest { GuestId = "00601442", EventId = ev.EventId, Name = "黃院長", Organization = "秀傳紀念醫院", Title = "院長", RankWeight = 1, TableNo = "VIP-1 主桌", IsCheckedIn = false, QrCodeHash = "SC-2026-00601442", Phone = "0922-111-222", Notes = "大會主席" },
            new Guest { GuestId = "00601443", EventId = ev.EventId, Name = "李局長", Organization = "彰化縣衛生局", Title = "局長", RankWeight = 1, TableNo = "VIP-1 主桌", IsCheckedIn = false, QrCodeHash = "SC-2026-00601443", Phone = "0933-555-777", Notes = "專案指導長官" },
            new Guest { GuestId = "00601444", EventId = ev.EventId, Name = "張副院長", Organization = "彰濱秀傳紀念醫院", Title = "副院長", RankWeight = 2, TableNo = "VIP-2 貴賓席", IsCheckedIn = false, QrCodeHash = "SC-2026-00601444", Phone = "0988-999-000", Notes = "座談引言人" },
            new Guest { GuestId = "00601445", EventId = ev.EventId, Name = "王科長", Organization = "國民健康署", Title = "科長", RankWeight = 2, TableNo = "VIP-2 貴賓席", IsCheckedIn = false, QrCodeHash = "SC-2026-00601445", Phone = "0911-223-344", Notes = "指導長官" },
            new Guest { GuestId = "00601446", EventId = ev.EventId, Name = "陳主任", Organization = "心血管醫學部", Title = "主任", RankWeight = 3, TableNo = "第 3 組 (12桌)", IsCheckedIn = false, QrCodeHash = "SC-2026-00601446", Phone = "0955-667-788", Notes = "專題講師" },
            new Guest { GuestId = "00601447", EventId = ev.EventId, Name = "林組長", Organization = "資訊科技處", Title = "組長", RankWeight = 3, TableNo = "第 3 組 (12桌)", IsCheckedIn = false, QrCodeHash = "SC-2026-00601447", Phone = "0966-778-899", Notes = "系統維運代表" },
            new Guest { GuestId = "00601448", EventId = ev.EventId, Name = "趙管理師", Organization = "品質管理中心", Title = "資深管理師", RankWeight = 4, TableNo = "第 5 組 (15桌)", IsCheckedIn = false, QrCodeHash = "SC-2026-00601448", Phone = "0977-889-900", Notes = "工作人員" }
        };

        var map = new ConcurrentDictionary<string, Guest>();
        foreach (var g in guestList)
        {
            map[g.GuestId] = g;
        }
        _guests[ev.EventId] = map;
    }

    public static string HashPassword(string password)
    {
        if (string.IsNullOrEmpty(password)) return string.Empty;
        using var sha = System.Security.Cryptography.SHA256.Create();
        var bytes = sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes("InPoint_salt_" + password.Trim()));
        return Convert.ToHexString(bytes).ToLower();
    }

    public static bool VerifyPassword(string password, string storedHash)
    {
        if (string.IsNullOrEmpty(storedHash)) return false;
        if (storedHash == password.Trim()) return true;
        return HashPassword(password) == storedHash;
    }

    // --- Events ---

    public Task<List<Event>> GetEventsAsync(string? ownerUsername = null, string role = "Admin")
    {
        var list = _events.Values.AsEnumerable();
        if (role == "Member" && !string.IsNullOrWhiteSpace(ownerUsername))
        {
            list = list.Where(e => string.Equals(e.OwnerUsername, ownerUsername, StringComparison.OrdinalIgnoreCase) || string.IsNullOrEmpty(e.OwnerUsername));
        }

        return Task.FromResult(list
            .OrderByDescending(e => e.IsActive)
            .ThenByDescending(e => e.EventDate)
            .ToList());
    }

    public Task<Event?> GetEventByIdAsync(string eventId)
    {
        _events.TryGetValue(eventId, out var ev);
        return Task.FromResult(ev);
    }

    public Task<Event> CreateEventAsync(Event newEvent)
    {
        if (string.IsNullOrWhiteSpace(newEvent.EventId))
        {
            newEvent.EventId = $"event_{DateTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid().ToString("N")[..6]}";
        }
        newEvent.CreatedAt = DateTime.UtcNow;
        _events[newEvent.EventId] = newEvent;
        _guests.TryAdd(newEvent.EventId, new ConcurrentDictionary<string, Guest>());
        SaveDataToDisk();
        return Task.FromResult(newEvent);
    }

    public Task<bool> UpdateEventAsync(Event updatedEvent)
    {
        if (_events.TryGetValue(updatedEvent.EventId, out var existing))
        {
            existing.EventName = updatedEvent.EventName;
            existing.EventDate = updatedEvent.EventDate;
            existing.Location = updatedEvent.Location;
            existing.Description = updatedEvent.Description;
            existing.IsActive = updatedEvent.IsActive;
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<bool> ArchiveEventAsync(string eventId, bool? targetStatus = null)
    {
        if (_events.TryGetValue(eventId, out var ev))
        {
            ev.IsActive = targetStatus.HasValue ? targetStatus.Value : !ev.IsActive;
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<bool> DeleteEventAsync(string eventId)
    {
        _events.TryRemove(eventId, out _);
        _guests.TryRemove(eventId, out _);
        SaveDataToDisk();
        return Task.FromResult(true);
    }

    public Task<Event> CloneEventAsync(string sourceEventId, string newEventName, DateTime newEventDate, string? location, string? description, bool copyGuests, string? ownerUsername)
    {
        _events.TryGetValue(sourceEventId, out var sourceEv);
        var newId = $"event_{DateTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid().ToString("N")[..6]}";

        var newEvent = new Event
        {
            EventId = newId,
            EventName = string.IsNullOrWhiteSpace(newEventName) ? $"[複製] {sourceEv?.EventName ?? "新活動"}" : newEventName,
            EventDate = newEventDate != default ? newEventDate : DateTime.UtcNow,
            Location = location ?? sourceEv?.Location ?? "大會國際會議廳",
            Description = description ?? sourceEv?.Description ?? string.Empty,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            OwnerUsername = ownerUsername
        };

        _events[newEvent.EventId] = newEvent;
        var guestMap = new ConcurrentDictionary<string, Guest>();

        if (copyGuests && _guests.TryGetValue(sourceEventId, out var sourceGuests))
        {
            foreach (var g in sourceGuests.Values)
            {
                var cloneG = new Guest
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
                };
                guestMap[cloneG.GuestId] = cloneG;
            }
        }

        _guests[newId] = guestMap;
        SaveDataToDisk();
        return Task.FromResult(newEvent);
    }

    // --- Guests ---

    public Task<List<Guest>> GetGuestsAsync(string eventId)
    {
        if (_guests.TryGetValue(eventId, out var map))
        {
            return Task.FromResult(map.Values
                .OrderBy(g => g.RankWeight)
                .ThenBy(g => g.TableNo)
                .ThenBy(g => g.GuestId)
                .ToList());
        }
        return Task.FromResult(new List<Guest>());
    }

    public Task<Guest?> GetGuestByIdAsync(string eventId, string guestId)
    {
        if (_guests.TryGetValue(eventId, out var map) && map.TryGetValue(guestId, out var guest))
        {
            return Task.FromResult<Guest?>(guest);
        }
        return Task.FromResult<Guest?>(null);
    }

    public Task<Guest?> GetGuestByQrCodeAsync(string qrCodeOrId)
    {
        if (string.IsNullOrWhiteSpace(qrCodeOrId)) return Task.FromResult<Guest?>(null);
        var clean = qrCodeOrId.Trim();
        var stripped = clean.TrimStart('0');
        if (string.IsNullOrEmpty(stripped)) stripped = "0";

        foreach (var map in _guests.Values)
        {
            var match = map.Values.FirstOrDefault(g => 
                g.QrCodeHash == clean || 
                g.GuestId == clean || 
                g.GuestId == stripped || 
                g.Phone == clean);

            if (match == null && stripped != clean)
            {
                match = map.Values.FirstOrDefault(g => g.GuestId.TrimStart('0') == stripped);
            }

            if (match != null) return Task.FromResult<Guest?>(match);
        }
        return Task.FromResult<Guest?>(null);
    }

    public Task<Guest> AddGuestAsync(Guest guest)
    {
        var map = _guests.GetOrAdd(guest.EventId, _ => new ConcurrentDictionary<string, Guest>());
        if (string.IsNullOrWhiteSpace(guest.GuestId))
        {
            guest.GuestId = $"G-{(map.Count + 1):D3}";
        }
        if (string.IsNullOrWhiteSpace(guest.QrCodeHash))
        {
            guest.QrCodeHash = $"SC-{guest.EventId.Replace("event_", "")}-{guest.GuestId}";
        }
        guest.CreatedAt = DateTime.UtcNow;
        map[guest.GuestId] = guest;
        SaveDataToDisk();
        return Task.FromResult(guest);
    }

    public Task<List<Guest>> BatchAddGuestsAsync(string eventId, List<Guest> guests)
    {
        var map = _guests.GetOrAdd(eventId, _ => new ConcurrentDictionary<string, Guest>());
        var seenIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        int autoIndex = map.Count + 1;
        var addedList = new List<Guest>();

        foreach (var guest in guests)
        {
            guest.EventId = eventId;
            var id = guest.GuestId?.Trim();
            if (string.IsNullOrWhiteSpace(id) || seenIds.Contains(id))
            {
                while (map.ContainsKey($"G-{autoIndex:D3}") || seenIds.Contains($"G-{autoIndex:D3}"))
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

            map[guest.GuestId] = guest;
            addedList.Add(guest);
        }

        SaveDataToDisk();
        return Task.FromResult(addedList);
    }

    public Task<bool> UpdateGuestAsync(Guest guest)
    {
        if (_guests.TryGetValue(guest.EventId, out var map) && map.TryGetValue(guest.GuestId, out var existing))
        {
            existing.Name = guest.Name;
            existing.Organization = guest.Organization;
            existing.Title = guest.Title;
            existing.RankWeight = guest.RankWeight;
            existing.TableNo = guest.TableNo;
            existing.Phone = guest.Phone;
            existing.Notes = guest.Notes;
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<bool> DeleteGuestAsync(string eventId, string guestId)
    {
        if (_guests.TryGetValue(eventId, out var map))
        {
            map.TryRemove(guestId, out _);
            SaveDataToDisk();
        }
        return Task.FromResult(true);
    }

    public Task<bool> ClearAllGuestsAsync(string eventId)
    {
        if (_guests.TryGetValue(eventId, out var map))
        {
            map.Clear();
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<Guest?> ToggleCheckInAsync(string eventId, string guestId, bool? targetStatus, string staffName)
    {
        if (_guests.TryGetValue(eventId, out var map) && map.TryGetValue(guestId, out var guest))
        {
            bool newStatus = targetStatus ?? !guest.IsCheckedIn;
            guest.IsCheckedIn = newStatus;
            if (newStatus)
            {
                guest.CheckedInAt = DateTime.Now;
                guest.CheckedInBy = staffName;
            }
            else
            {
                guest.CheckedInAt = null;
                guest.CheckedInBy = null;
            }
            SaveDataToDisk();
            return Task.FromResult<Guest?>(guest);
        }
        return Task.FromResult<Guest?>(null);
    }

    // --- Users / Members ---

    public Task<List<MemberDto>> GetMembersAsync()
    {
        var list = _users.Values
            .Where(u => u.Role != "Admin")
            .OrderByDescending(u => u.CreatedAt)
            .Select(u => new MemberDto
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
                EventCount = _events.Values.Count(e => string.Equals(e.OwnerUsername, u.Username, StringComparison.OrdinalIgnoreCase))
            })
            .ToList();

        return Task.FromResult(list);
    }

    public Task<User?> GetUserByIdAsync(string userId)
    {
        _users.TryGetValue(userId, out var user);
        return Task.FromResult(user);
    }

    public Task<User?> GetUserByUsernameAsync(string username)
    {
        var user = _users.Values.FirstOrDefault(u => string.Equals(u.Username, username?.Trim(), StringComparison.OrdinalIgnoreCase));
        return Task.FromResult(user);
    }

    public Task<User> CreateUserAsync(User user)
    {
        if (string.IsNullOrWhiteSpace(user.UserId))
        {
            user.UserId = "user_" + Guid.NewGuid().ToString("N")[..12];
        }
        user.CreatedAt = DateTime.UtcNow;
        _users[user.UserId] = user;
        SaveDataToDisk();
        return Task.FromResult(user);
    }

    public Task<bool> UpdateUserAsync(User user)
    {
        if (_users.TryGetValue(user.UserId, out var existing))
        {
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
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<bool> DeleteUserAsync(string userId)
    {
        if (_users.TryGetValue(userId, out var user))
        {
            if (user.Role == "Admin") return Task.FromResult(false);
            _users.TryRemove(userId, out _);
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<bool> ToggleUserStatusAsync(string userId, bool? targetStatus = null)
    {
        if (_users.TryGetValue(userId, out var user))
        {
            user.IsActive = targetStatus ?? !user.IsActive;
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<bool> ResetUserPasswordAsync(string userId, string newPassword)
    {
        if (_users.TryGetValue(userId, out var user))
        {
            user.PasswordHash = HashPassword(newPassword);
            SaveDataToDisk();
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<int> GetUserEventCountAsync(string username)
    {
        var count = _events.Values.Count(e => string.Equals(e.OwnerUsername, username, StringComparison.OrdinalIgnoreCase));
        return Task.FromResult(count);
    }

    // --- Stats, Export & AI ---

    public Task<EventSummaryStats> GetEventStatsAsync(string eventId)
    {
        if (_guests.TryGetValue(eventId, out var map))
        {
            var guests = map.Values.ToList();
            var total = guests.Count;
            var checkedCount = guests.Count(g => g.IsCheckedIn);
            var pendingCount = total - checkedCount;
            var attRate = total > 0 ? Math.Round((double)checkedCount / total * 100, 1) : 0;

            var vips = guests.Where(g => g.RankWeight <= 2).ToList();
            var vipTotal = vips.Count;
            var vipChecked = vips.Count(g => g.IsCheckedIn);
            var vipRate = vipTotal > 0 ? Math.Round((double)vipChecked / vipTotal * 100, 1) : 0;

            return Task.FromResult(new EventSummaryStats
            {
                TotalGuests = total,
                CheckedInCount = checkedCount,
                PendingCount = pendingCount,
                AttendanceRate = attRate,
                VipTotal = vipTotal,
                VipCheckedIn = vipChecked,
                VipAttendanceRate = vipRate
            });
        }

        return Task.FromResult(new EventSummaryStats());
    }

    public Task<string> ExportCsvAsync(string eventId)
    {
        _events.TryGetValue(eventId, out var ev);
        var eventName = ev?.EventName ?? eventId;

        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"# 活動報到名冊 - {eventName}");
        sb.AppendLine($"# 匯出時間：{DateTime.Now:yyyy/MM/dd HH:mm:ss}");
        sb.AppendLine("貴賓編號,姓名,服務單位,職稱,職級權重,桌次/座位,報到狀態,報到時間,經手人員,專屬QR碼,電話,備註");

        if (_guests.TryGetValue(eventId, out var map))
        {
            var sorted = map.Values
                .OrderBy(g => g.RankWeight)
                .ThenBy(g => g.TableNo)
                .ThenBy(g => g.GuestId);

            foreach (var g in sorted)
            {
                var checkInStatus = g.IsCheckedIn ? "已報到" : "未報到";
                var checkInTime = g.CheckedInAt.HasValue ? g.CheckedInAt.Value.ToString("yyyy/MM/dd HH:mm:ss") : "";
                var rankDesc = g.RankWeight switch
                {
                    1 => "1-特級長官/院長",
                    2 => "2-副院長/民代",
                    3 => "3-科部主任/專家",
                    _ => "4-一般貴賓"
                };

                sb.AppendLine($"\"{g.GuestId}\",\"{g.Name}\",\"{g.Organization}\",\"{g.Title}\",\"{rankDesc}\",\"{g.TableNo}\",\"{checkInStatus}\",\"{checkInTime}\",\"{g.CheckedInBy ?? ""}\",\"{g.QrCodeHash}\",\"{g.Phone ?? ""}\",\"{g.Notes ?? ""}\"");
            }
        }

        return Task.FromResult(sb.ToString());
    }

    public Task<List<Guest>> ParseRawGuestTextAsync(string eventId, string rawText)
    {
        var result = new List<Guest>();
        if (string.IsNullOrWhiteSpace(rawText)) return Task.FromResult(result);

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
            if (title.Contains("總裁") || title.Contains("院長") || title.Contains("部長") || title.Contains("局長") || title.Contains("董事長") || title.Contains("次長") || title.Contains("署長"))
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
                GuestId = $"IMP-{DateTime.Now:HHmmss}-{autoId++:D2}",
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

        return Task.FromResult(result);
    }

    public async Task<string> ProcessAiQueryAsync(string eventId, string query)
    {
        var guests = await GetGuestsAsync(eventId);
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
                    sb.AppendLine($"- ✅ 【{g.Organization}】{g.Title} **{g.Name}**（桌次：{g.TableNo} / 報到時間：{g.CheckedInAt:HH:mm}）");
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

    public Task<object> GetStorageDiagnosticsAsync()
    {
        return Task.FromResult<object>(new
        {
            serviceMode = "InMemoryEventService (Local JSON Storage)",
            databaseType = "JSON File Persistence",
            serverTime = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss"),
            machineName = Environment.MachineName,
            storageDirectories = _storageDirs,
            eventsCount = _events.Count,
            guestsCount = _guests.Values.Sum(m => m.Count),
            usersCount = _users.Count
        });
    }
}
