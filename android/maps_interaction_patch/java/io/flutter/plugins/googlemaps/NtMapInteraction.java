package io.flutter.plugins.googlemaps;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Point;
import android.graphics.drawable.LayerDrawable;
import android.graphics.drawable.ShapeDrawable;
import android.graphics.drawable.shapes.OvalShape;
import android.util.Log;
import android.view.ViewGroup;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.maps.android.clustering.Cluster;
import com.google.maps.android.ui.IconGenerator;
import com.google.maps.android.ui.SquareTextView;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import java.io.ByteArrayOutputStream;
import java.util.*;
import java.util.function.Predicate;

/** Narrow NT boundary for exact rendered-pixel picking and selection context. */
final class NtMapInteraction {
  static final int ALPHA_MIN = 128; // No transparent margins or faint shadow targets.
  final float density;
  private final GoogleMap map;
  private final Context context;
  private final MethodChannel channel;
  private final Predicate<MarkerBuilder> current;
  private final Runnable recluster;
  private final Map<String, Frame> frames = new HashMap<>();
  private final Map<String, Entry> entries = new LinkedHashMap<>();
  private final Map<String, Set<String>> latestClusters = new HashMap<>();
  private final Map<String, Bitmap> countBitmaps = new HashMap<>();
  private Set<String> remainder = Collections.emptySet();
  String selectedOwnerId, selectedManagerId;
  boolean inferRemainder;
  void inferredRemainder(Set<String> ids) { if (inferRemainder) remainder = ids; }
  private boolean enabled, trace;
  private long gesture, generation, renderGeneration;
  private int traceCount;
  private String selectedGroup;
  private Frame selectedGroupFrame;

