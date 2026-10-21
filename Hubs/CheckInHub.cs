using Microsoft.AspNetCore.SignalR;
using ShowChwanCheckIn.Models;

namespace ShowChwanCheckIn.Hubs;

public class CheckInHub : Hub
{
    public async Task JoinEvent(string eventId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, eventId);
    }

    public async Task LeaveEvent(string eventId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, eventId);
    }

    public async Task NotifyCheckIn(string eventId, Guest guest, string staffName)
    {
        await Clients.Group(eventId).SendAsync("OnGuestCheckInChanged", new
        {
            EventId = eventId,
            Guest = guest,
            UpdatedBy = staffName,
            Timestamp = DateTime.Now
        });
    }

    /// <summary>
    /// 後台觸發開始抽動畫面 (大螢幕高速輪播滾動)
    /// </summary>
    public async Task StartLotterySpin(string eventId, string prizeName, int quantity, int eligibleCount)
    {
        await Clients.Group(eventId).SendAsync("OnLotterySpinStarted", new
        {
            EventId = eventId,
            PrizeName = prizeName,
            Quantity = quantity,
            EligibleCount = eligibleCount,
            Timestamp = DateTime.UtcNow
        });
    }

    /// <summary>
    /// 後台完成抽獎，大螢幕揭曉得獎名單與震撼金光彩帶
    /// </summary>
    public async Task NotifyLotteryDrawn(string eventId, string prizeName, object winners)
    {
        await Clients.Group(eventId).SendAsync("OnLotteryDrawn", new
        {
            EventId = eventId,
            PrizeName = prizeName,
            Winners = winners,
            Timestamp = DateTime.UtcNow
        });
    }

    /// <summary>
    /// 棄權重抽特定中獎人
    /// </summary>
    public async Task NotifyLotteryWinnerRevoked(string eventId, string winnerId)
    {
        await Clients.Group(eventId).SendAsync("OnLotteryWinnerRevoked", new
        {
            EventId = eventId,
            WinnerId = winnerId,
            Timestamp = DateTime.UtcNow
        });
    }

    /// <summary>
    /// 重置中獎名單
    /// </summary>
    public async Task NotifyLotteryReset(string eventId)
    {
        await Clients.Group(eventId).SendAsync("OnLotteryReset", new
        {
            EventId = eventId,
            Timestamp = DateTime.UtcNow
        });
    }
}
