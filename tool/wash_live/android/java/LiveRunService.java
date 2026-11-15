package de.k0rbi02.wash_live;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Hält die „läuft“-Benachrichtigungen von Waschmaschine und Trockner aktuell –
 * unabhängig von Flutter, also auch wenn die App geschlossen oder weggewischt ist.
 * Den Countdown zählt Android selbst, den Balken zieht dieser Dienst alle 15 s nach.
 * Auf Android 16 wird die Meldung als Live Update (Chip in der Statusleiste) angefragt.
 */
public class LiveRunService extends Service {

    static final String EXTRA_MACHINE = "wash_machine";
    static final String EXTRA_ACTION = "wash_action";

    private static final String CHANNEL = "wash_live";
    private static final String PREFS = "wash_live";
    private static final long TICK_MS = 15_000L;
    private static final String[] MACHINES = {"wash", "dry"};

    private static volatile LiveRunService instance;

    static final class LiveRun {
        final String machine, title, program;
        final long start, end;

        LiveRun(String machine, String title, String program, long start, long end) {
            this.machine = machine;
            this.title = title;
            this.program = program;
            this.start = start;
            this.end = end;
        }
    }

    static int idFor(String machine) {
        return "wash".equals(machine) ? 103 : 203;
    }

    static void start(Context ctx, LiveRun run) {
        save(ctx, run);
        LiveRunService running = instance;
        if (running != null) {
            running.refresh();
            return;
        }
        Intent intent = new Intent(ctx, LiveRunService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.startForegroundService(intent);
        } else {
            ctx.startService(intent);
        }
    }

    static void stop(Context ctx, String machine) {
        prefs(ctx).edit().remove(machine).apply();
        nm(ctx).cancel(idFor(machine));
        LiveRunService running = instance;
        if (running != null) running.refresh();
    }

    private static SharedPreferences prefs(Context ctx) {
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static NotificationManager nm(Context ctx) {
        return (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
    }

    private static void save(Context ctx, LiveRun r) {
        try {
            JSONObject j = new JSONObject()
                    .put("title", r.title)
                    .put("program", r.program)
                    .put("start", r.start)
                    .put("end", r.end);
            prefs(ctx).edit().putString(r.machine, j.toString()).apply();
        } catch (Exception ignored) {
        }
    }

    private static List<LiveRun> load(Context ctx) {
        List<LiveRun> out = new ArrayList<>();
        for (String m : MACHINES) {
            String raw = prefs(ctx).getString(m, null);
            if (raw == null) continue;
            try {
                JSONObject j = new JSONObject(raw);
                out.add(new LiveRun(m, j.getString("title"), j.getString("program"), j.getLong("start"), j.getLong("end")));
            } catch (Exception ignored) {
            }
        }
        return out;
    }

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            refresh();
            handler.postDelayed(this, TICK_MS);
        }
    };
    private Integer foregroundId = null;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        ensureChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        handler.removeCallbacks(tick);
        tick.run();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacks(tick);
        if (instance == this) instance = null;
        super.onDestroy();
    }

    void refresh() {
        long now = System.currentTimeMillis();
        List<LiveRun> live = new ArrayList<>();
        for (LiveRun r : load(this)) {
            if (r.end <= now) {
                // Abgelaufen – ab hier übernimmt die „fertig“-Erinnerung.
                prefs(this).edit().remove(r.machine).apply();
                nm(this).cancel(idFor(r.machine));
            } else {
                live.add(r);
            }
        }

        if (live.isEmpty()) {
            if (foregroundId == null) {
                // Per startForegroundService gestartet: einmal Vordergrund, sonst beendet Android die App.
                goForeground(999, placeholder());
            }
            stopForegroundCompat();
            stopSelf();
            handler.removeCallbacks(tick);
            return;
        }

        LiveRun first = live.get(0);
        int firstId = idFor(first.machine);
        if (foregroundId != null && foregroundId != firstId) nm(this).cancel(foregroundId);
        goForeground(firstId, build(first, now));
        for (int i = 1; i < live.size(); i++) {
            LiveRun r = live.get(i);
            nm(this).notify(idFor(r.machine), build(r, now));
        }
    }

    private void goForeground(int id, Notification n) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(id, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        } else {
            startForeground(id, n);
        }
        foregroundId = id;
    }

    @SuppressWarnings("deprecation")
    private void stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE);
        } else {
            stopForeground(true);
        }
        foregroundId = null;
    }

    private void ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        if (nm(this).getNotificationChannel(CHANNEL) != null) return;
        NotificationChannel ch = new NotificationChannel(CHANNEL, "Läuft gerade", NotificationManager.IMPORTANCE_LOW);
        ch.setDescription("Zeigt dauerhaft, wie lange Waschmaschine und Trockner noch brauchen.");
        ch.setShowBadge(false);
        nm(this).createNotificationChannel(ch);
    }

    @SuppressWarnings("deprecation")
    private Notification.Builder builder() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL)
                : new Notification.Builder(this);
    }

    private Notification placeholder() {
        return builder()
                .setSmallIcon(R.drawable.ic_stat_wash)
                .setContentTitle("wa:sh")
                .setOngoing(true)
                .build();
    }

    private Notification build(LiveRun r, long now) {
        long total = Math.max(1L, r.end - r.start);
        int pct = (int) Math.max(0, Math.min(100, (now - r.start) * 100 / total));
        long minsLeft = Math.max(1L, (r.end - now + 59_999L) / 60_000L);
        String clock = new SimpleDateFormat("HH:mm", Locale.GERMANY).format(new Date(r.end));

        Notification.Builder b = builder()
                .setSmallIcon(R.drawable.ic_stat_wash)
                .setContentTitle(r.title)
                .setContentText("Fertig um " + clock + " · " + r.program)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_PROGRESS)
                .setShowWhen(true)
                .setWhen(r.end)
                .setUsesChronometer(true)
                .setProgress(100, pct, false)
                .setContentIntent(pending(r.machine, null, 0))
                .addAction(new Notification.Action.Builder((Icon) null, "Schon fertig", pending(r.machine, "finish", 1)).build())
                .addAction(new Notification.Action.Builder((Icon) null, "Zur Übersicht", pending(r.machine, "overview", 2)).build());

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) b.setChronometerCountDown(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) b.setTimeoutAfter(r.end - now);
        if (Build.VERSION.SDK_INT >= 36) promote(b, minsLeft + " Min");
        return b.build();
    }

    /** Android 16: als Live Update mit Chip in der Statusleiste anfragen. */
    private void promote(Notification.Builder b, String chip) {
        try {
            b.getClass().getMethod("setRequestPromotedOngoing", boolean.class).invoke(b, true);
            b.getClass().getMethod("setShortCriticalText", CharSequence.class).invoke(b, chip);
        } catch (Exception ignored) {
            // Ohne die API bleibt es eine normale Meldung mit Balken.
        }
    }

    private PendingIntent pending(String machine, String action, int code) {
        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (intent == null) intent = new Intent();
        intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        intent.putExtra(EXTRA_MACHINE, machine);
        if (action != null) intent.putExtra(EXTRA_ACTION, action);
        return PendingIntent.getActivity(
                this,
                idFor(machine) * 10 + code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
}
