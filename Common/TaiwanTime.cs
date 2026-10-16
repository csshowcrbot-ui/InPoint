using System;

namespace ShowChwanCheckIn.Common;

/// <summary>
/// 台灣標準時間 (台北時間 UTC+8) 處理工具
/// </summary>
public static class TaiwanTime
{
    private static readonly TimeZoneInfo _taiwanZone = InitTaiwanZone();

    private static TimeZoneInfo InitTaiwanZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Taipei Standard Time");
        }
        catch
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById("Asia/Taipei");
            }
            catch
            {
                return TimeZoneInfo.CreateCustomTimeZone(
                    "Taipei Standard Time",
                    TimeSpan.FromHours(8),
                    "(UTC+08:00) 台北標準時間",
                    "台北標準時間");
            }
        }
    }

    /// <summary>
    /// 取得台灣台北標準時區 (UTC+8)
    /// </summary>
    public static TimeZoneInfo Zone => _taiwanZone;

    /// <summary>
    /// 取得當前台灣台北標準時間
    /// </summary>
    public static DateTime Now => TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, _taiwanZone);

    /// <summary>
    /// 將 DateTime 轉換為台灣台北標準時間
    /// </summary>
    public static DateTime ToTaiwanTime(this DateTime dt)
    {
        if (dt.Kind == DateTimeKind.Utc)
        {
            return TimeZoneInfo.ConvertTimeFromUtc(dt, _taiwanZone);
        }
        else if (dt.Kind == DateTimeKind.Local)
        {
            return TimeZoneInfo.ConvertTime(dt, _taiwanZone);
        }
        else
        {
            // Unspecified 視為 UTC 時間（資料庫存儲的時間標準）
            var utc = DateTime.SpecifyKind(dt, DateTimeKind.Utc);
            return TimeZoneInfo.ConvertTimeFromUtc(utc, _taiwanZone);
        }
    }

    /// <summary>
    /// 將可為空的 DateTime 轉換為台灣台北標準時間
    /// </summary>
    public static DateTime? ToTaiwanTime(this DateTime? dt)
    {
        return dt.HasValue ? ToTaiwanTime(dt.Value) : null;
    }

    /// <summary>
    /// 格式化為台灣標準時間字串 (預設 yyyy/MM/dd HH:mm:ss)
    /// </summary>
    public static string ToTaiwanTimeString(this DateTime dt, string format = "yyyy/MM/dd HH:mm:ss")
    {
        return ToTaiwanTime(dt).ToString(format);
    }

    /// <summary>
    /// 格式化為台灣標準時間字串 (若為 null 則返回空字串)
    /// </summary>
    public static string ToTaiwanTimeString(this DateTime? dt, string format = "yyyy/MM/dd HH:mm:ss")
    {
        if (!dt.HasValue) return string.Empty;
        return ToTaiwanTime(dt.Value).ToString(format);
    }
}