  NtMapInteraction(int id, Context context, BinaryMessenger messenger, GoogleMap map,
      Predicate<MarkerBuilder> current, Runnable recluster) {
    this.context = context; this.map = map; this.current = current; this.recluster = recluster;
    density = context.getResources().getDisplayMetrics().density;
    channel = new MethodChannel(messenger, "nexttransfer/maps_interaction/" + id);
    channel.setMethodCallHandler((call, result) -> {
      if (call.method.equals("configure")) {
        enabled = Boolean.TRUE.equals(call.argument("enabled"));
        trace = Boolean.TRUE.equals(call.argument("trace")) && (context.getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        result.success(null);
      } else if (call.method.equals("selection")) {
        Number value = call.argument("generation");
        long next = value == null ? 0 : value.longValue();
        if (next < generation) { result.success(null); return; }
        generation = next;
        List<String> ids = call.argument("remainderIds");
        Set<String> nextRemainder = ids == null ? Collections.emptySet() : new HashSet<>(ids);
        String nextOwner = call.argument("selectedOwnerId");
        boolean changed = !remainder.equals(nextRemainder) || !Objects.equals(nextOwner, selectedOwnerId);
        selectedOwnerId = nextOwner;
        selectedManagerId = call.argument("selectedManagerId");
        inferRemainder = Boolean.TRUE.equals(call.argument("inferRemainder"));
        remainder = nextRemainder;
        selectedGroup = call.argument("groupKey");
        byte[] bytes = call.argument("groupPin");
        Number width = call.argument("width"), height = call.argument("height");
        selectedGroupFrame = bytes == null ? null : new Frame(BitmapFactory.decodeByteArray(bytes, 0, bytes.length),
            width.doubleValue() * density, height.doubleValue() * density);
        for (Entry entry : entries.values()) applyGroupSelection(entry);
        if (changed) recluster.run();
        log("selection-context", selectedGroup == null ? "single-or-clear" : selectedGroup);
        result.success(null);
      } else { result.notImplemented(); }
    });
  }

  boolean enabled() { return enabled; }
  void dispose() { enabled = false; channel.setMethodCallHandler(null); entries.clear(); frames.clear(); countBitmaps.clear(); }
  void log(String phase, String id) {
    if (trace && traceCount++ < 256) Log.d("NTMapTiming", "phase=" + phase + " token=" + gesture
        + " selection=" + generation + " render=" + renderGeneration + " us=" + System.nanoTime()/1000 + " id=" + id);
  }

  void remember(PlatformMarker marker) {
    Object value = marker.getIcon().getBitmap();
    if (value instanceof PlatformBitmapBytesMap bytes) {
      byte[] data = bytes.getByteData();
      Bitmap bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
      if (bitmap != null) {
        double w = bytes.getWidth() == null ? bitmap.getWidth()/bytes.getImagePixelRatio()*density : bytes.getWidth()*density;
        double h = bytes.getHeight() == null ? bitmap.getHeight()/bytes.getImagePixelRatio()*density : bytes.getHeight()*density;
        Bitmap rendered = Bitmap.createScaledBitmap(bitmap, (int)w, (int)h, true);
        Frame frame = new Frame(rendered, rendered.getWidth(), rendered.getHeight(), Math.min(rendered.getHeight(), 34 * density));
        frames.put(marker.getMarkerId(), frame);
        for (Entry entry : entries.values()) if (marker.getMarkerId().equals(entry.recordId)) entry.frame = frame;
      }
    }
  }

  void forget(String id) {
    frames.remove(id);
    entries.values().removeIf(entry -> id.equals(entry.recordId));
  }
  void diffArrived() { renderGeneration++; log("native-diff", ""); }
  void membershipChanged(String manager) { log("membership", manager); }

  void record(String id, Marker marker, MarkerBuilder builder) {
    if (id.equals("provisional-place")) return;
    entries.values().removeIf(entry -> id.equals(entry.recordId));
    Frame frame = frames.get(id);
    if (frame != null) entries.put(marker.getId(), new Entry(id, id, marker, frame,
        Collections.singletonList(builder), null));
  }

  static String clusterKey(String manager, Collection<? extends MarkerBuilder> items) {
    List<String> ids = new ArrayList<>();
    for (MarkerBuilder item : items) ids.add(item.markerId());
    Collections.sort(ids);
    return manager + ":" + String.join("|", ids);
  }
  void clustersChanged(String manager, Set<? extends Cluster<? extends MarkerBuilder>> clusters) {
    Set<String> keys = new HashSet<>();
    for (Cluster<? extends MarkerBuilder> cluster : clusters) keys.add(clusterKey(manager, cluster.getItems()));
    latestClusters.put(manager, keys);
    entries.values().removeIf(entry -> manager.equals(entry.manager) && !keys.contains(entry.key));
    renderGeneration++;
    log("cluster-result", manager);
  }

  boolean remainder(Cluster<? extends MarkerBuilder> cluster) {
    if (remainder.size() < 2 || cluster.getSize() != remainder.size()) return false;
    for (MarkerBuilder item : cluster.getItems()) if (!remainder.contains(item.markerId())) return false;
    return true;
  }

  // Exact upstream 4.1.0 count-icon recipe. Capturing the bitmap here means
  // picking uses the pixels actually sent to Maps, not guessed text bounds.
  Bitmap countBitmap(String text, int color, int textAppearance) {
    String key = text + ":" + color + ":" + textAppearance;
    Bitmap cached = countBitmaps.get(key);
    if (cached != null) return cached;
    IconGenerator generator = new IconGenerator(context);
    SquareTextView content = new SquareTextView(context);
    content.setLayoutParams(new ViewGroup.LayoutParams(-2, -2));
    content.setId(com.google.maps.android.R.id.amu_text);
    int padding = (int)(12 * density);
    content.setPadding(padding, padding, padding, padding);
    generator.setContentView(content);
    generator.setTextAppearance(textAppearance);
    ShapeDrawable circle = new ShapeDrawable(new OvalShape()); circle.getPaint().setColor(color);
    ShapeDrawable outline = new ShapeDrawable(new OvalShape()); outline.getPaint().setColor(0x80ffffff);
    LayerDrawable background = new LayerDrawable(new android.graphics.drawable.Drawable[]{outline, circle});
    int stroke = (int)(3 * density); background.setLayerInset(1, stroke, stroke, stroke, stroke);
    generator.setBackground(background);
    Bitmap bitmap = generator.makeIcon(text);
    countBitmaps.put(key, bitmap); return bitmap;
  }

  void cluster(String manager, Cluster<? extends MarkerBuilder> cluster, Marker marker, Bitmap bitmap) {
    List<MarkerBuilder> items = new ArrayList<>(cluster.getItems());
    if (!items.stream().allMatch(current)) return;
    String key = clusterKey(manager, items);
    if (!latestClusters.getOrDefault(manager, Collections.emptySet()).contains(key)) return;
    entries.values().removeIf(entry -> key.equals(entry.key));
    Entry entry = new Entry(key, null, marker, new Frame(bitmap, bitmap.getWidth(), bitmap.getHeight()), items, manager);
    entries.put(marker.getId(), entry);
    applyGroupSelection(entry);
    log("cluster-rendered", key);
  }

  private void applyGroupSelection(Entry entry) {
    if (entry.manager == null) return;
    Frame frame = entry.key.equals(selectedGroup) && selectedGroupFrame != null ? selectedGroupFrame : entry.frame;
    if (entry.applied == frame) return;
    entry.applied = frame;
    entry.marker.setIcon(BitmapDescriptorFactory.fromBitmap(Bitmap.createScaledBitmap(frame.bitmap,
        (int)frame.width, (int)frame.height, true)));
    // Both compositions preserve the original bottom-center anchor. The hit
    // shape remains the count bitmap: the red ornament adds no hit catchment.
    entry.marker.setAnchor(.5f, 1f);
  }

  Entry resolve(float x, float y) {
    Entry best = null; double bestDistance = Double.POSITIVE_INFINITY;
    for (Entry entry : entries.values()) {
      if (!entry.items.stream().allMatch(current) || !entry.marker.isVisible() || entry.marker.getAlpha() <= 0) continue;
      Point anchor = map.getProjection().toScreenLocation(entry.marker.getPosition());
      if (!entry.frame.hit(x - anchor.x + entry.frame.width*.5, y - anchor.y + entry.frame.height)) continue;
      // Use measured painted identity bounds, not the transparent canvas or
      // SDK proximity cycle, to arbitrate genuinely overlapping painted hits.
      double distance = Math.pow(x-(anchor.x-entry.frame.width*.5+entry.frame.centerX), 2)
          + Math.pow(y-(anchor.y-entry.frame.height+entry.frame.centerY), 2);
      if (best == null || distance < bestDistance || (distance == bestDistance && entry.key.compareTo(best.key) < 0)) {
        best = entry; bestDistance = distance;
      }
    }
    return best;
  }

  void tap(float x, float y) {
    gesture++; log("T-1", "");
    Entry entry = resolve(x, y);
    log("T0", entry == null ? "blank" : entry.key);
    Map<String,Object> data = new HashMap<>();
    data.put("token", gesture); data.put("renderGeneration", renderGeneration);
    data.put("selectionGeneration", generation); data.put("x", (double)x); data.put("y", (double)y);
    if (entry != null) {
      data.put("recordId", entry.recordId);
      List<String> ids = new ArrayList<>(); for (MarkerBuilder item : entry.items) ids.add(item.markerId());
      data.put("ids", ids);
      LatLng position = entry.marker.getPosition();
      data.put("latitude", position.latitude); data.put("longitude", position.longitude);
      if (entry.manager != null) {
        data.put("groupKey", entry.key);
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        entry.frame.bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes);
        data.put("bitmap", bytes.toByteArray());
        data.put("width", entry.frame.width/density); data.put("height", entry.frame.height/density);
      }
    }
    channel.invokeMethod("tap", data);
  }

