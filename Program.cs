using System.Collections.Concurrent;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using ShowChwanCheckIn.Common;
using ShowChwanCheckIn.Data;
using ShowChwanCheckIn.Hubs;
using ShowChwanCheckIn.Models;
using ShowChwanCheckIn.Services;

var builder = WebApplication.CreateBuilder(args);

var rawConnStr = builder.Configuration.GetConnectionString("DefaultConnection");
var activeConnStr = ResolveWorkingConnectionString(rawConnStr);
bool useSql = !string.IsNullOrWhiteSpace(activeConnStr);
bool isPostgres = useSql && (activeConnStr.StartsWith("postgres://") || activeConnStr.StartsWith("postgresql://") || activeConnStr.Contains("Host="));

if (isPostgres)
{
    var pgConnStr = ConvertPostgresUrlToConnectionString(activeConnStr);
    builder.Services.AddDbContextFactory<AppDbContext>(options =>
    {
        options.UseNpgsql(pgConnStr);
    });
    builder.Services.AddSingleton<IEventService, SqlEventService>();
}
else if (useSql)
{
    builder.Services.AddDbContextFactory<AppDbContext>(options =>
    {
        options.UseSqlServer(activeConnStr, sqlOpts =>
        {
            sqlOpts.EnableRetryOnFailure(maxRetryCount: 3, maxRetryDelay: TimeSpan.FromSeconds(5), errorNumbersToAdd: null);
        });
    });
    builder.Services.AddSingleton<IEventService, SqlEventService>();
}
else
{
    builder.Services.AddSingleton<IEventService, InMemoryEventService>();
}

