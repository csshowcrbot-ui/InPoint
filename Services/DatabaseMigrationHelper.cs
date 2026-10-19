using System;
using System.IO;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using ShowChwanCheckIn.Data;
using ShowChwanCheckIn.Models;

namespace ShowChwanCheckIn.Services;

public static class DatabaseMigrationHelper
{
    private const string LEGACY_ZEABUR_URL = "postgresql://root:WFrQ2E753JL9ec6USijDO01kNM4n8bfg@54.150.14.236:32694/zeabur";
    private const string TARGET_REAL_EVENT_ID = "event_20261020_055937_53ed8a";
    private const string DUMMY_EVENT_ID = "event_20260917_084526";

    public record MigrationResult(bool Success, string Message, int EventsCount, int UsersCount, int GuestsCount);

    /// <summary>
    /// 在系統啟動時檢查是否需要自 Zeabur 遷移資料
    /// </summary>
    public static async Task AutoMigrateOnStartupAsync(AppDbContext db, string? activeConnStr, bool isPostgres)
    {
        if (!isPostgres || string.IsNullOrWhiteSpace(activeConnStr))
            return;

        try
        {
            // 檢查是否已存在真實活動
            bool hasRealEvent = await db.Events.AnyAsync(e => e.EventId == TARGET_REAL_EVENT_ID);
            if (!hasRealEvent)
            {
                Console.WriteLine("[Migration] 檢測到 Railway PostgreSQL 尚未包含 Zeabur 真實活動資料，啟動自動資料遷移...");
                var res = await ExecuteMigrationAsync(db, activeConnStr, force: false);
                Console.WriteLine($"[Migration] 遷移結果: {res.Message} (活動: {res.EventsCount}, 名冊: {res.GuestsCount}, 會員: {res.UsersCount})");
            }
            else
            {
                // 已有真實資料，安全清除初期產生的假活動
                await CleanDummyEventAsync(db);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Migration Notice] 自動遷移程序提示: {ex.Message}");
        }
    }

