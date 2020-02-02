require "formula"

class Flam3 < Formula
  homepage "https://github.com/scottdraves/flam3"
  url "https://github.com/scottdraves/flam3/archive/v3.0.1.tar.gz"
  sha256 "fc9e936fb5c6cfa05afc94cf9b991259cb9f9d40c2681d2761e5a06dd5afdc9c"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "pkg-config" => :build
  depends_on "libpng"
  depends_on "jpeg"

  # patches
  # - to avoid seg fault (cfr https://code.google.com/p/flam3/issues/detail?id=10)
  # - to support libpng >= 1.5 instead of 1.2 (https://code.google.com/p/flam3/source/detail?r=164)
  patch :DATA

  def install
    Dir.chdir("src")
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    # write down test file (this is test.flam3, which is distributed with the flam3 source code)
    (testpath/'test.flam3').write <<-EOS.undent
      <test>
        <flame time="0" palette="15" size="640 480" center="0 0" scale="240" zoom="0" oversample="1" filter="1" quality="10" background="0 0 0" brightness="4" gamma="4" vibrancy="1" hue="0.22851">
          <xform weight="0.25" color="1" spherical="1" coefs="-0.681206 -0.0779465 0.20769 0.755065 -0.0416126 -0.262334"/>
          <xform weight="0.25" color="0.66" spherical="1" coefs="0.953766 0.48396 0.43268 -0.0542476 0.642503 -0.995898"/>
          <xform weight="0.25" color="0.33" spherical="1" coefs="0.840613 -0.816191 0.318971 -0.430402 0.905589 0.909402"/>
          <xform weight="0.25" color="0" spherical="1" coefs="0.960492 -0.466555 0.215383 -0.727377 -0.126074 0.253509"/>
        </flame>
        <flame time="100" palette="29" size="640 480" center="0 0" scale="240" zoom="0" oversample="1" filter="1" quality="10" background="0 0 0" brightness="4" gamma="4" vibrancy="1" hue="0.147038">
          <xform weight="0.25" color="1" spherical="1" coefs="-0.357523 0.774667 0.397446 0.674359 -0.730708 0.812876"/>
          <xform weight="0.25" color="0.66" spherical="1" coefs="-0.69942 0.141688 -0.743472 0.475451 -0.336206 0.0958816"/>
          <xform weight="0.25" color="0.33" spherical="1" coefs="0.0738451 -0.349212 -0.635205 0.262572 -0.398985 -0.736904"/>
          <xform weight="0.25" color="0" spherical="1" coefs="0.992697 0.433488 -0.427202 -0.339112 -0.507145 0.120765"/>
        </flame>
      </test>
    EOS
    # try to render the 2 flames (should produce 00000.png and 00001.png)
    system "flam3-render < test.flam3"
    # check if 2 pictures were indeed generated
    system "test -f 00000.png -a -f 00001.png"
  end
end

__END__
# patch starts here
diff --git a/src/rect.c b/src/rect.c
index 4704f48..aa4d4eb 100644
--- a/src/rect.c
+++ b/src/rect.c
@@ -559,7 +559,6 @@ static int render_rectangle(flam3_frame *spec, void *out,
    pthread_attr_t pt_attr;
    pthread_t *myThreads=NULL;
 #endif
-   int thread_status;
    int thi;
    time_t tstart,tend;
    double sumfilt;
@@ -894,7 +893,7 @@ static int render_rectangle(flam3_frame *spec, void *out,

          /* Wait for them to return */
          for (thi=0; thi < spec->nthreads; thi++)
-            pthread_join(myThreads[thi], (void **)&thread_status);
+            pthread_join(myThreads[thi], (void **)0);

          #if defined(USE_LOCKS)
          pthread_mutex_destroy(&fic.bucket_mutex);
@@ -1025,7 +1024,7 @@ static int render_rectangle(flam3_frame *spec, void *out,

          /* Wait for them to return */
          for (thi=0; thi < spec->nthreads; thi++)
-            pthread_join(myThreads[thi], (void **)&thread_status);
+            pthread_join(myThreads[thi], (void **)0);

          free(myThreads);
 #else
diff --git a/src/png.c b/src/png.c
index 23ff489..c3d1d36 100755
--- a/src/png.c
+++ b/src/png.c
@@ -142,7 +142,7 @@ unsigned char *read_png(FILE *ifp, int *width, int *height) {
   }
   if (setjmp(png_jmpbuf(png_ptr))) {
      if (png_image) {
-	 for (y = 0 ; y < info_ptr->height ; y++)
+	 for (y = 0 ; y < png_get_image_height(png_ptr, info_ptr) ; y++)
 	     free (png_image[y]);
 	 free (png_image);
      }
@@ -161,19 +161,20 @@ unsigned char *read_png(FILE *ifp, int *width, int *height) {
   png_set_sig_bytes (png_ptr, SIG_CHECK_SIZE);
   png_read_info (png_ptr, info_ptr);

-  if (8 != info_ptr->bit_depth) {
+  if (8 != png_get_bit_depth(png_ptr, info_ptr)) {
     fprintf(stderr, "bit depth type must be 8, not %d.\n",
-	    info_ptr->bit_depth);
+	    png_get_bit_depth(png_ptr, info_ptr));
     return 0;
   }

-  *width = info_ptr->width;
-  *height = info_ptr->height;
+  *width = png_get_image_width(png_ptr, info_ptr);
+  *height = png_get_image_height(png_ptr, info_ptr);
+  png_byte color_type = png_get_color_type(png_ptr, info_ptr);
   p = q = malloc(4 * *width * *height);
-  png_image = (png_byte **)malloc (info_ptr->height * sizeof (png_byte*));
+  png_image = (png_byte **)malloc (*height * sizeof (png_byte*));

-  linesize = info_ptr->width;
-  switch (info_ptr->color_type) {
+  linesize = *width;
+  switch (color_type) {
     case PNG_COLOR_TYPE_RGB:
       linesize *= 3;
       break;
@@ -182,21 +183,21 @@ unsigned char *read_png(FILE *ifp, int *width, int *height) {
       break;
   default:
     fprintf(stderr, "color type must be RGB or RGBA not %d.\n",
-	    info_ptr->color_type);
+	    color_type);
     return 0;
   }

-  for (y = 0 ; y < info_ptr->height ; y++) {
+  for (y = 0 ; y < *height ; y++) {
     png_image[y] = malloc (linesize);
   }
   png_read_image (png_ptr, png_image);
   png_read_end (png_ptr, info_ptr);

-  for (y = 0 ; y < info_ptr->height ; y++) {
+  for (y = 0 ; y < *height ; y++) {
     unsigned char *s = png_image[y];
-    for (x = 0 ; x < info_ptr->width ; x++) {
+    for (x = 0 ; x < *width ; x++) {

-      switch (info_ptr->color_type) {
+      switch (color_type) {
       case PNG_COLOR_TYPE_RGB:
 	p[0] = s[0];
 	p[1] = s[1];
@@ -217,7 +218,7 @@ unsigned char *read_png(FILE *ifp, int *width, int *height) {
     }
   }

-  for (y = 0 ; y < info_ptr->height ; y++)
+  for (y = 0 ; y < *height ; y++)
     free (png_image[y]);
   free (png_image);
   png_destroy_read_struct (&png_ptr, &info_ptr, (png_infopp)NULL);