builder.Services.AddSignalR();
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Database Table Auto-Creation / Migration for SQL Server or PostgreSQL
if (useSql)
{
    try
    {
        var factory = app.Services.GetRequiredService<IDbContextFactory<AppDbContext>>();
        using var db = factory.CreateDbContext();
        db.Database.EnsureCreated();

        if (isPostgres)
        {
            try
            {
                var pgConnStr = ConvertPostgresUrlToConnectionString(activeConnStr);
                using var pgConn = new NpgsqlConnection(pgConnStr);
                pgConn.Open();

                var alterPgSql = @"
                DO $$
                BEGIN
                    -- 檢查並為 checkInEvents (雙引號駝峰表名) 新增欄位
                    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'checkInEvents') THEN
                        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'checkInEvents' AND column_name = 'RankRules') THEN
                            ALTER TABLE ""checkInEvents"" ADD COLUMN ""RankRules"" TEXT NULL;
                        END IF;
                        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'checkInEvents' AND column_name = 'OwnerUsername') THEN
                            ALTER TABLE ""checkInEvents"" ADD COLUMN ""OwnerUsername"" VARCHAR(100) NULL;
                        END IF;
                    END IF;

                    -- 檢查並為 checkinevents (全小寫表名) 新增欄位
                    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'checkinevents') THEN
                        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'checkinevents' AND column_name = 'RankRules') THEN
                            ALTER TABLE checkinevents ADD COLUMN ""RankRules"" TEXT NULL;
                        END IF;
                        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'checkinevents' AND column_name = 'rankrules') THEN
                            ALTER TABLE checkinevents ADD COLUMN rankrules TEXT NULL;
                        END IF;
                        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'checkinevents' AND column_name = 'OwnerUsername') THEN
                            ALTER TABLE checkinevents ADD COLUMN ""OwnerUsername"" VARCHAR(100) NULL;
                        END IF;
                        IF NOT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'checkinevents' AND column_name = 'ownerusername') THEN
                            ALTER TABLE checkinevents ADD COLUMN ownerusername VARCHAR(100) NULL;
                        END IF;
                    END IF;
                END $$;
                ";
                using var alterCmd = new NpgsqlCommand(alterPgSql, pgConn);
                alterCmd.ExecuteNonQuery();
                Console.WriteLine("[PostgreSQL DB] Alter table column check executed successfully.");
            }
            catch (Exception pgEx)
            {
                Console.WriteLine($"[PostgreSQL DB] Alter column migration note: {pgEx.Message}");
            }

            if (!db.Users.Any(u => u.Username == "admin"))
            {
                db.Users.Add(new User
                {
                    UserId = "user_admin",
                    Username = "admin",
                    PasswordHash = InMemoryEventService.HashPassword("ZiEiHrpPq@"),
                    Role = "Admin",
                    DisplayName = "系統最高管理員",
                    Organization = "InPoint 核心管理中心",
                    PlanType = "Unlimited",
                    MaxGuestsPerEvent = 99999,
                    MaxEvents = -1,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    Notes = "預設系統管理員"
                });
            }

            if (!db.Users.Any(u => u.Username == "single_demo"))
            {
                db.Users.Add(new User
                {
                    UserId = "user_single_demo",
                    Username = "single_demo",
                    PasswordHash = InMemoryEventService.HashPassword("123456"),
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
                });
            }

            if (!db.Users.Any(u => u.Username == "annual_demo"))
            {
                db.Users.Add(new User
                {
                    UserId = "user_annual_demo",
                    Username = "annual_demo",
                    PasswordHash = InMemoryEventService.HashPassword("123456"),
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
                });
            }

            db.SaveChanges();

            if (!db.Events.Any())
            {
                var targetEventId = "event_20260917_084526";
                db.Events.Add(new Event
                {
                    EventId = targetEventId,
                    EventName = "月烤月嗨",
                    EventDate = new DateTime(2026, 9, 17, 9, 0, 0, DateTimeKind.Utc),
                    Location = "後山停車場",
                    Description = "2026 秀傳中秋同樂烤肉聯歡大會",
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    OwnerUsername = "single_demo"
                });
                db.SaveChanges();

                if (!db.Guests.Any(g => g.EventId == targetEventId))
                {
                    db.Guests.AddRange(new[]
                    {
                        new Guest { EventId = targetEventId, GuestId = "00601441", Name = "黃院長", Organization = "秀傳紀念醫院", Title = "院長", RankWeight = 1, TableNo = "VIP-1 主桌", IsCheckedIn = true, CheckedInAt = DateTime.UtcNow.AddMinutes(-35), CheckedInBy = "櫃檯報到處", QrCodeHash = "SC-2026-00601441", Phone = "0922-111-222", Notes = "大會主席" },
                        new Guest { EventId = targetEventId, GuestId = "00601442", Name = "張副院長", Organization = "彰濱秀傳紀念醫院", Title = "副院長", RankWeight = 2, TableNo = "VIP-2 貴賓席", IsCheckedIn = true, CheckedInAt = DateTime.UtcNow.AddMinutes(-25), CheckedInBy = "櫃檯報到處", QrCodeHash = "SC-2026-00601442", Phone = "0988-999-000", Notes = "座談引言人" },
                        new Guest { EventId = targetEventId, GuestId = "00601443", Name = "李議員", Organization = "彰化縣議會", Title = "議員", RankWeight = 2, TableNo = "VIP-2 貴賓席", IsCheckedIn = true, CheckedInAt = DateTime.UtcNow.AddMinutes(-20), CheckedInBy = "櫃檯報到處", QrCodeHash = "SC-2026-00601443", Phone = "0933-555-777", Notes = "特邀指導貴賓" },
                        new Guest { EventId = targetEventId, GuestId = "00601444", Name = "陳主任", Organization = "心血管醫學部", Title = "主任", RankWeight = 3, TableNo = "第 3 組 (12桌)", IsCheckedIn = true, CheckedInAt = DateTime.UtcNow.AddMinutes(-15), CheckedInBy = "櫃檯報到處", QrCodeHash = "SC-2026-00601444", Phone = "0955-667-788", Notes = "專題座談代表" },
                        new Guest { EventId = targetEventId, GuestId = "00601445", Name = "林組長", Organization = "資訊科技處", Title = "組長", RankWeight = 3, TableNo = "第 3 組 (12桌)", IsCheckedIn = false, CheckedInAt = null, CheckedInBy = null, QrCodeHash = "SC-2026-00601445", Phone = "0966-778-899", Notes = "系統維運代表" },
                        new Guest { EventId = targetEventId, GuestId = "00601446", Name = "趙管理師", Organization = "品質管理中心", Title = "資深管理師", RankWeight = 4, TableNo = "第 5 組 (15桌)", IsCheckedIn = true, CheckedInAt = DateTime.UtcNow.AddMinutes(-10), CheckedInBy = "櫃檯報到處", QrCodeHash = "SC-2026-00601446", Phone = "0977-889-900", Notes = "同仁代表" },
                        new Guest { EventId = targetEventId, GuestId = "00601447", Name = "孫專員", Organization = "醫療企劃部", Title = "專員", RankWeight = 4, TableNo = "第 5 組 (15桌)", IsCheckedIn = true, CheckedInAt = DateTime.UtcNow.AddMinutes(-8), CheckedInBy = "櫃檯報到處", QrCodeHash = "SC-2026-00601447", Phone = "0912-333-444", Notes = "企劃同仁" },
                        new Guest { EventId = targetEventId, GuestId = "00601448", Name = "郭工程師", Organization = "醫工部", Title = "工程師", RankWeight = 4, TableNo = "第 6 組 (18桌)", IsCheckedIn = false, CheckedInAt = null, CheckedInBy = null, QrCodeHash = "SC-2026-00601448", Phone = "0922-444-555", Notes = "醫工同仁" }
                    });
                    db.SaveChanges();
                }
            }
            Console.WriteLine("[PostgreSQL DB] Tables and Seed data initialized successfully.");
        }
        else
        {
            // Ensure checkInUsers table and OwnerUsername column exist in SQL Server
            using var conn = new SqlConnection(activeConnStr);
            conn.Open();

            var ddlSql = @"
            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'checkInUsers')
            BEGIN
                CREATE TABLE [checkInUsers] (
                    [UserId] NVARCHAR(100) NOT NULL PRIMARY KEY,
                    [Username] NVARCHAR(100) NOT NULL,
                    [PasswordHash] NVARCHAR(255) NOT NULL,
                    [Role] NVARCHAR(50) NOT NULL,
                    [DisplayName] NVARCHAR(100) NULL,
                    [Organization] NVARCHAR(200) NULL,
                    [PlanType] NVARCHAR(50) NULL,
                    [ExpireAt] DATETIME2 NULL,
                    [MaxGuestsPerEvent] INT NOT NULL DEFAULT 500,
                    [MaxEvents] INT NOT NULL DEFAULT 1,
                    [IsActive] BIT NOT NULL DEFAULT 1,
                    [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                    [Notes] NVARCHAR(1000) NULL
                );
                CREATE UNIQUE INDEX [IX_checkInUsers_Username] ON [checkInUsers]([Username]);
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('checkInEvents') AND name = 'OwnerUsername')
            BEGIN
                ALTER TABLE [checkInEvents] ADD [OwnerUsername] NVARCHAR(100) NULL;
            END

            IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('checkInEvents') AND name = 'RankRules')
            BEGIN
                ALTER TABLE [checkInEvents] ADD [RankRules] NVARCHAR(MAX) NULL;
            END
            ";

            using var cmd = new SqlCommand(ddlSql, conn);
            cmd.ExecuteNonQuery();

            // Seed default admin and demo members in SQL if missing
            var seedUsersSql = @"
            IF NOT EXISTS (SELECT 1 FROM [checkInUsers] WHERE [Username] = 'admin')
            BEGIN
                INSERT INTO [checkInUsers] ([UserId], [Username], [PasswordHash], [Role], [DisplayName], [Organization], [PlanType], [ExpireAt], [MaxGuestsPerEvent], [MaxEvents], [IsActive], [CreatedAt], [Notes])
                VALUES ('user_admin', 'admin', @AdminPass, 'Admin', N'系統最高管理員', N'InPoint 核心管理中心', 'Unlimited', NULL, 99999, -1, 1, GETUTCDATE(), N'預設系統管理員');
            END

            IF NOT EXISTS (SELECT 1 FROM [checkInUsers] WHERE [Username] = 'single_demo')
            BEGIN
                INSERT INTO [checkInUsers] ([UserId], [Username], [PasswordHash], [Role], [DisplayName], [Organization], [PlanType], [ExpireAt], [MaxGuestsPerEvent], [MaxEvents], [IsActive], [CreatedAt], [Notes])
                VALUES ('user_single_demo', 'single_demo', @DemoPass, 'Member', N'陳專員 (單場活動試用)', N'前瞻生醫研發中心', 'SingleEvent', DATEADD(day, 7, GETUTCDATE()), 500, 1, 1, GETUTCDATE(), N'單場活動 7 天授權體驗帳號');
            END

            IF NOT EXISTS (SELECT 1 FROM [checkInUsers] WHERE [Username] = 'annual_demo')
            BEGIN
                INSERT INTO [checkInUsers] ([UserId], [Username], [PasswordHash], [Role], [DisplayName], [Organization], [PlanType], [ExpireAt], [MaxGuestsPerEvent], [MaxEvents], [IsActive], [CreatedAt], [Notes])
                VALUES ('user_annual_demo', 'annual_demo', @DemoPass, 'Member', N'林主任 (機構年度專案)', N'秀傳醫療體系 - 營運管理部', 'AnnualOrg', DATEADD(year, 1, GETUTCDATE()), 1500, -1, 1, GETUTCDATE(), N'機構年度方案完整功能帳號');
            END
            ";
            using var seedCmd = new SqlCommand(seedUsersSql, conn);
            seedCmd.Parameters.AddWithValue("@AdminPass", InMemoryEventService.HashPassword("ZiEiHrpPq@"));
            seedCmd.Parameters.AddWithValue("@DemoPass", InMemoryEventService.HashPassword("123456"));
            seedCmd.ExecuteNonQuery();

            // Seed demo event and guests in SQL if missing or empty
            var seedGuestsSql = @"
            IF NOT EXISTS (SELECT 1 FROM [checkInEvents])
            BEGIN
                INSERT INTO [checkInEvents] ([EventId], [EventName], [EventDate], [Location], [Description], [IsActive], [CreatedAt], [OwnerUsername])
                VALUES ('event_20260917_084526', N'月烤月嗨', '2026-09-17 09:00:00', N'後山停車場', N'2026 秀傳中秋同樂烤肉聯歡大會', 1, GETUTCDATE(), 'single_demo');
            END

            DECLARE @TargetEventId NVARCHAR(100);
            SELECT TOP 1 @TargetEventId = [EventId] FROM [checkInEvents] ORDER BY [CreatedAt] ASC;

            IF @TargetEventId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [checkInGuests] WHERE [EventId] = @TargetEventId)
            BEGIN
                -- VIP 1 級長官 (已到場 1 位)
                INSERT INTO [checkInGuests] ([EventId], [GuestId], [Name], [Organization], [Title], [RankWeight], [TableNo], [IsCheckedIn], [CheckedInAt], [CheckedInBy], [QrCodeHash], [Phone], [Notes])
                VALUES (@TargetEventId, '00601441', N'黃院長', N'秀傳紀念醫院', N'院長', 1, N'VIP-1 主桌', 1, DATEADD(minute, -35, GETUTCDATE()), N'櫃檯報到處', 'SC-2026-00601441', '0922-111-222', N'大會主席');

                -- VIP 2 級長官 (已到場 2 位)
                INSERT INTO [checkInGuests] ([EventId], [GuestId], [Name], [Organization], [Title], [RankWeight], [TableNo], [IsCheckedIn], [CheckedInAt], [CheckedInBy], [QrCodeHash], [Phone], [Notes])
                VALUES (@TargetEventId, '00601442', N'張副院長', N'彰濱秀傳紀念醫院', N'副院長', 2, N'VIP-2 貴賓席', 1, DATEADD(minute, -25, GETUTCDATE()), N'櫃檯報到處', 'SC-2026-00601442', '0988-999-000', N'座談引言人');

                INSERT INTO [checkInGuests] ([EventId], [GuestId], [Name], [Organization], [Title], [RankWeight], [TableNo], [IsCheckedIn], [CheckedInAt], [CheckedInBy], [QrCodeHash], [Phone], [Notes])
                VALUES (@TargetEventId, '00601443', N'李議員', N'彰化縣議會', N'議員', 2, N'VIP-2 貴賓席', 1, DATEADD(minute, -20, GETUTCDATE()), N'櫃檯報到處', 'SC-2026-00601443', '0933-555-777', N'特邀指導貴賓');

                -- VIP 3 級長官 (已到場 1 位)
                INSERT INTO [checkInGuests] ([EventId], [GuestId], [Name], [Organization], [Title], [RankWeight], [TableNo], [IsCheckedIn], [CheckedInAt], [CheckedInBy], [QrCodeHash], [Phone], [Notes])
                VALUES (@TargetEventId, '00601444', N'陳主任', N'心血管醫學部', N'主任', 3, N'第 3 組 (12桌)', 1, DATEADD(minute, -15, GETUTCDATE()), N'櫃檯報到處', 'SC-2026-00601444', '0955-667-788', N'專題座談代表');

                -- 尚未抵達之貴賓長官與一般同仁
                INSERT INTO [checkInGuests] ([EventId], [GuestId], [Name], [Organization], [Title], [RankWeight], [TableNo], [IsCheckedIn], [CheckedInAt], [CheckedInBy], [QrCodeHash], [Phone], [Notes])
                VALUES 
                (@TargetEventId, '00601445', N'林組長', N'資訊科技處', N'組長', 3, N'第 3 組 (12桌)', 0, NULL, NULL, 'SC-2026-00601445', '0966-778-899', N'系統維運代表'),
                (@TargetEventId, '00601446', N'趙管理師', N'品質管理中心', N'資深管理師', 4, N'第 5 組 (15桌)', 1, DATEADD(minute, -10, GETUTCDATE()), N'櫃檯報到處', 'SC-2026-00601446', '0977-889-900', N'同仁代表'),
                (@TargetEventId, '00601447', N'孫專員', N'醫療企劃部', N'專員', 4, N'第 5 組 (15桌)', 1, DATEADD(minute, -8, GETUTCDATE()), N'櫃檯報到處', 'SC-2026-00601447', '0912-333-444', N'企劃同仁'),
                (@TargetEventId, '00601448', N'郭工程師', N'醫工部', N'工程師', 4, N'第 6 組 (18桌)', 0, NULL, NULL, 'SC-2026-00601448', '0922-444-555', N'醫工同仁');
            END
            ";
            using var seedGuestsCmd = new SqlCommand(seedGuestsSql, conn);
            seedGuestsCmd.ExecuteNonQuery();

            Console.WriteLine("[SQL Server DB] Database tables, demo accounts, and VIP guest lists verified successfully.");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"SQL Database Migration warning: {ex.Message}");
    }
}