  static final class Frame {
    final Bitmap bitmap; final double width, height, centerX, centerY;
    Frame(Bitmap bitmap, double width, double height) { this(bitmap,width,height,height); }
    Frame(Bitmap bitmap, double width, double height, double identityHeight) {
      this.bitmap=bitmap; this.width=width; this.height=height;
      int left=bitmap.getWidth(),right=-1,top=bitmap.getHeight(),bottom=-1;
      int firstRow=Math.max(0,bitmap.getHeight()-(int)Math.ceil(identityHeight*bitmap.getHeight()/height));
      for(int y=firstRow;y<bitmap.getHeight();y++) for(int x=0;x<bitmap.getWidth();x++) {
        if((bitmap.getPixel(x,y)>>>24)>=ALPHA_MIN) {
          left=Math.min(left,x);right=Math.max(right,x);top=Math.min(top,y);bottom=Math.max(bottom,y);
        }
      }
      centerX=right<left?width*.5:(left+right+1)*.5*width/bitmap.getWidth();
      centerY=bottom<top?height*.5:(top+bottom+1)*.5*height/bitmap.getHeight();
    }
    boolean hit(double x, double y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return false;
      int px=Math.min(bitmap.getWidth()-1,(int)(x*bitmap.getWidth()/width));
      int py=Math.min(bitmap.getHeight()-1,(int)(y*bitmap.getHeight()/height));
      return (bitmap.getPixel(px,py) >>> 24) >= ALPHA_MIN;
    }
  }
  static final class Entry {
    final String key, recordId, manager; final Marker marker; Frame frame, applied;
    final List<MarkerBuilder> items;
    Entry(String key,String recordId,Marker marker,Frame frame,List<MarkerBuilder> items,String manager) {
      this.key=key;this.recordId=recordId;this.marker=marker;this.frame=frame;this.items=items;this.manager=manager;
    }
  }
}
