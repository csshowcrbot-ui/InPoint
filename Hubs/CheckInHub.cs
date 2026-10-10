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
}
