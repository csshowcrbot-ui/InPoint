using Microsoft.EntityFrameworkCore;
using ShowChwanCheckIn.Models;

namespace ShowChwanCheckIn.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Event> Events => Set<Event>();
    public DbSet<Guest> Guests => Set<Guest>();
    public DbSet<User> Users => Set<User>();
    public DbSet<LotteryPrize> LotteryPrizes => Set<LotteryPrize>();
    public DbSet<LotteryWinner> LotteryWinners => Set<LotteryWinner>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Event Entity -> checkInEvents
        modelBuilder.Entity<Event>(entity =>
        {
            entity.ToTable("checkInEvents");
            entity.HasKey(e => e.EventId);
            entity.Property(e => e.EventId).HasMaxLength(100);
            entity.Property(e => e.EventName).HasMaxLength(255).IsRequired();
            entity.Property(e => e.Location).HasMaxLength(255);
            entity.Property(e => e.Description).HasMaxLength(1000);
            entity.Property(e => e.OwnerUsername).HasMaxLength(100);
            entity.Property(e => e.RankRules);
            entity.Property(e => e.HasLotteryAddon);
        });

        // Guest Entity -> checkInGuests (Composite Key: EventId + GuestId to support multi-event guest IDs)
        modelBuilder.Entity<Guest>(entity =>
        {
            entity.ToTable("checkInGuests");
            entity.HasKey(g => new { g.EventId, g.GuestId });
            entity.Property(g => g.EventId).HasMaxLength(100);
            entity.Property(g => g.GuestId).HasMaxLength(100);
            entity.Property(g => g.Name).HasMaxLength(100).IsRequired();
            entity.Property(g => g.Organization).HasMaxLength(200);
            entity.Property(g => g.Title).HasMaxLength(100);
            entity.Property(g => g.TableNo).HasMaxLength(50);
            entity.Property(g => g.QrCodeHash).HasMaxLength(100);
            entity.Property(g => g.Phone).HasMaxLength(50);
            entity.Property(g => g.CheckedInBy).HasMaxLength(100);
            entity.Property(g => g.Notes).HasMaxLength(1000);

            entity.HasIndex(g => g.EventId);
            entity.HasIndex(g => g.QrCodeHash);
        });

        // User Entity -> checkInUsers
        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("checkInUsers");
            entity.HasKey(u => u.UserId);
            entity.Property(u => u.UserId).HasMaxLength(100);
            entity.Property(u => u.Username).HasMaxLength(100).IsRequired();
            entity.Property(u => u.PasswordHash).HasMaxLength(255).IsRequired();
            entity.Property(u => u.Role).HasMaxLength(50).IsRequired();
            entity.Property(u => u.DisplayName).HasMaxLength(100);
            entity.Property(u => u.Organization).HasMaxLength(200);
            entity.Property(u => u.PlanType).HasMaxLength(50);
            entity.Property(u => u.Notes).HasMaxLength(1000);
            entity.Property(u => u.HasLotteryAddon);
            entity.Property(u => u.LotteryAuthorizedAt);

            entity.HasIndex(u => u.Username).IsUnique();
        });

        // LotteryPrize Entity -> checkInLotteryPrizes
        modelBuilder.Entity<LotteryPrize>(entity =>
        {
            entity.ToTable("checkInLotteryPrizes");
            entity.HasKey(p => p.PrizeId);
            entity.Property(p => p.PrizeId).HasMaxLength(100);
            entity.Property(p => p.EventId).HasMaxLength(100).IsRequired();
            entity.Property(p => p.PrizeName).HasMaxLength(200).IsRequired();
            entity.Property(p => p.Quantity).IsRequired();
            entity.Property(p => p.DisplayOrder).IsRequired();

            entity.HasIndex(p => p.EventId);
        });

        // LotteryWinner Entity -> checkInLotteryWinners
        modelBuilder.Entity<LotteryWinner>(entity =>
        {
            entity.ToTable("checkInLotteryWinners");
            entity.HasKey(w => w.WinnerId);
            entity.Property(w => w.WinnerId).HasMaxLength(100);
            entity.Property(w => w.EventId).HasMaxLength(100).IsRequired();
            entity.Property(w => w.PrizeId).HasMaxLength(100);
            entity.Property(w => w.PrizeName).HasMaxLength(200).IsRequired();
            entity.Property(w => w.GuestId).HasMaxLength(100).IsRequired();
            entity.Property(w => w.GuestName).HasMaxLength(100).IsRequired();
            entity.Property(w => w.Organization).HasMaxLength(200);
            entity.Property(w => w.Title).HasMaxLength(100);
            entity.Property(w => w.TableNo).HasMaxLength(50);

            entity.HasIndex(w => w.EventId);
            entity.HasIndex(w => new { w.EventId, w.GuestId });
        });
    }

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        base.ConfigureConventions(configurationBuilder);

        configurationBuilder.Properties<DateTime>().HaveConversion<UtcDateTimeConverter>();
        configurationBuilder.Properties<DateTime?>().HaveConversion<NullableUtcDateTimeConverter>();
    }
}

public class UtcDateTimeConverter : Microsoft.EntityFrameworkCore.Storage.ValueConversion.ValueConverter<DateTime, DateTime>
{
    public UtcDateTimeConverter() : base(
        v => v.Kind == DateTimeKind.Utc ? v : DateTime.SpecifyKind(v, DateTimeKind.Utc),
        v => DateTime.SpecifyKind(v, DateTimeKind.Utc))
    {
    }
}

public class NullableUtcDateTimeConverter : Microsoft.EntityFrameworkCore.Storage.ValueConversion.ValueConverter<DateTime?, DateTime?>
{
    public NullableUtcDateTimeConverter() : base(
        v => !v.HasValue ? v : (v.Value.Kind == DateTimeKind.Utc ? v : DateTime.SpecifyKind(v.Value, DateTimeKind.Utc)),
        v => !v.HasValue ? v : DateTime.SpecifyKind(v.Value, DateTimeKind.Utc))
    {
    }
}