    /// <summary>
    /// 執行完整遷移程序 (支援線上拉取與離線快照容錯)
    /// </summary>
    public static async Task<MigrationResult> ExecuteMigrationAsync(AppDbContext db, string targetConnStr, bool force = false)
    {
        bool hasRealEvent = await db.Events.AnyAsync(e => e.EventId == TARGET_REAL_EVENT_ID);
        if (hasRealEvent && !force)
        {
            return new MigrationResult(true, "資料庫已存在真實活動資料，略過重複遷移。", 
                await db.Events.CountAsync(), await db.Users.CountAsync(), await db.Guests.CountAsync());
        }

        string formattedTargetConnStr = ConvertPostgresUrlToConnectionString(targetConnStr);

        // 策略 1: 嘗試透過公網直接連線 Zeabur 線上資料庫進行即時同步
        try
        {
            Console.WriteLine("[Migration Strategy 1] 嘗試直連 Zeabur 線上 PostgreSQL 進行即時同步...");
            var zeaburConnStr = ConvertPostgresUrlToConnectionString(LEGACY_ZEABUR_URL);
            using var zeaburConn = new NpgsqlConnection(zeaburConnStr);
            await zeaburConn.OpenAsync();

            // 自 Zeabur 讀取最新資料
            var liveUsers = new List<User>();
            var liveEvents = new List<Event>();
            var liveGuests = new List<Guest>();

            // 1. Users
            using (var uCmd = new NpgsqlCommand(@"SELECT ""UserId"", ""Username"", ""PasswordHash"", ""Role"", ""DisplayName"", ""Organization"", ""PlanType"", ""ExpireAt"", ""MaxGuestsPerEvent"", ""MaxEvents"", ""IsActive"", ""CreatedAt"", ""Notes"" FROM ""checkInUsers"";", zeaburConn))
            using (var r = await uCmd.ExecuteReaderAsync())
            {
                while (await r.ReadAsync())
                {
                    liveUsers.Add(new User
                    {
                        UserId = r.GetString(0),
                        Username = r.GetString(1),
                        PasswordHash = r.GetString(2),
                        Role = r.IsDBNull(3) ? "Member" : r.GetString(3),
                        DisplayName = r.IsDBNull(4) ? "" : r.GetString(4),
                        Organization = r.IsDBNull(5) ? "" : r.GetString(5),
                        PlanType = r.IsDBNull(6) ? "SingleEvent" : r.GetString(6),
                        ExpireAt = r.IsDBNull(7) ? null : r.GetDateTime(7),
                        MaxGuestsPerEvent = r.GetInt32(8),
                        MaxEvents = r.GetInt32(9),
                        IsActive = r.GetBoolean(10),
                        CreatedAt = r.GetDateTime(11),
                        Notes = r.IsDBNull(12) ? null : r.GetString(12)
                    });
                }
            }

            // 2. Events
            using (var eCmd = new NpgsqlCommand(@"SELECT ""EventId"", ""EventName"", ""EventDate"", ""Location"", ""Description"", ""IsActive"", ""CreatedAt"", ""OwnerUsername"", ""RankRules"" FROM ""checkInEvents"";", zeaburConn))
            using (var r = await eCmd.ExecuteReaderAsync())
            {
                while (await r.ReadAsync())
                {
                    liveEvents.Add(new Event
                    {
                        EventId = r.GetString(0),
                        EventName = r.GetString(1),
                        EventDate = r.GetDateTime(2),
                        Location = r.IsDBNull(3) ? "" : r.GetString(3),
                        Description = r.IsDBNull(4) ? "" : r.GetString(4),
                        IsActive = r.GetBoolean(5),
                        CreatedAt = r.GetDateTime(6),
                        OwnerUsername = r.IsDBNull(7) ? null : r.GetString(7),
                        RankRules = r.IsDBNull(8) ? null : r.GetString(8)
                    });
                }
            }

            // 3. Guests
            using (var gCmd = new NpgsqlCommand(@"SELECT ""EventId"", ""GuestId"", ""Name"", ""Organization"", ""Title"", ""RankWeight"", ""TableNo"", ""IsCheckedIn"", ""CheckedInAt"", ""CheckedInBy"", ""QrCodeHash"", ""Phone"", ""Notes"" FROM ""checkInGuests"";", zeaburConn))
            using (var r = await gCmd.ExecuteReaderAsync())
            {
                while (await r.ReadAsync())
                {
                    liveGuests.Add(new Guest
                    {
                        EventId = r.GetString(0),
                        GuestId = r.GetString(1),
                        Name = r.IsDBNull(2) ? "" : r.GetString(2),
                        Organization = r.IsDBNull(3) ? "" : r.GetString(3),
                        Title = r.IsDBNull(4) ? "" : r.GetString(4),
                        RankWeight = r.GetInt32(5),
                        TableNo = r.IsDBNull(6) ? "" : r.GetString(6),
                        IsCheckedIn = r.GetBoolean(7),
                        CheckedInAt = r.IsDBNull(8) ? null : r.GetDateTime(8),
                        CheckedInBy = r.IsDBNull(9) ? null : r.GetString(9),
                        QrCodeHash = r.IsDBNull(10) ? "" : r.GetString(10),
                        Phone = r.IsDBNull(11) ? null : r.GetString(11),
                        Notes = r.IsDBNull(12) ? null : r.GetString(12)
                    });
                }
            }

            // 寫入 Railway PostgreSQL (具備 UPSERT 邏輯)
            foreach (var u in liveUsers)
            {
                var existing = await db.Users.FirstOrDefaultAsync(x => x.UserId == u.UserId || x.Username == u.Username);
                if (existing != null)
                {
                    existing.Username = u.Username;
                    existing.PasswordHash = u.PasswordHash;
                    existing.Role = u.Role;
                    existing.DisplayName = u.DisplayName;
                    existing.Organization = u.Organization;
                    existing.PlanType = u.PlanType;
                    existing.ExpireAt = u.ExpireAt;
                    existing.MaxGuestsPerEvent = u.MaxGuestsPerEvent;
                    existing.MaxEvents = u.MaxEvents;
                    existing.IsActive = u.IsActive;
                    existing.Notes = u.Notes;
                }
                else
                {
                    db.Users.Add(u);
                }
            }
            await db.SaveChangesAsync();

            foreach (var ev in liveEvents)
            {
                var existing = await db.Events.FirstOrDefaultAsync(x => x.EventId == ev.EventId);
                if (existing != null)
                {
                    existing.EventName = ev.EventName;
                    existing.EventDate = ev.EventDate;
                    existing.Location = ev.Location;
                    existing.Description = ev.Description;
                    existing.IsActive = ev.IsActive;
                    existing.OwnerUsername = ev.OwnerUsername;
                    existing.RankRules = ev.RankRules;
                }
                else
                {
                    db.Events.Add(ev);
                }
            }
            await db.SaveChangesAsync();

            foreach (var g in liveGuests)
            {
                var existing = await db.Guests.FirstOrDefaultAsync(x => x.EventId == g.EventId && x.GuestId == g.GuestId);
                if (existing != null)
                {
                    existing.Name = g.Name;
                    existing.Organization = g.Organization;
                    existing.Title = g.Title;
                    existing.RankWeight = g.RankWeight;
                    existing.TableNo = g.TableNo;
                    existing.IsCheckedIn = g.IsCheckedIn;
                    existing.CheckedInAt = g.CheckedInAt;
                    existing.CheckedInBy = g.CheckedInBy;
                    existing.QrCodeHash = g.QrCodeHash;
                    existing.Phone = g.Phone;
                    existing.Notes = g.Notes;
                }
                else
                {
                    db.Guests.Add(g);
                }
            }
            await db.SaveChangesAsync();

            await CleanDummyEventAsync(db);

            return new MigrationResult(true, "自 Zeabur 線上資料庫即時熱遷移成功！", liveEvents.Count, liveUsers.Count, liveGuests.Count);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Migration Strategy 1 Failed] 直連 Zeabur 失敗 ({ex.Message})，啟動 Strategy 2 (執行安全快照 SQL)...");
        }

