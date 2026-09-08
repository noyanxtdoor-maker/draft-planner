package io.flutter.plugins.googlemaps;

import android.content.Context;
import android.view.MotionEvent;
import android.view.ViewConfiguration;
import com.google.android.gms.maps.GoogleMapOptions;
import com.google.android.gms.maps.MapView;

/** Maps-only tap interception. Pan, pinch and long press remain SDK gestures. */
final class NtPrecisionMapView extends MapView {
  NtMapInteraction interaction;
  private float downX, downY;
  private long downTime;
  private boolean tap;
  private final int slop;

  NtPrecisionMapView(Context context, GoogleMapOptions options) {
    super(context, options);
    slop = ViewConfiguration.get(context).getScaledTouchSlop();
  }

  @Override public boolean dispatchTouchEvent(MotionEvent event) {
    switch (event.getActionMasked()) {
      case MotionEvent.ACTION_DOWN:
        downX = event.getX(); downY = event.getY();
        downTime = event.getEventTime(); tap = true; break;
      case MotionEvent.ACTION_POINTER_DOWN:
      case MotionEvent.ACTION_CANCEL:
        tap = false; break;
      case MotionEvent.ACTION_MOVE:
        if (Math.hypot(event.getX() - downX, event.getY() - downY) > slop) tap = false;
        break;
      case MotionEvent.ACTION_UP:
        boolean completedTap = tap && event.getPointerCount() == 1
            && event.getEventTime() - downTime < ViewConfiguration.getLongPressTimeout()
            && Math.hypot(event.getX() - downX, event.getY() - downY) <= slop;
        tap = false;
        if (completedTap && interaction != null && interaction.enabled()) {
          // Cancel BEFORE the SDK sees UP: it cannot cycle to another marker,
          // open an info window, or execute default click camera centering.
          MotionEvent cancel = MotionEvent.obtain(event);
          cancel.setAction(MotionEvent.ACTION_CANCEL);
          super.dispatchTouchEvent(cancel);
          cancel.recycle();
          interaction.tap(event.getX(), event.getY());
          return true;
        }
        break;
      default: break;
    }
    return super.dispatchTouchEvent(event);
  }
}
