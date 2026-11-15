package de.k0rbi02.wash_live;

import android.content.Context;
import android.content.Intent;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/** Brücke zwischen Flutter und der nativen „läuft“-Anzeige (Android). */
public class WashLivePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
        PluginRegistry.NewIntentListener {

    private MethodChannel channel;
    private Context context;
    private ActivityPluginBinding activity;
    private Map<String, String> launch;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "wash/live");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "start": {
                Number start = call.argument("start");
                Number end = call.argument("end");
                LiveRunService.start(context, new LiveRunService.LiveRun(
                        call.argument("machine"),
                        call.argument("title"),
                        call.argument("program"),
                        start.longValue(),
                        end.longValue()));
                result.success(null);
                break;
            }
            case "stop":
                LiveRunService.stop(context, call.argument("machine"));
                result.success(null);
                break;
            case "launchAction":
                result.success(launch);
                launch = null;
                break;
            case "openNotificationSettings": {
                // Direkt in die Benachrichtigungs-Einstellungen der App (Kategorien je Maschine).
                Intent i = new Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.getPackageName())
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(i);
                result.success(null);
                break;
            }
            default:
                result.notImplemented();
        }
    }

    // ── Tipps auf die Meldung bzw. ihre Buttons ────────────────────────

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding;
        binding.addOnNewIntentListener(this);
        launch = extract(binding.getActivity().getIntent());
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding;
        binding.addOnNewIntentListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        if (activity != null) activity.removeOnNewIntentListener(this);
        activity = null;
    }

    @Override
    public boolean onNewIntent(@NonNull Intent intent) {
        Map<String, String> data = extract(intent);
        if (data == null) return false;
        if (channel != null) channel.invokeMethod("open", data);
        return true;
    }

    private static Map<String, String> extract(Intent i) {
        if (i == null) return null;
        String machine = i.getStringExtra(LiveRunService.EXTRA_MACHINE);
        if (machine == null) return null;
        Map<String, String> m = new HashMap<>();
        m.put("machine", machine);
        m.put("action", i.getStringExtra(LiveRunService.EXTRA_ACTION));
        i.removeExtra(LiveRunService.EXTRA_MACHINE);
        i.removeExtra(LiveRunService.EXTRA_ACTION);
        return m;
    }
}
