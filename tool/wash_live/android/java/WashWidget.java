package de.k0rbi02.wash_live;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.SystemClock;
import android.text.format.DateFormat;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONObject;

import java.util.Date;

/**
 * Widget für den Startbildschirm: Waschmaschine und Trockner nebeneinander,
 * je mit Restzeit (läuft von selbst runter), „fertig um“ und Fortschritt.
 * Tippen: freie Maschine → Programm 1 starten, sonst die App öffnen.
 *
 * Den Stand meldet die App über {@link #save} (Plugin-Methode „widget“).
 */
public class WashWidget extends AppWidgetProvider {

    private static final String PREFS = "wash_widget";
    private static final String[] MACHINES = {"wash", "dry"};

    @Override
    public void onUpdate(Context ctx, AppWidgetManager mgr, int[] ids) {
        render(ctx, mgr, ids);
    }

    @Override
    public void onReceive(Context ctx, Intent intent) {
        super.onReceive(ctx, intent);
        // Auch der eigene Wecker zum Ende eines Laufs landet hier.
        if (AppWidgetManager.ACTION_APPWIDGET_UPDATE.equals(intent.getAction())
                && intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS) == null) {
            refresh(ctx);
        }
    }

    /** Stand einer Maschine von der App: state = idle | running | finished. */
    static void save(Context ctx, String machine, String state, String program, long start, long end) {
        try {
            JSONObject j = new JSONObject()
                    .put("state", state)
                    .put("program", program == null ? "" : program)
                    .put("start", start)
                    .put("end", end);
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(machine, j.toString()).apply();
        } catch (Exception ignored) {
        }
        refresh(ctx);
    }

    static void refresh(Context ctx) {
        AppWidgetManager mgr = AppWidgetManager.getInstance(ctx);
        int[] ids = mgr.getAppWidgetIds(new ComponentName(ctx, WashWidget.class));
        if (ids.length > 0) render(ctx, mgr, ids);
    }

    private static void render(Context ctx, AppWidgetManager mgr, int[] ids) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        RemoteViews views = new RemoteViews(ctx.getPackageName(), R.layout.wash_widget);
        long now = System.currentTimeMillis();
        long nextEnd = Long.MAX_VALUE;

        for (String m : MACHINES) {
            boolean wash = "wash".equals(m);
            int title = wash ? R.id.wash_title : R.id.dry_title;
            int timer = wash ? R.id.wash_timer : R.id.dry_timer;
            int status = wash ? R.id.wash_status : R.id.dry_status;
            int sub = wash ? R.id.wash_sub : R.id.dry_sub;
            int bar = wash ? R.id.wash_progress : R.id.dry_progress;
            int cell = wash ? R.id.wash_cell : R.id.dry_cell;

            views.setTextViewText(title, wash ? LiveRunService.tr("Waschen", "Wash") : LiveRunService.tr("Trocknen", "Dry"));

            String state = "idle", program = "";
            long start = 0, end = 0;
            try {
                String raw = prefs.getString(m, null);
                if (raw != null) {
                    JSONObject j = new JSONObject(raw);
                    state = j.optString("state", "idle");
                    program = j.optString("program", "");
                    start = j.optLong("start");
                    end = j.optLong("end");
                }
            } catch (Exception ignored) {
            }

            boolean running = !"idle".equals(state) && end > now;
            boolean done = !"idle".equals(state) && end > 0 && end <= now;

            if (running) {
                views.setViewVisibility(timer, View.VISIBLE);
                views.setViewVisibility(status, View.GONE);
                // Chronometer zählt selbst runter, ohne dass das Widget aktualisiert werden muss.
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    views.setChronometer(timer, SystemClock.elapsedRealtime() + (end - now), null, true);
                    views.setChronometerCountDown(timer, true);
                } else {
                    views.setChronometer(timer, SystemClock.elapsedRealtime() - (now - start), null, true);
                }
                String clock = DateFormat.getTimeFormat(ctx).format(new Date(end));
                views.setTextViewText(sub, LiveRunService.tr("fertig ", "done ") + clock + (program.isEmpty() ? "" : " · " + program));
                views.setViewVisibility(bar, View.VISIBLE);
                long total = Math.max(1, end - start);
                views.setProgressBar(bar, 100, (int) Math.max(0, Math.min(100, (now - start) * 100 / total)), false);
                nextEnd = Math.min(nextEnd, end);
                views.setOnClickPendingIntent(cell, open(ctx, m, wash ? 11 : 21));
            } else {
                views.setViewVisibility(timer, View.GONE);
                views.setViewVisibility(status, View.VISIBLE);
                views.setViewVisibility(bar, View.GONE);
                views.setChronometer(timer, SystemClock.elapsedRealtime(), null, false);
                if (done) {
                    views.setTextViewText(status, LiveRunService.tr("Fertig!", "Done!"));
                    views.setTextViewText(sub, LiveRunService.tr("Ab in den Keller", "Down to the basement"));
                    views.setOnClickPendingIntent(cell, open(ctx, m, wash ? 12 : 22));
                } else {
                    views.setTextViewText(status, LiveRunService.tr("frei", "free"));
                    views.setTextViewText(sub, LiveRunService.tr("Tippen: Programm 1 starten", "Tap: start program 1"));
                    views.setOnClickPendingIntent(cell, startLink(ctx, m, wash ? 13 : 23));
                }
            }
        }

        for (int id : ids) mgr.updateAppWidget(id, views);
        scheduleAt(ctx, nextEnd);
    }

    /** App öffnen, direkt bei dieser Maschine (wie die „läuft“-Anzeige). */
    private static PendingIntent open(Context ctx, String machine, int code) {
        Intent intent = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (intent == null) intent = new Intent();
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        intent.putExtra(LiveRunService.EXTRA_MACHINE, machine);
        return PendingIntent.getActivity(ctx, 900 + code, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** Freie Maschine: wash://start?machine=…&program=1 – startet sofort. */
    private static PendingIntent startLink(Context ctx, String machine, int code) {
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse("wash://start?machine=" + machine + "&program=1"));
        intent.setPackage(ctx.getPackageName());
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(ctx, 900 + code, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** Zum Ende des nächsten Laufs neu zeichnen („Fertig!“). Ungenau reicht. */
    private static void scheduleAt(Context ctx, long when) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(ctx, WashWidget.class).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        PendingIntent pi = PendingIntent.getBroadcast(ctx, 990, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        am.cancel(pi);
        if (when != Long.MAX_VALUE) am.set(AlarmManager.RTC, when + 1000, pi);
    }
}
