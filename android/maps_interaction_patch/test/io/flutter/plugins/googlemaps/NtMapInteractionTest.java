package io.flutter.plugins.googlemaps;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;
import android.content.Context;
import android.graphics.*;
import android.graphics.drawable.ShapeDrawable;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.Projection;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.maps.android.clustering.ClusterManager;
import com.google.maps.android.clustering.algo.StaticCluster;
import com.google.maps.android.clustering.view.DefaultClusterRenderer;
import com.google.maps.android.ui.IconGenerator;
import io.flutter.plugin.common.BinaryMessenger;
import java.lang.reflect.Field;
import java.util.*;
import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class NtMapInteractionTest {
  BinaryMessenger messenger;
  Context context;
  GoogleMap map;
  NtMapInteraction nt;
  Set<MarkerBuilder> current;
  @Before public void setup() {
    context = RuntimeEnvironment.getApplication();
    map = mock(GoogleMap.class);
    Projection projection = mock(Projection.class);
    when(map.getProjection()).thenReturn(projection);
    when(projection.toScreenLocation(any())).thenAnswer(i -> {
      LatLng p=i.getArgument(0); return new Point((int)p.longitude, (int)p.latitude);
    });
    current = new HashSet<>();
    messenger = mock(BinaryMessenger.class);
    nt = new NtMapInteraction(1, context, messenger, map, current::contains, () -> {});
  }
  Bitmap circle() {
    Bitmap b=Bitmap.createBitmap(96,96,Bitmap.Config.ARGB_8888);
    Paint p=new Paint();p.setColor(Color.BLUE);
    for (int y=0;y<96;y++) for (int x=0;x<96;x++) if ((x-48)*(x-48)+(y-48)*(y-48)<=35*35) b.setPixel(x,y,Color.BLUE);return b;
  }
  MarkerBuilder builder(String id) {
    MarkerBuilder b=mock(MarkerBuilder.class);when(b.markerId()).thenReturn(id);when(b.clusterManagerId()).thenReturn("maps-people");when(b.getPosition()).thenReturn(new LatLng(0,0));current.add(b);return b;
  }
  @SuppressWarnings("unchecked")
  void entry(String id,int x,int centerY,float z) throws Exception {
    Marker marker=mock(Marker.class);
    when(marker.getId()).thenReturn(id);when(marker.getPosition()).thenReturn(new LatLng(centerY+48,x));
    when(map.getProjection().toScreenLocation(marker.getPosition())).thenReturn(new Point(x,centerY+48));when(marker.isVisible()).thenReturn(true);when(marker.getAlpha()).thenReturn(1f);when(marker.getZIndex()).thenReturn(z);
    Field field=NtMapInteraction.class.getDeclaredField("entries");field.setAccessible(true);
    ((Map<String,NtMapInteraction.Entry>)field.get(nt)).put(id,new NtMapInteraction.Entry(id,id,marker,
      new NtMapInteraction.Frame(circle(),96,96),List.of(builder(id)),null));
  }
  @Test public void transparentCornersAndOutsidePixelsAreNotTargets() {
    NtMapInteraction.Frame frame=new NtMapInteraction.Frame(circle(),34,34);
    assertTrue(frame.hit(17,17));assertFalse(frame.hit(0,0));assertFalse(frame.hit(2,17));
    assertFalse(frame.hit(34,17));assertFalse(frame.hit(-1,17));
  }
  @Test public void upperAndLowerGroupsResolveByActualVisiblePixel() throws Exception {
    entry("upper-four",70,0,0);entry("lower-four",70,60,0);
    assertEquals("upper-four",nt.resolve(70,0).key);
    assertEquals("lower-four",nt.resolve(70,60).key);
    assertNull(nt.resolve(110,60));
  }
  @Test public void contactAndBusRemainIndependentAndDoNotCycle() throws Exception {
    entry("contact:A",70,0,0);entry("place:bus",115,0,0);
    for(int i=0;i<5;i++) {
      assertEquals("contact:A",nt.resolve(70,0).key);
      assertEquals("place:bus",nt.resolve(115,0).key);
    }
    assertNull(nt.resolve(115,40));
  }
  @Test public void selectedZOrderCannotStealAnotherVisibleCenter() throws Exception {
    entry("contact:A",70,0,20);entry("contact:B",90,0,0);
    assertEquals("contact:B",nt.resolve(90,0).key);
    assertEquals("contact:A",nt.resolve(70,0).key);
  }
  @Test public void staleRenderedMembersCannotWin() throws Exception {
    entry("old",70,0,20);current.clear();
    entry("latest",70,0,0);
    assertEquals("latest",nt.resolve(70,0).key);
  }
  StaticCluster<MarkerBuilder> cluster(String...ids) {
    StaticCluster<MarkerBuilder> cluster=new StaticCluster<>(new LatLng(0,0));
    for(String id:ids)cluster.add(builder(id));return cluster;
  }
  @Test public void threeExceptionAppliesOnlyToExactSelectionRemainder() throws Exception {
    Field f=NtMapInteraction.class.getDeclaredField("remainder");f.setAccessible(true);f.set(nt,Set.of("A","C","D"));
    assertTrue(nt.remainder(cluster("A","C","D")));
    assertFalse(nt.remainder(cluster("E","F","G")));
    assertFalse(nt.remainder(cluster("A","C")));
    ClusterManagersController controller=new ClusterManagersController(mock(MapsCallbackApi.class),context,PlatformMarkerType.values()[0]);
    controller.ntInteraction=nt;
    @SuppressWarnings("unchecked") ClusterManager<MarkerBuilder> manager=mock(ClusterManager.class);
    ClusterManagersController.MarkerClusterRenderer<MarkerBuilder> renderer=new ClusterManagersController.MarkerClusterRenderer<>(context,map,manager,controller);
    assertEquals(4,renderer.getMinClusterSize());
    assertTrue(renderer.shouldRenderAsCluster(cluster("A","C","D")));
    assertFalse(renderer.shouldRenderAsCluster(cluster("E","F","G")));
    f.set(nt,Collections.emptySet());
    assertFalse(renderer.shouldRenderAsCluster(cluster("A","C","D")));
    assertTrue(renderer.shouldRenderAsCluster(cluster("A","B","C","D")));
  }
  @org.robolectric.annotation.GraphicsMode(org.robolectric.annotation.GraphicsMode.Mode.NATIVE)
  @Test public void countBitmapKeepsUpstreamNativePixels() throws Exception {
    @SuppressWarnings("unchecked") ClusterManager<MarkerBuilder> manager=mock(ClusterManager.class);
    DefaultClusterRenderer<MarkerBuilder> original=new DefaultClusterRenderer<>(context,map,manager);
    Field circle=DefaultClusterRenderer.class.getDeclaredField("mColoredCircleBackground");circle.setAccessible(true);
    ((ShapeDrawable)circle.get(original)).getPaint().setColor(original.getColor(4));
    Field gen=DefaultClusterRenderer.class.getDeclaredField("mIconGenerator");gen.setAccessible(true);
    Bitmap expected=((IconGenerator)gen.get(original)).makeIcon("4");
    Bitmap actual=nt.countBitmap("4",original.getColor(4),original.getClusterTextAppearance(4));
    assertTrue("Native count artwork must match upstream pixels",expected.sameAs(actual));
    assertTrue("Count bitmap must contain real painted pixels", (actual.getPixel(actual.getWidth()/2,actual.getHeight()/2) >>> 24) > 0);
  }
  @Test public void nativeClusterClickConsumesDefaultCameraAction() {
    ClusterManagersController controller=new ClusterManagersController(mock(MapsCallbackApi.class),context,PlatformMarkerType.values()[0]);
    assertTrue(controller.onClusterClick(cluster("A","B","C","D")));
    verifyNoInteractions(map);
  }

  @Test public void gestureBoundaryCancelsSdkTapAndEmitsChosenId() throws Exception {
    entry("contact:A",70,0,20);entry("place:bus",110,0,0);
    Field enabled=NtMapInteraction.class.getDeclaredField("enabled");enabled.setAccessible(true);enabled.set(nt,true);
    Field trace=NtMapInteraction.class.getDeclaredField("trace");trace.setAccessible(true);trace.set(nt,true);
    NtPrecisionMapView view=new NtPrecisionMapView(context,new com.google.android.gms.maps.GoogleMapOptions());
    view.interaction=nt;
    android.view.MotionEvent down=android.view.MotionEvent.obtain(1000,1000,0,110,0,0);
    android.view.MotionEvent up=android.view.MotionEvent.obtain(1000,1040,1,110,0,0);
    view.dispatchTouchEvent(down);assertTrue(view.dispatchTouchEvent(up));down.recycle();up.recycle();
    org.mockito.ArgumentCaptor<java.nio.ByteBuffer> sent=org.mockito.ArgumentCaptor.forClass(java.nio.ByteBuffer.class);
    verify(messenger).send(eq("nexttransfer/maps_interaction/1"),sent.capture(),any());
    java.nio.ByteBuffer bytes=sent.getValue();bytes.flip();
    io.flutter.plugin.common.MethodCall call=io.flutter.plugin.common.StandardMethodCodec.INSTANCE.decodeMethodCall(bytes);
    assertEquals("tap",call.method);assertEquals("place:bus",call.argument("recordId"));
    for(org.robolectric.shadows.ShadowLog.LogItem log:org.robolectric.shadows.ShadowLog.getLogsForTag("NTMapTiming"))System.out.println(log.msg);
  }
  @Test public void staleSelectionCommandsCannotRestoreOlderRemainder() throws Exception {
    org.mockito.ArgumentCaptor<BinaryMessenger.BinaryMessageHandler> handler=org.mockito.ArgumentCaptor.forClass(BinaryMessenger.BinaryMessageHandler.class);
    verify(messenger).setMessageHandler(eq("nexttransfer/maps_interaction/1"),handler.capture());
    for(int gen:new int[]{3,1}) {
      java.nio.ByteBuffer bytes=io.flutter.plugin.common.StandardMethodCodec.INSTANCE.encodeMethodCall(
        new io.flutter.plugin.common.MethodCall("selection",Map.of("generation",gen,"remainderIds",gen==3?List.of("A","C","D"):List.of("old","stale"))));
      bytes.flip();handler.getValue().onMessage(bytes,reply -> {});
    }
    assertTrue(nt.remainder(cluster("A","C","D")));
    assertFalse(nt.remainder(cluster("old","stale")));
  }


  @Test public void directSelectionInfersOnlyItsRemainderWithoutMutatingLiveAlgorithm() {
    ClusterManagersController controller=new ClusterManagersController(mock(MapsCallbackApi.class),context,PlatformMarkerType.values()[0]);
    controller.ntInteraction=nt;
    controller.init(map,mock(com.google.maps.android.collections.MarkerManager.class));
    when(map.getCameraPosition()).thenReturn(new com.google.android.gms.maps.model.CameraPosition(new LatLng(0,0),10,0,0));
    com.google.maps.android.clustering.algo.NonHierarchicalDistanceBasedAlgorithm<MarkerBuilder> live=new com.google.maps.android.clustering.algo.NonHierarchicalDistanceBasedAlgorithm<>();
    MarkerBuilder selected=builder("contact:B");
    int index=1;for(String id:List.of("contact:A","contact:C","contact:D")) {
      MarkerBuilder item=builder(id);when(item.getPosition()).thenReturn(new LatLng(.0001*index++,0));live.addItem(item);
    }
    @SuppressWarnings("unchecked") ClusterManager<MarkerBuilder> manager=mock(ClusterManager.class);
    when(manager.getAlgorithm()).thenReturn(live);
    controller.clusterManagerIdToManager.put("maps-people",manager);
    controller.ntSelectedMarker=() -> selected;
    nt.selectedOwnerId="contact:B";nt.selectedManagerId="maps-people";nt.inferRemainder=true;
    controller.ntRecluster();
    assertTrue(nt.remainder(cluster("contact:A","contact:C","contact:D")));
    assertEquals(3,live.getItems().size());assertFalse(live.getItems().contains(selected));
    assertFalse(nt.remainder(cluster("other:A","other:C","other:D")));
  }


  @Test public void panAndLongPressDoNotBecomeMarkerTaps() throws Exception {
    Field enabled=NtMapInteraction.class.getDeclaredField("enabled");enabled.setAccessible(true);enabled.set(nt,true);
    NtPrecisionMapView view=new NtPrecisionMapView(context,new com.google.android.gms.maps.GoogleMapOptions());view.interaction=nt;
    clearInvocations(messenger);
    for(long duration:new long[]{100,android.view.ViewConfiguration.getLongPressTimeout()+1}) {
      android.view.MotionEvent down=android.view.MotionEvent.obtain(1000,1000,0,10,10,0);
      view.dispatchTouchEvent(down);down.recycle();
      if(duration==100){android.view.MotionEvent move=android.view.MotionEvent.obtain(1000,1020,2,200,10,0);view.dispatchTouchEvent(move);move.recycle();}
      android.view.MotionEvent up=android.view.MotionEvent.obtain(1000,1000+duration,1,10,10,0);view.dispatchTouchEvent(up);up.recycle();
    }
    verifyNoInteractions(messenger);
  }


  @Test public void separatedRemainderCanvasAddsNoInvisibleHitRegion() {
    Bitmap bitmap=Bitmap.createBitmap(288,96,Bitmap.Config.ARGB_8888);
    for(int y=0;y<96;y++)for(int x=0;x<96;x++)if((x-48)*(x-48)+(y-48)*(y-48)<=41*41)bitmap.setPixel(x,y,Color.BLUE);
    NtMapInteraction.Frame frame=new NtMapInteraction.Frame(bitmap,102,34,34);
    assertTrue(frame.hit(17,17));assertFalse(frame.hit(51,17));assertFalse(frame.hit(85,17));
    assertEquals(17.177,frame.centerX,.2);
  }

}