static string ConvertPostgresUrlToConnectionString(string url)
{
    if (url.StartsWith("postgres://") || url.StartsWith("postgresql://"))
    {
        try
        {
            var uri = new Uri(url);
            var userInfo = uri.UserInfo.Split(':');
            var username = userInfo.Length > 0 ? Uri.UnescapeDataString(userInfo[0]) : "";
            var password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
            var db = uri.AbsolutePath.TrimStart('/');
            var host = uri.Host;
            var port = uri.Port > 0 ? uri.Port : 5432;

            return $"Host={host};Port={port};Database={db};Username={username};Password={password};";
        }
        catch
        {
            return url;
        }
    }
    return url;
}

static string ResolveWorkingConnectionString(string? rawConnStr)
{
    if (string.IsNullOrWhiteSpace(rawConnStr) || rawConnStr.Contains("YOUR_SERVER_NAME"))
        return string.Empty;

    if (rawConnStr.StartsWith("postgres://") || rawConnStr.StartsWith("postgresql://") || rawConnStr.Contains("Host="))
        return rawConnStr;

    var serverCandidates = new List<string>();
    var match = System.Text.RegularExpressions.Regex.Match(rawConnStr, @"Server=([^;]+)", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
    if (match.Success)
    {
        var cfg = match.Groups[1].Value.Trim();
        if (!string.IsNullOrWhiteSpace(cfg)) serverCandidates.Add(cfg);
    }

    if (!serverCandidates.Contains("210.61.91.243")) serverCandidates.Add("210.61.91.243");
    if (!serverCandidates.Contains("ntsql2")) serverCandidates.Add("ntsql2");
    if (!serverCandidates.Contains("ntsql2.cshosp.local")) serverCandidates.Add("ntsql2.cshosp.local");
    if (!serverCandidates.Contains("127.0.0.1")) serverCandidates.Add("127.0.0.1");

    foreach (var s in serverCandidates)
    {
        try
        {
            var testStr = System.Text.RegularExpressions.Regex.Replace(
                rawConnStr, 
                @"Server=[^;]+", 
                $"Server={s}", 
                System.Text.RegularExpressions.RegexOptions.IgnoreCase);

            var sqlBuilder = new SqlConnectionStringBuilder(testStr)
            {
                ConnectTimeout = 3
            };

            using var conn = new SqlConnection(sqlBuilder.ConnectionString);
            conn.Open();
            Console.WriteLine($"[SQL DB] Successfully connected using Server={s}");
            return sqlBuilder.ConnectionString;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[SQL DB] Candidate Server={s} failed: {ex.Message}");
        }
    }

    return rawConnStr;
}

app.UseCors("AllowAll");
app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        ctx.Context.Response.Headers.Append("Cache-Control", "no-cache, no-store, must-revalidate");
        ctx.Context.Response.Headers.Append("Pragma", "no-cache");
        ctx.Context.Response.Headers.Append("Expires", "0");
    }
});

// SignalR Hub
app.MapHub<CheckInHub>("/hub/checkin");

// --- In-Memory Auth Session Management ---
var activeSessions = new ConcurrentDictionary<string, UserSession>();

const string REQUIRED_ADMIN_PASS = "ZiEiHrpPq@";

UserSession? GetSessionFromContext(HttpContext ctx)
{
    string? token = null;
    if (ctx.Request.Headers.TryGetValue("Authorization", out var authHeader))
    {
        var val = authHeader.ToString().Trim();
        if (val.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            token = val[7..].Trim();
        }
        else
        {
            token = val;
        }
    }
    if (string.IsNullOrWhiteSpace(token) && ctx.Request.Headers.TryGetValue("X-Auth-Token", out var xToken))
    {
        token = xToken.ToString().Trim();
    }
    if (string.IsNullOrWhiteSpace(token) && ctx.Request.Query.TryGetValue("token", out var qToken))
    {
        token = qToken.ToString().Trim();
    }

    if (!string.IsNullOrWhiteSpace(token))
    {
        if (activeSessions.TryGetValue(token, out var session))
        {
            return session;
        }

        // 伺服器重啟/重新部署後的無狀態 Session 自動復原機制
        if (token.StartsWith("adm_") || token.StartsWith("inpoint_adm_"))
        {
            var adminSession = new UserSession("admin", "admin", "Admin", "系統最高管理員", "InPoint 核心管理中心", "Unlimited", null, 99999, -1, DateTime.UtcNow);
            activeSessions[token] = adminSession;
            return adminSession;
        }

        string? targetUsername = null;
        if (ctx.Request.Headers.TryGetValue("X-Username", out var hUser))
        {
            targetUsername = hUser.ToString().Trim();
        }
        else if (token.StartsWith("usr_"))
        {
            var parts = token.Split('_');
            if (parts.Length >= 2 && !string.IsNullOrWhiteSpace(parts[1]))
            {
                targetUsername = parts[1];
            }
        }
        else if (token.StartsWith("inpoint_mem_"))
        {
            var parts = token.Split('_');
            if (parts.Length >= 3 && !string.IsNullOrWhiteSpace(parts[2]))
            {
                targetUsername = parts[2];
            }
        }

        if (!string.IsNullOrWhiteSpace(targetUsername))
        {
            try
            {
                using var scope = app.Services.CreateScope();
                var eventService = scope.ServiceProvider.GetRequiredService<IEventService>();
                var u = eventService.GetUserByUsernameAsync(targetUsername).GetAwaiter().GetResult();
                if (u != null && u.IsActive)
                {
                    var restoredSession = new UserSession(
                        u.UserId,
                        u.Username,
                        u.Role,
                        u.DisplayName,
                        u.Organization,
                        u.PlanType,
                        u.ExpireAt,
                        u.MaxGuestsPerEvent,
                        u.MaxEvents,
                        DateTime.UtcNow
                    );
                    activeSessions[token] = restoredSession;
                    return restoredSession;
                }
            }
            catch {}
        }
    }

    return null;
}

bool CheckAdminAuth(HttpContext ctx)
{
    var session = GetSessionFromContext(ctx);
    if (session != null && session.Role == "Admin") return true;

    // Direct password fallbacks
    if (ctx.Request.Headers.TryGetValue("X-Admin-Password", out var hPass) && hPass.ToString().Trim() == REQUIRED_ADMIN_PASS)
        return true;
    if (ctx.Request.Query.TryGetValue("password", out var qPass) && qPass.ToString().Trim() == REQUIRED_ADMIN_PASS)
        return true;

    return false;
}

// --- 1. Authentication APIs ---