        // 策略 2: 直連失敗時，透過專案內建的 migration_zeabur_to_railway.sql 執行完整匯入
        try
        {
            var sqlFile = FindSqlScriptPath();
            if (!string.IsNullOrWhiteSpace(sqlFile) && File.Exists(sqlFile))
            {
                Console.WriteLine($"[Migration Strategy 2] 正在執行 SQL 快照檔案: {sqlFile}");
                var sqlContent = await File.ReadAllTextAsync(sqlFile);

                using var targetConn = new NpgsqlConnection(formattedTargetConnStr);
                await targetConn.OpenAsync();
                using var transCmd = new NpgsqlCommand(sqlContent, targetConn);
                transCmd.CommandTimeout = 60;
                await transCmd.ExecuteNonQueryAsync();

                await CleanDummyEventAsync(db);

                int evCount = await db.Events.CountAsync();
                int uCount = await db.Users.CountAsync();
                int gCount = await db.Guests.CountAsync();

                return new MigrationResult(true, "透過內建 Zeabur 歷史資料庫快照 SQL 遷移成功！", evCount, uCount, gCount);
            }
            else
            {
                return new MigrationResult(false, "找不到 migration_zeabur_to_railway.sql 快照檔案，無法執行備援遷移。", 0, 0, 0);
            }
        }
        catch (Exception sqlEx)
        {
            Console.WriteLine($"[Migration Strategy 2 Failed] SQL 執行失敗: {sqlEx.Message}");
            return new MigrationResult(false, $"遷移失敗: {sqlEx.Message}", 0, 0, 0);
        }
    }

    private static async Task CleanDummyEventAsync(AppDbContext db)
    {
        try
        {
            var dummy = await db.Events.FirstOrDefaultAsync(e => e.EventId == DUMMY_EVENT_ID);
            if (dummy != null)
            {
                Console.WriteLine("[Migration] 清理初期產生的假活動 '月烤月嗨' 及相關測試名冊...");
                var dummyGuests = await db.Guests.Where(g => g.EventId == DUMMY_EVENT_ID).ToListAsync();
                if (dummyGuests.Any()) db.Guests.RemoveRange(dummyGuests);
                db.Events.Remove(dummy);
                await db.SaveChangesAsync();
                Console.WriteLine("[Migration] 假活動清理完畢，資料庫已純化為正式歷史真實資料。");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Migration] 清理假活動提示: {ex.Message}");
        }
    }

    private static string? FindSqlScriptPath()
    {
        string[] candidates = new[]
        {
            "migration_zeabur_to_railway.sql",
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "migration_zeabur_to_railway.sql"),
            Path.Combine(Directory.GetCurrentDirectory(), "migration_zeabur_to_railway.sql"),
            Path.Combine("..", "migration_zeabur_to_railway.sql")
        };

        foreach (var c in candidates)
        {
            if (File.Exists(c)) return Path.GetFullPath(c);
        }
        return null;
    }

    private static string ConvertPostgresUrlToConnectionString(string url)
    {
        if (!url.StartsWith("postgres://") && !url.StartsWith("postgresql://"))
            return url;

        try
        {
            var uri = new Uri(url.Replace("postgresql://", "http://").Replace("postgres://", "http://"));
            var userInfo = uri.UserInfo.Split(':');
            var builder = new NpgsqlConnectionStringBuilder
            {
                Host = uri.Host,
                Port = uri.Port > 0 ? uri.Port : 5432,
                Username = userInfo[0],
                Password = userInfo.Length > 1 ? userInfo[1] : "",
                Database = uri.AbsolutePath.TrimStart('/'),
                SslMode = SslMode.Prefer,
                Timeout = 15
            };
            return builder.ConnectionString;
        }
        catch
        {
            return url;
        }
    }
}