app.MapPost("/api/auth/login", async (LoginRequest req, IEventService service) =>
{
    var username = req.Username?.Trim() ?? "";
    var password = req.Password?.Trim() ?? "";
    var role = string.IsNullOrWhiteSpace(req.Role) ? "Member" : req.Role;

    if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
    {
        return Results.BadRequest(new LoginResponse
        {
            Success = false,
            Message = "請輸入完整帳號與密碼"
        });
    }

    // A. Administrator Login
    if (role.Equals("Admin", StringComparison.OrdinalIgnoreCase) || username.Equals("admin", StringComparison.OrdinalIgnoreCase))
    {
        bool isAdminValid = (password == REQUIRED_ADMIN_PASS);
        var adminUser = await service.GetUserByUsernameAsync("admin");

        if (!isAdminValid && adminUser != null)
        {
            isAdminValid = InMemoryEventService.VerifyPassword(password, adminUser.PasswordHash);
        }

        if (!isAdminValid)
        {
            return Results.Unauthorized();
        }

        var token = "inpoint_adm_" + Guid.NewGuid().ToString("N");
        var session = new UserSession(
            adminUser?.UserId ?? "user_admin",
            "admin",
            "Admin",
            adminUser?.DisplayName ?? "系統最高管理員",
            adminUser?.Organization ?? "InPoint 核心管理中心",
            "Unlimited",
            null,
            99999,
            -1,
            DateTime.UtcNow
        );
        activeSessions[token] = session;

        return Results.Ok(new LoginResponse
        {
            Success = true,
            Token = token,
            Username = "admin",
            Role = "Admin",
            DisplayName = session.DisplayName,
            Organization = session.Organization,
            PlanType = "Unlimited",
            ExpireAt = null,
            MaxGuestsPerEvent = 99999,
            MaxEvents = -1,
            IsExpired = false,
            RemainingDays = 9999,
            Message = "🎉 管理者驗證成功，歡迎登入 InPoint 管理中心！"
        });
    }

    // B. Member Login (一般會員)
    var user = await service.GetUserByUsernameAsync(username);

    // Auto-provision demo accounts if missing in database
    if (user == null && password == "123456")
    {
        if (username.Equals("single_demo", StringComparison.OrdinalIgnoreCase))
        {
            user = new User
            {
                UserId = "user_single_demo",
                Username = "single_demo",
                PasswordHash = InMemoryEventService.HashPassword("123456"),
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
            await service.CreateUserAsync(user);
        }
        else if (username.Equals("annual_demo", StringComparison.OrdinalIgnoreCase))
        {
            user = new User
            {
                UserId = "user_annual_demo",
                Username = "annual_demo",
                PasswordHash = InMemoryEventService.HashPassword("123456"),
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
            await service.CreateUserAsync(user);
        }
    }

    if (user == null || !InMemoryEventService.VerifyPassword(password, user.PasswordHash))
    {
        return Results.BadRequest(new LoginResponse
        {
            Success = false,
            Message = "⚠️ 會員帳號或密碼錯誤，請重新確認！"
        });
    }

    if (!user.IsActive)
    {
        return Results.BadRequest(new LoginResponse
        {
            Success = false,
            Message = "⚠️ 此會員帳號已被停用，請洽詢系統管理員！"
        });
    }

    bool isExpired = user.ExpireAt.HasValue && user.ExpireAt.Value < DateTime.UtcNow;
    int remainingDays = user.ExpireAt.HasValue ? (int)Math.Max(0, (user.ExpireAt.Value - DateTime.UtcNow).TotalDays) : 9999;

    var memToken = $"inpoint_mem_{user.Username}_{Guid.NewGuid():N}";
    var memSession = new UserSession(
        user.UserId,
        user.Username,
        "Member",
        user.DisplayName,
        user.Organization,
        user.PlanType,
        user.ExpireAt,
        user.MaxGuestsPerEvent,
        user.MaxEvents,
        DateTime.UtcNow
    );
    activeSessions[memToken] = memSession;

    string welcomeMsg = isExpired
        ? $"⚠️ 您的方案已於 {user.ExpireAt:yyyy-MM-dd} 到期，目前為唯讀狀態，請聯繫管理員續約！"
        : $"🎉 登入成功！歡迎【{user.Organization}】{user.DisplayName}（方案有效天數剩餘 {remainingDays} 天）";

    return Results.Ok(new LoginResponse
    {
        Success = true,
        Token = memToken,
        Username = user.Username,
        Role = "Member",
        DisplayName = user.DisplayName,
        Organization = user.Organization,
        PlanType = user.PlanType,
        ExpireAt = user.ExpireAt,
        MaxGuestsPerEvent = user.MaxGuestsPerEvent,
        MaxEvents = user.MaxEvents,
        IsExpired = isExpired,
        RemainingDays = remainingDays,
        Message = welcomeMsg
    });
});

app.MapGet("/api/auth/me", (HttpContext ctx) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null)
    {
        return Results.Unauthorized();
    }

    bool isExpired = session.ExpireAt.HasValue && session.ExpireAt.Value < DateTime.UtcNow;
    int remainingDays = session.ExpireAt.HasValue ? (int)Math.Max(0, (session.ExpireAt.Value - DateTime.UtcNow).TotalDays) : 9999;

    return Results.Ok(new
    {
        userId = session.UserId,
        username = session.Username,
        role = session.Role,
        displayName = session.DisplayName,
        organization = session.Organization,
        planType = session.PlanType,
        expireAt = session.ExpireAt,
        maxGuestsPerEvent = session.MaxGuestsPerEvent,
        maxEvents = session.MaxEvents,
        isExpired,
        remainingDays
    });
});

app.MapPost("/api/auth/logout", (HttpContext ctx) =>
{
    string? token = null;
    if (ctx.Request.Headers.TryGetValue("Authorization", out var authHeader))
    {
        var val = authHeader.ToString().Trim();
        token = val.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ? val[7..].Trim() : val;
    }
    if (!string.IsNullOrWhiteSpace(token))
    {
        activeSessions.TryRemove(token, out _);
    }
    return Results.Ok(new { success = true, message = "已安全登出" });
});

// --- 2. Member Management APIs (Admin Only) ---

app.MapGet("/api/members", async (HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var members = await service.GetMembersAsync();
    return Results.Ok(members);
});

app.MapPost("/api/members", async (CreateMemberRequest req, HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    if (string.IsNullOrWhiteSpace(req.Username) || string.IsNullOrWhiteSpace(req.Password))
    {
        return Results.BadRequest(new { success = false, message = "請填寫會員帳號與登入密碼" });
    }

    var existing = await service.GetUserByUsernameAsync(req.Username.Trim());
    if (existing != null)
    {
        return Results.BadRequest(new { success = false, message = $"帳號「{req.Username}」已存在，請使用其他帳號！" });
    }

    bool isAnnual = req.PlanType == "AnnualOrg";
    string planType = isAnnual ? "AnnualOrg" : (string.IsNullOrWhiteSpace(req.PlanType) ? "SingleEvent_Light" : req.PlanType);
    int defaultDays = isAnnual ? 365 : 7;
    int defaultMaxGuests = planType switch
    {
        "SingleEvent_Light" => 100,
        "SingleEvent_Standard" => 300,
        "SingleEvent_Flagship" => 600,
        "AnnualOrg" => 1500,
        _ => 100
    };
    int maxGuests = req.MaxGuestsPerEvent ?? defaultMaxGuests;
    int maxEvents = isAnnual ? -1 : 1;

    DateTime expireAt;
    if (req.ExpireAt.HasValue)
    {
        expireAt = req.ExpireAt.Value;
    }
    else if (req.ExpireDays.HasValue && req.ExpireDays.Value > 0)
    {
        expireAt = DateTime.UtcNow.AddDays(req.ExpireDays.Value);
    }
    else
    {
        expireAt = DateTime.UtcNow.AddDays(defaultDays);
    }

    var newUser = new User
    {
        UserId = "user_" + Guid.NewGuid().ToString("N")[..12],
        Username = req.Username.Trim(),
        PasswordHash = InMemoryEventService.HashPassword(req.Password.Trim()),
        Role = "Member",
        DisplayName = string.IsNullOrWhiteSpace(req.DisplayName) ? req.Username.Trim() : req.DisplayName.Trim(),
        Organization = string.IsNullOrWhiteSpace(req.Organization) ? "受邀合作單位" : req.Organization.Trim(),
        PlanType = planType,
        ExpireAt = expireAt,
        MaxGuestsPerEvent = maxGuests,
        MaxEvents = maxEvents,
        IsActive = true,
        CreatedAt = DateTime.UtcNow,
        Notes = req.Notes
    };

    var created = await service.CreateUserAsync(newUser);
    return Results.Created($"/api/members/{created.UserId}", created);
});

app.MapPut("/api/members/{userId}", async (string userId, UpdateMemberRequest req, HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var user = await service.GetUserByIdAsync(userId);
    if (user == null)
    {
        return Results.NotFound(new { success = false, message = "找不到該會員資料" });
    }

    user.DisplayName = string.IsNullOrWhiteSpace(req.DisplayName) ? user.DisplayName : req.DisplayName.Trim();
    user.Organization = string.IsNullOrWhiteSpace(req.Organization) ? user.Organization : req.Organization.Trim();
    user.PlanType = req.PlanType ?? user.PlanType;
    user.IsActive = req.IsActive;
    user.Notes = req.Notes;

    if (req.ExpireAt.HasValue)
    {
        user.ExpireAt = req.ExpireAt.Value;
    }
    if (req.MaxGuestsPerEvent.HasValue && req.MaxGuestsPerEvent.Value > 0)
    {
        user.MaxGuestsPerEvent = req.MaxGuestsPerEvent.Value;
        user.MaxEvents = (user.PlanType == "AnnualOrg") ? -1 : 1;
    }
    else if (req.PlanType != null && (req.PlanType.StartsWith("SingleEvent") || req.PlanType != "AnnualOrg"))
    {
        user.MaxGuestsPerEvent = req.PlanType switch
        {
            "SingleEvent_Light" => 100,
            "SingleEvent_Standard" => 300,
            "SingleEvent_Flagship" => 600,
            _ => 100
        };
        user.MaxEvents = 1;
    }
    else if (req.PlanType == "AnnualOrg")
    {
        user.MaxGuestsPerEvent = 1500;
        user.MaxEvents = -1;
    }

    if (!string.IsNullOrWhiteSpace(req.Password))
    {
        user.PasswordHash = InMemoryEventService.HashPassword(req.Password.Trim());
    }

    await service.UpdateUserAsync(user);
    return Results.Ok(new { success = true, user });
});

app.MapPost("/api/members/{userId}/toggle-status", async (string userId, HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var success = await service.ToggleUserStatusAsync(userId);
    return success ? Results.Ok(new { success = true, userId }) : Results.NotFound(new { message = "會員不存在" });
});

app.MapPost("/api/members/{userId}/reset-password", async (string userId, ResetMemberPasswordRequest req, HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    if (string.IsNullOrWhiteSpace(req.NewPassword))
    {
        return Results.BadRequest(new { success = false, message = "請輸入新密碼" });
    }

    var success = await service.ResetUserPasswordAsync(userId, req.NewPassword.Trim());
    return success ? Results.Ok(new { success = true, message = "密碼已重設" }) : Results.NotFound(new { message = "會員不存在" });
});

app.MapDelete("/api/members/{userId}", async (string userId, HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var success = await service.DeleteUserAsync(userId);
    return success ? Results.Ok(new { success = true, userId }) : Results.BadRequest(new { message = "無法刪除管理者或會員不存在" });
});

app.MapGet("/api/members/{userId}/events", async (string userId, HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var user = await service.GetUserByIdAsync(userId);
    if (user == null)
    {
        return Results.NotFound(new { success = false, message = "找不到該會員資料" });
    }

    var allEvents = await service.GetEventsAsync(null, "Admin");
    var memberEvents = allEvents
        .Where(e => string.Equals(e.OwnerUsername, user.Username, StringComparison.OrdinalIgnoreCase))
        .OrderByDescending(e => e.IsActive)
        .ThenByDescending(e => e.EventDate)
        .ToList();

    var result = new List<object>();
    foreach (var ev in memberEvents)
    {
        var stats = await service.GetEventStatsAsync(ev.EventId);
        result.Add(new
        {
            ev.EventId,
            ev.EventName,
            ev.EventDate,
            ev.Location,
            ev.Description,
            ev.IsActive,
            ev.CreatedAt,
            ev.OwnerUsername,
            totalGuests = stats.TotalGuests,
            checkedInCount = stats.CheckedInCount,
            pendingCount = stats.PendingCount,
            attendanceRate = stats.AttendanceRate,
            vipTotal = stats.VipTotal,
            vipCheckedIn = stats.VipCheckedIn
        });
    }

    return Results.Ok(new
    {
        user = new
        {
            user.UserId,
            user.Username,
            user.DisplayName,
            user.Organization,
            user.PlanType,
            user.ExpireAt,
            user.MaxGuestsPerEvent,
            user.MaxEvents,
            user.IsActive
        },
        events = result
    });
});

// --- 3. Events API with Role & Plan Enforcement ---

app.MapGet("/api/events", async (HttpContext ctx, IEventService service) =>
{
    var session = GetSessionFromContext(ctx);
    
    // If not logged in, reject access to enforce privacy
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var role = session?.Role ?? "Admin";
    var username = session?.Username ?? "admin";
    var events = await service.GetEventsAsync(username, role);
    return Results.Ok(events);
});

// Public Event Info for Kiosk / Mobile Check-in Display
app.MapGet("/api/events/public-list", async (IEventService service) =>
{
    var events = await service.GetEventsAsync(null, "Admin");
    var safeList = events.Where(e => e.IsActive).Select(e => new
    {
        e.EventId,
        e.EventName,
        e.EventDate,
        e.Location,
        e.Description,
        e.IsActive
    });
    return Results.Ok(safeList);
});

app.MapGet("/api/events/{id}/public-info", async (string id, IEventService service) =>
{
    var ev = await service.GetEventByIdAsync(id);
    if (ev == null) return Results.NotFound(new { message = "活動不存在" });
    return Results.Ok(new
    {
        ev.EventId,
        ev.EventName,
        ev.EventDate,
        ev.Location,
        ev.Description,
        ev.IsActive
    });
});

// Kiosk Feed & Recent Arrivals API (Real-time Billboard Feed)
Func<string, IEventService, Task<IResult>> handleKioskFeed = async (id, service) =>
{
    var ev = await service.GetEventByIdAsync(id);
    var stats = await service.GetEventStatsAsync(id);
    var allGuests = await service.GetGuestsAsync(id);
    var recentArrivals = allGuests
        .Where(g => g.IsCheckedIn)
        .OrderByDescending(g => g.CheckedInAt ?? DateTime.MinValue)
        .Take(30)
        .Select(g => new
        {
            g.GuestId,
            g.Name,
            g.Organization,
            g.Title,
            g.TableNo,
            g.RankWeight,
            g.IsCheckedIn,
            g.CheckedInAt,
            g.CheckedInBy,
            vipCategory = (g.Title.Contains("照專") && !g.Title.Contains("督導")) ? "一般貴賓/同仁" :
                          g.RankWeight == 1 ? "VIP-1 院長/局長" :
                          g.RankWeight == 2 ? "VIP-2 副院長/民代/督導" :
                          g.RankWeight == 3 ? "科部主任/教授" : "一般貴賓/同仁"
        })
        .ToList();

    return Results.Ok(new
    {
        eventId = id,
        eventName = ev?.EventName ?? "智慧活動報到",
        eventDate = ev?.EventDate ?? DateTime.UtcNow,
        location = ev?.Location ?? "大會國際會議廳",
        stats,
        recentArrivals
    });
};

app.MapGet("/api/events/{id}/kiosk-feed", (string id, IEventService service) => handleKioskFeed(id, service));
app.MapGet("/api/events/{id}/recent-arrivals", (string id, IEventService service) => handleKioskFeed(id, service));

app.MapGet("/api/events/{id}", async (string id, HttpContext ctx, IEventService service) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        var evPublic = await service.GetEventByIdAsync(id);
        if (evPublic != null) return Results.Ok(evPublic);
        return Results.Unauthorized();
    }

    var ev = await service.GetEventByIdAsync(id);
    return ev != null ? Results.Ok(ev) : Results.NotFound(new { message = "活動不存在" });
});

async Task<IResult> HandleCreateEvent(CreateEventRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext)
{
    var session = GetSessionFromContext(ctx);
    bool isAdmin = CheckAdminAuth(ctx);

    if (session == null && !isAdmin)
    {
        return Results.Unauthorized();
    }

    if (req == null || string.IsNullOrWhiteSpace(req.EventName))
    {
        return Results.BadRequest(new { success = false, message = "請輸入活動名稱" });
    }

    // Plan Limit Validations for Member
    if (!isAdmin && session != null)
    {
        if (session.ExpireAt.HasValue && session.ExpireAt.Value < DateTime.UtcNow)
        {
            return Results.BadRequest(new
            {
                success = false,
                error = "PLAN_EXPIRED",
                message = $"⚠️ 您的會員方案已於 {session.ExpireAt:yyyy-MM-dd} 到期，無法建立新活動，請聯絡管理員續約！"
            });
        }

        if (session.PlanType != "AnnualOrg" && session.PlanType != "Unlimited")
        {
            var currentEventCount = await service.GetUserEventCountAsync(session.Username);
            if (currentEventCount >= 1)
            {
                return Results.BadRequest(new
                {
                    success = false,
                    error = "PLAN_LIMIT_REACHED",
                    message = "⚠️ 您目前的「單場活動方案」僅授權建立 1 場活動。如需舉辦多場活動，請升級為「機構年度方案」以享有無限場次與範本複製功能！"
                });
            }
        }
    }

    var newEvent = new Event
    {
        EventId = string.IsNullOrWhiteSpace(req.EventId) ? $"event_{TaiwanTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid().ToString("N")[..6]}" : req.EventId,
        EventName = req.EventName.Trim(),
        EventDate = req.EventDate != default ? req.EventDate : DateTime.UtcNow,
        Location = string.IsNullOrWhiteSpace(req.Location) ? "大會國際會議廳" : req.Location.Trim(),
        Description = req.Description?.Trim() ?? string.Empty,
        IsActive = req.IsActive,
        CreatedAt = DateTime.UtcNow,
        OwnerUsername = session?.Username ?? "admin"
    };

    var created = await service.CreateEventAsync(newEvent);
    await hubContext.Clients.All.SendAsync("OnEventCreated", created);
    return Results.Created($"/api/events/{created.EventId}", created);
}

app.MapPost("/api/events", HandleCreateEvent);
app.MapPost("/api/events/create", HandleCreateEvent);
app.MapPost("/api/events/add", HandleCreateEvent);
app.MapPost("/api/events/new", HandleCreateEvent);

// Clone Event (範本複製 - Exclusive to AnnualOrg & Admin)
app.MapPost("/api/events/{id}/clone", async (string id, CloneEventRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var session = GetSessionFromContext(ctx);
    bool isAdmin = CheckAdminAuth(ctx);

    if (session == null && !isAdmin)
    {
        return Results.Unauthorized();
    }

    if (!isAdmin && session != null)
    {
        if (session.PlanType != "AnnualOrg" && session.PlanType != "Unlimited")
        {
            return Results.BadRequest(new
            {
                success = false,
                error = "FEATURE_RESTRICTED",
                message = "⚠️ 「範本複製」為【機構年度方案】尊榮專屬功能！請升級為機構年度方案即可享有無限場次建立與一鍵範本複製！"
            });
        }
        if (session.ExpireAt.HasValue && session.ExpireAt.Value < DateTime.UtcNow)
        {
            return Results.BadRequest(new
            {
                success = false,
                error = "PLAN_EXPIRED",
                message = "⚠️ 您的會員方案已過期，無法複製活動！"
            });
        }
    }

    var sourceEv = await service.GetEventByIdAsync(id);
    if (sourceEv == null)
    {
        return Results.NotFound(new { success = false, message = "找不到來源活動場次" });
    }

    var targetOwner = isAdmin
        ? (!string.IsNullOrWhiteSpace(req.OwnerUsername) ? req.OwnerUsername.Trim() : (sourceEv.OwnerUsername ?? "admin"))
        : (session?.Username ?? "admin");

    var cloned = await service.CloneEventAsync(
        id,
        req.NewEventName,
        req.NewEventDate,
        req.Location,
        req.Description,
        req.CopyGuests,
        targetOwner
    );

    await hubContext.Clients.All.SendAsync("OnEventCreated", cloned);
    return Results.Ok(new { success = true, clonedEvent = cloned });
});

async Task<IResult> HandleToggleEventActive(string? id, ToggleEventActiveRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext)
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var eventId = !string.IsNullOrWhiteSpace(id) ? id : req?.EventId;
    if (string.IsNullOrWhiteSpace(eventId) && ctx.Request.Query.TryGetValue("eventId", out var qId))
    {
        eventId = qId.ToString();
    }
    if (string.IsNullOrWhiteSpace(eventId))
    {
        return Results.BadRequest(new { success = false, message = "請指定活動代碼 (eventId)" });
    }

    var success = await service.ArchiveEventAsync(eventId, req?.IsActive);
    if (success)
    {
        var ev = await service.GetEventByIdAsync(eventId);
        await hubContext.Clients.All.SendAsync("OnEventArchived", eventId);
        if (ev != null)
        {
            await hubContext.Clients.All.SendAsync("OnEventUpdated", ev);
        }
        return Results.Ok(new { success = true, eventId, isActive = ev?.IsActive, @event = ev });
    }
    return Results.NotFound(new { success = false, message = "找不到指定的活動場次" });
}

app.MapPost("/api/events/{id}/toggle-active", (string id, ToggleEventActiveRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleToggleEventActive(id, req, ctx, service, hubContext));
app.MapPost("/api/events/{id}/archive", (string id, ToggleEventActiveRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleToggleEventActive(id, req, ctx, service, hubContext));
app.MapPost("/api/events/toggle-active", (ToggleEventActiveRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleToggleEventActive(null, req, ctx, service, hubContext));
app.MapPost("/api/events/toggle-status", (ToggleEventActiveRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleToggleEventActive(null, req, ctx, service, hubContext));
app.MapPost("/api/events/archive", (ToggleEventActiveRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleToggleEventActive(null, req, ctx, service, hubContext));

async Task<IResult> HandleDeleteEvent(string? id, DeleteEventRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext)
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var eventId = !string.IsNullOrWhiteSpace(id) ? id : req?.EventId;
    if (string.IsNullOrWhiteSpace(eventId) && ctx.Request.Query.TryGetValue("eventId", out var qId))
    {
        eventId = qId.ToString();
    }
    eventId ??= string.Empty;

    await service.DeleteEventAsync(eventId);
    await hubContext.Clients.All.SendAsync("OnEventDeleted", eventId);
    return Results.Ok(new { success = true, eventId });
}

app.MapPost("/api/events/delete-event", (DeleteEventRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleDeleteEvent(null, req, ctx, service, hubContext));
app.MapPost("/api/events/remove", (DeleteEventRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleDeleteEvent(null, req, ctx, service, hubContext));
app.MapPost("/api/events/delete", (DeleteEventRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleDeleteEvent(null, req, ctx, service, hubContext));
app.MapPost("/api/events/{id}/remove", (string id, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleDeleteEvent(id, null, ctx, service, hubContext));
app.MapPost("/api/events/{id}/delete", (string id, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleDeleteEvent(id, null, ctx, service, hubContext));
app.MapDelete("/api/events/{id}", (string id, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleDeleteEvent(id, null, ctx, service, hubContext));
app.MapGet("/api/events/{id}/delete", (string id, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => HandleDeleteEvent(id, null, ctx, service, hubContext));

// --- 4. Guests API with Plan Capacity Enforcement ---

app.MapGet("/api/events/{id}/guests", async (string id, HttpContext ctx, IEventService service) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var guests = await service.GetGuestsAsync(id);
    return Results.Ok(guests);
});

app.MapGet("/api/events/{id}/stats", async (string id, HttpContext ctx, IEventService service) =>
{
    var stats = await service.GetEventStatsAsync(id);
    var session = GetSessionFromContext(ctx);
    if (session != null)
    {
        stats.MaxGuestsAllowed = session.MaxGuestsPerEvent;
    }
    return Results.Ok(stats);
});

app.MapGet("/api/guests/lookup/{code}", async (string code, IEventService service) =>
{
    var guest = await service.GetGuestByQrCodeAsync(code);
    return guest != null ? Results.Ok(guest) : Results.NotFound(new { message = "查無此貴賓 QR 碼或代碼" });
});

app.MapPost("/api/events/{id}/guests", async (string id, Guest guest, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    try
    {
        var currentGuests = await service.GetGuestsAsync(id);
        int maxAllowed = session?.MaxGuestsPerEvent ?? 1500;

        if (currentGuests.Count >= maxAllowed)
        {
            return Results.BadRequest(new
            {
                success = false,
                error = "GUEST_LIMIT_EXCEEDED",
                message = $"⚠️ 已達此方案單場人數上限 ({maxAllowed} 人)！無法再新增貴賓。"
            });
        }

        guest.EventId = id;

        // 若使用者自行指定了編號，檢查該活動是否已存在此編號
        if (!string.IsNullOrWhiteSpace(guest.GuestId))
        {
            var exists = currentGuests.Any(g => string.Equals(g.GuestId, guest.GuestId.Trim(), StringComparison.OrdinalIgnoreCase));
            if (exists)
            {
                return Results.BadRequest(new
                {
                    success = false,
                    error = "DUPLICATE_GUEST_ID",
                    message = $"⚠️ 此編號「{guest.GuestId}」在該場活動中已存在，請更換編號或留空自動產生！"
                });
            }
        }

        var added = await service.AddGuestAsync(guest);
        await hubContext.Clients.Group(id).SendAsync("OnGuestAdded", added);
        if (added.IsCheckedIn)
        {
            var stats = await service.GetEventStatsAsync(id);
            await hubContext.Clients.Group(id).SendAsync("OnGuestCheckInChanged", new
            {
                EventId = id,
                Guest = added,
                UpdatedBy = added.CheckedInBy ?? "現場新增報到",
                Timestamp = TaiwanTime.Now,
                Stats = stats
            });
        }
        await hubContext.Clients.All.SendAsync("OnStatsUpdated", await service.GetEventStatsAsync(id));
        return Results.Created($"/api/events/{id}/guests/{added.GuestId}", added);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[AddGuest Error] {ex}");
        return Results.BadRequest(new
        {
            success = false,
            error = "ADD_GUEST_FAILED",
            message = $"新增貴賓失敗：{ex.Message}"
        });
    }
});

app.MapPost("/api/events/{id}/guests/batch", async (string id, List<Guest> guests, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var currentGuests = await service.GetGuestsAsync(id);
    int maxAllowed = session?.MaxGuestsPerEvent ?? 1500;
    int availableSlots = Math.Max(0, maxAllowed - currentGuests.Count);

    if (guests.Count > availableSlots)
    {
        return Results.BadRequest(new
        {
            success = false,
            error = "GUEST_LIMIT_EXCEEDED",
            message = $"⚠️ 欲匯入 {guests.Count} 人，但此方案單場上限為 {maxAllowed} 人（目前已登錄 {currentGuests.Count} 人，僅剩 {availableSlots} 個名額）！"
        });
    }

    var addedList = await service.BatchAddGuestsAsync(id, guests);
    await hubContext.Clients.Group(id).SendAsync("OnGuestsBatchAdded", addedList);
    await hubContext.Clients.All.SendAsync("OnStatsUpdated", await service.GetEventStatsAsync(id));
    return Results.Ok(new { count = addedList.Count, guests = addedList });
});

app.MapPost("/api/events/{id}/guests/clear", async (string id, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var success = await service.ClearAllGuestsAsync(id);
    if (success)
    {
        await hubContext.Clients.Group(id).SendAsync("OnGuestsCleared", id);
        await hubContext.Clients.All.SendAsync("OnStatsUpdated", await service.GetEventStatsAsync(id));
        return Results.Ok(new { success = true, eventId = id });
    }
    return Results.NotFound();
});

app.MapDelete("/api/events/{id}/guests/{gId}", async (string id, string gId, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    await service.DeleteGuestAsync(id, gId);
    await hubContext.Clients.Group(id).SendAsync("OnGuestDeleted", gId);
    await hubContext.Clients.All.SendAsync("OnStatsUpdated", await service.GetEventStatsAsync(id));
    return Results.Ok(new { success = true, guestId = gId });
});

app.MapPost("/api/events/delete-guest", async (DeleteGuestRequest? req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var eventId = req?.EventId ?? (ctx.Request.Query.TryGetValue("eventId", out var qe) ? qe.ToString() : "");
    var guestId = req?.GuestId ?? (ctx.Request.Query.TryGetValue("guestId", out var qg) ? qg.ToString() : "");
    
    await service.DeleteGuestAsync(eventId, guestId);
    await hubContext.Clients.Group(eventId).SendAsync("OnGuestDeleted", guestId);
    await hubContext.Clients.All.SendAsync("OnStatsUpdated", await service.GetEventStatsAsync(eventId));
    return Results.Ok(new { success = true, guestId });
});

// Check-in Toggle
Func<string, string, CheckInToggleRequest, HttpContext, IEventService, IHubContext<CheckInHub>, Task<IResult>> handleCheckInToggle = async (id, gId, req, ctx, service, hubContext) =>
{
    var staff = string.IsNullOrWhiteSpace(req.StaffName) ? "報到處工作人員" : req.StaffName;
    var updated = await service.ToggleCheckInAsync(id, gId, req.IsCheckedIn, staff);
    if (updated != null)
    {
        var stats = await service.GetEventStatsAsync(id);
        await hubContext.Clients.Group(id).SendAsync("OnGuestCheckInChanged", new
        {
            EventId = id,
            Guest = updated,
            UpdatedBy = staff,
            Timestamp = TaiwanTime.Now,
            Stats = stats
        });
        await hubContext.Clients.All.SendAsync("OnStatsUpdated", stats);
        return Results.Ok(updated);
    }
    return Results.NotFound(new { message = "找不到該貴賓" });
};

app.MapPatch("/api/events/{id}/guests/{gId}/checkin", (string id, string gId, CheckInToggleRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => handleCheckInToggle(id, gId, req, ctx, service, hubContext));
app.MapPost("/api/events/{id}/guests/{gId}/checkin", (string id, string gId, CheckInToggleRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) => handleCheckInToggle(id, gId, req, ctx, service, hubContext));

app.MapPost("/api/events/toggle-checkin", async (ToggleCheckInDirectRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var staff = string.IsNullOrWhiteSpace(req.StaffName) ? "報到處工作人員" : req.StaffName;
    var updated = await service.ToggleCheckInAsync(req.EventId, req.GuestId, req.IsCheckedIn, staff);
    if (updated != null)
    {
        var stats = await service.GetEventStatsAsync(req.EventId);
        await hubContext.Clients.Group(req.EventId).SendAsync("OnGuestCheckInChanged", new
        {
            EventId = req.EventId,
            Guest = updated,
            UpdatedBy = staff,
            Timestamp = TaiwanTime.Now,
            Stats = stats
        });
        await hubContext.Clients.All.SendAsync("OnStatsUpdated", stats);
        return Results.Ok(updated);
    }
    return Results.NotFound(new { message = "找不到該貴賓" });
});

// Helper to evaluate rank weight based on title and custom event rank rules
static int CalculateRankWeightByRules(string title, string? rankRulesJson)
{
    title = (title ?? string.Empty).Trim();
    if (string.IsNullOrWhiteSpace(title)) return 4;

    if (!string.IsNullOrWhiteSpace(rankRulesJson))
    {
        try
        {
            using var doc = System.Text.Json.JsonDocument.Parse(rankRulesJson);
            var root = doc.RootElement;
            
            // Check rank 4 excludes
            if (root.TryGetProperty("rank4Keywords", out var r4Arr) && r4Arr.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                foreach (var kw in r4Arr.EnumerateArray())
                {
                    var val = kw.GetString()?.Trim();
                    if (!string.IsNullOrEmpty(val) && title.Contains(val, StringComparison.OrdinalIgnoreCase))
                    {
                        if (!title.Contains("督導", StringComparison.OrdinalIgnoreCase))
                            return 4;
                    }
                }
            }

            // Check rank 1
            if (root.TryGetProperty("rank1Keywords", out var r1Arr) && r1Arr.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                foreach (var kw in r1Arr.EnumerateArray())
                {
                    var val = kw.GetString()?.Trim();
                    if (!string.IsNullOrEmpty(val) && title.Contains(val, StringComparison.OrdinalIgnoreCase))
                        return 1;
                }
            }

            // Check rank 2
            if (root.TryGetProperty("rank2Keywords", out var r2Arr) && r2Arr.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                foreach (var kw in r2Arr.EnumerateArray())
                {
                    var val = kw.GetString()?.Trim();
                    if (!string.IsNullOrEmpty(val) && title.Contains(val, StringComparison.OrdinalIgnoreCase))
                        return 2;
                }
            }

            // Check rank 3
            if (root.TryGetProperty("rank3Keywords", out var r3Arr) && r3Arr.ValueKind == System.Text.Json.JsonValueKind.Array)
            {
                foreach (var kw in r3Arr.EnumerateArray())
                {
                    var val = kw.GetString()?.Trim();
                    if (!string.IsNullOrEmpty(val) && title.Contains(val, StringComparison.OrdinalIgnoreCase))
                        return 3;
                }
            }

            return 4;
        }
        catch
        {
            // fallback to default
        }
    }

    // Default System Rules
    if (title.Contains("照專") && !title.Contains("督導")) return 4;
    if (Regex.IsMatch(title, @"院長|局長|部長|署長|董事長|總裁|副部長|校長|理事長|市長|縣長")) return 1;
    if (Regex.IsMatch(title, @"副院長|副局長|議員|立委|代表|組長|科長|副署長|委員|督導|副市長|副縣長|秘書長")) return 2;
    if (Regex.IsMatch(title, @"主任|教授|醫師|處長|顧問|隊長|副主任|總監|學者|專家|講師|經理|協理")) return 3;
    return 4;
}

// Update Event Custom Rank Rules
app.MapPost("/api/events/{id}/rank-rules", async (string id, UpdateRankRulesRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var ev = await service.GetEventByIdAsync(id);
    if (ev == null)
    {
        return Results.NotFound(new { success = false, message = "找不到該活動場次" });
    }

    ev.RankRules = req.RankRules;
    await service.UpdateEventAsync(ev);

    int recalculatedCount = 0;
    if (req.RecalculateExistingGuests)
    {
        var guests = await service.GetGuestsAsync(id);
        foreach (var g in guests)
        {
            int newRank = CalculateRankWeightByRules(g.Title, ev.RankRules);
            if (g.RankWeight != newRank)
            {
                g.RankWeight = newRank;
                await service.UpdateGuestAsync(g);
                recalculatedCount++;
            }
        }
    }

    var updatedStats = await service.GetEventStatsAsync(id);
    await hubContext.Clients.Group(id).SendAsync("OnGuestsBatchAdded", await service.GetGuestsAsync(id));
    await hubContext.Clients.All.SendAsync("OnStatsUpdated", updatedStats);

    return Results.Ok(new
    {
        success = true,
        message = $"已成功更新此活動之專屬職級尊榮排序規則！" + (recalculatedCount > 0 ? $"已同步重新計算 {recalculatedCount} 位貴賓職級權重。" : "現有名冊職級權重已符合最新規則。"),
        recalculatedCount,
        eventObj = ev
    });
});

// Update Single Guest Rank Weight
app.MapPost("/api/events/{id}/guests/{gId}/rank", async (string id, string gId, UpdateGuestRankRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var guests = await service.GetGuestsAsync(id);
    var g = guests.FirstOrDefault(x => x.GuestId == gId);
    if (g == null)
    {
        return Results.NotFound(new { success = false, message = "找不到該貴賓" });
    }

    if (req.RankWeight < 1 || req.RankWeight > 4)
    {
        return Results.BadRequest(new { success = false, message = "職級權重必須介於 1 到 4 之間" });
    }

    g.RankWeight = req.RankWeight;
    await service.UpdateGuestAsync(g);

    var stats = await service.GetEventStatsAsync(id);
    await hubContext.Clients.Group(id).SendAsync("OnGuestCheckInChanged", new
    {
        EventId = id,
        Guest = g,
        UpdatedBy = "名冊管理人員",
        Timestamp = TaiwanTime.Now,
        Stats = stats
    });
    await hubContext.Clients.All.SendAsync("OnStatsUpdated", stats);

    return Results.Ok(new { success = true, guest = g });
});

app.MapPut("/api/events/{id}/guests/{gId}/rank", async (string id, string gId, UpdateGuestRankRequest req, HttpContext ctx, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    var guests = await service.GetGuestsAsync(id);
    var g = guests.FirstOrDefault(x => x.GuestId == gId);
    if (g == null)
    {
        return Results.NotFound(new { success = false, message = "找不到該貴賓" });
    }

    if (req.RankWeight < 1 || req.RankWeight > 4)
    {
        return Results.BadRequest(new { success = false, message = "職級權重必須介於 1 到 4 之間" });
    }

    g.RankWeight = req.RankWeight;
    await service.UpdateGuestAsync(g);

    var stats = await service.GetEventStatsAsync(id);
    await hubContext.Clients.Group(id).SendAsync("OnGuestCheckInChanged", new
    {
        EventId = id,
        Guest = g,
        UpdatedBy = "名冊管理人員",
        Timestamp = TaiwanTime.Now,
        Stats = stats
    });
    await hubContext.Clients.All.SendAsync("OnStatsUpdated", stats);

    return Results.Ok(new { success = true, guest = g });
});


// --- 5. Export CSV & Excel ---

app.MapGet("/api/events/{id}/export", async (string id, HttpContext ctx, IEventService service) =>
{
    ctx.Response.Headers.CacheControl = "no-cache, no-store, must-revalidate";
    ctx.Response.Headers.Pragma = "no-cache";
    ctx.Response.Headers.Expires = "0";

    var ev = await service.GetEventByIdAsync(id);
    if (ev == null)
    {
        return Results.NotFound(new { message = "找不到該活動場次" });
    }

    var csvData = await service.ExportCsvAsync(id);
    var safeEventName = string.IsNullOrWhiteSpace(ev.EventName) ? "InPoint" : ev.EventName.Replace(" ", "_");
    var safeFileName = $"活動報到名冊_{safeEventName}_{TaiwanTime.Now:yyyyMMdd_HHmm}.csv";

    var preamble = System.Text.Encoding.UTF8.GetPreamble();
    var bytes = System.Text.Encoding.UTF8.GetBytes(csvData);
    var fullBytes = preamble.Concat(bytes).ToArray();

    return Results.File(fullBytes, "text/csv; charset=utf-8", safeFileName);
});

// --- 6. AI Text Parser & Assistant ---

app.MapPost("/api/ai/parse-guests", async (AiParseRequest req, HttpContext ctx, IEventService service) =>
{
    var session = GetSessionFromContext(ctx);
    if (session == null && !CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var list = await service.ParseRawGuestTextAsync(req.EventId, req.RawText);
    return Results.Ok(new { count = list.Count, parsedGuests = list });
});

app.MapPost("/api/ai/query-status", async (AiQueryRequest req, HttpContext ctx, IEventService service) =>
{
    var responseText = await service.ProcessAiQueryAsync(req.EventId, req.Query);
    return Results.Ok(new { reply = responseText });
});

// --- 7. Diagnostics ---

app.MapGet("/api/system/storage-status", async (HttpContext ctx, IEventService service) =>
{
    if (!CheckAdminAuth(ctx))
    {
        return Results.Unauthorized();
    }

    var status = await service.GetStorageDiagnosticsAsync();
    return Results.Ok(status);
});

// --- 8. Dynamic Anti-Cheat QR Code & Self Check-in ---

var qrSecret = Guid.NewGuid().ToString("N");

string GenerateDynamicToken(string eventId, long window)
{
    using var hmac = new System.Security.Cryptography.HMACSHA256(System.Text.Encoding.UTF8.GetBytes(qrSecret));
    var hash = hmac.ComputeHash(System.Text.Encoding.UTF8.GetBytes($"{eventId}_{window}"));
    return Convert.ToHexString(hash)[..16].ToLower();
}

string GenerateClientFallbackToken(string eventId, long window)
{
    var str = $"{eventId}_{window}";
    int hash = 0;
    for (int i = 0; i < str.Length; i++)
    {
        hash = ((hash << 5) - hash) + (int)str[i];
    }
    return Math.Abs(hash).ToString("x").PadLeft(8, '0') + (window % 100000).ToString("x");
}

bool ValidateDynamicToken(string eventId, string token, long reqTs = 0)
{
    if (string.IsNullOrWhiteSpace(token)) return false;
    var nowSec = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    
    if (reqTs > 0 && Math.Abs(nowSec - reqTs) > 75)
    {
        return false;
    }

    var effectiveTs = reqTs > 0 ? reqTs : nowSec;
    var window = effectiveTs / 60;
    var currentWindow = nowSec / 60;

    if (window < currentWindow - 1 || window > currentWindow + 1)
    {
        return false;
    }

    for (long w = currentWindow; w >= currentWindow - 1; w--)
    {
        var expected = GenerateDynamicToken(eventId, w);
        if (string.Equals(expected, token, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var clientExpected = GenerateClientFallbackToken(eventId, w);
        if (string.Equals(clientExpected, token, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }
    }
    return false;
}

app.MapGet("/api/events/{id}/dynamic-qr-token", (string id) =>
{
    var nowSec = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
    var currentWindow = nowSec / 60;
    var remaining = 60 - (nowSec % 60);
    var token = GenerateDynamicToken(id, currentWindow);

    return Results.Ok(new
    {
        eventId = id,
        token = token,
        ts = nowSec,
        intervalSeconds = 60,
        remainingSeconds = remaining == 0 ? 60 : remaining,
        generatedAt = DateTime.UtcNow,
        checkInPath = $"/self-checkin.html?eventId={id}&token={token}&ts={nowSec}"
    });
});

app.MapPost("/api/events/{id}/self-checkin", async (string id, SelfCheckInRequest req, IEventService service, IHubContext<CheckInHub> hubContext) =>
{
    if (!ValidateDynamicToken(id, req.Token, req.Ts))
    {
        return Results.BadRequest(new
        {
            success = false,
            error = "EXPIRED_QR_CODE",
            message = "⚠️ 此報到 QR 碼已過期失效（已超過 60 秒防作弊時限），請直接掃描現場大螢幕之最新動態 QR 碼！"
        });
    }

    var query = req.Identifier?.Trim() ?? "";
    if (string.IsNullOrWhiteSpace(query))
    {
        return Results.BadRequest(new { success = false, message = "請輸入員工卡號、編號或姓名" });
    }

    var guests = await service.GetGuestsAsync(id);
    var strippedQuery = query.TrimStart('0');
    if (string.IsNullOrEmpty(strippedQuery)) strippedQuery = "0";

    var target = guests.FirstOrDefault(g => 
        string.Equals(g.GuestId, query, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(g.GuestId?.TrimStart('0'), strippedQuery, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(g.Name, query, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(g.QrCodeHash, query, StringComparison.OrdinalIgnoreCase) ||
        (!string.IsNullOrEmpty(g.Phone) && g.Phone.EndsWith(query)));

    if (target == null)
    {
        return Results.NotFound(new
        {
            success = false,
            error = "GUEST_NOT_FOUND",
            message = $"⚠️ 查無與「{query}」相符之貴賓資料，請確認員工卡號或姓名！"
        });
    }

    if (target.IsCheckedIn)
    {
        return Results.Ok(new
        {
            success = true,
            alreadyCheckedIn = true,
            guest = target,
            message = $"ℹ️ 【{target.Name}】(編號: {target.GuestId}) 稍早已完成報到，您的席位為【{target.TableNo}】！"
        });
    }

    var updated = await service.ToggleCheckInAsync(id, target.GuestId, true, "手機掃碼自主報到");
    var stats = await service.GetEventStatsAsync(id);

    await hubContext.Clients.Group(id).SendAsync("OnGuestCheckInChanged", new
    {
        EventId = id,
        Guest = updated,
        UpdatedBy = "手機掃碼自主報到",
        Timestamp = TaiwanTime.Now,
        Stats = stats
    });
    await hubContext.Clients.All.SendAsync("OnStatsUpdated", stats);

    return Results.Ok(new
    {
        success = true,
        alreadyCheckedIn = false,
        guest = updated,
        message = $"🎉 自助報到成功！歡迎【{updated?.Organization}】{updated?.Title} {updated?.Name}，您的桌次為【{updated?.TableNo}】！"
    });
});

app.Run();

public record AiQueryRequest(string EventId, string Query);
