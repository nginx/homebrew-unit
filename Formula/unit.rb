class Unit < Formula
  desc "Dynamic web and application server"
  homepage "https://unit.nginx.org"
  url "https://github.com/nginx/unit.git",
      tag:      "1.34.0",
      revision: "27bde184dedcbf687db2f314c60c037623318a8d"
  head "https://github.com/nginx/unit.git", branch: "master"

  depends_on "rust" => :build
  depends_on "libedit"
  depends_on "openssl@3"
  depends_on "pcre2"
  depends_on "pkg-config"

  resource "njs" do
    url "https://github.com/nginx/njs.git",
        tag:      "0.8.8",
        revision: "78e3edf7505cd04a5df0b7936bcd2d89e95bdda8"
  end

  resource "unitctl" do
    src_repo = "https://github.com/nginx/unit"
    if OS.mac? && Hardware::CPU.intel?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-x86_64-apple-darwin"
      sha256 "3dcc9367bcda782c366d93d86287a30d902c63c5d26b4e80db41f2b5f53449a4"
    elsif OS.mac? && Hardware::CPU.arm?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-aarch64-apple-darwin"
      sha256 "2789f5d39229800cac942324ad9b17832d7bf5b628c232af81bd5af96a20fc85"
    elsif OS.linux? && Hardware::CPU.intel?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-x86_64-unknown-linux-gnu"
      sha256 "b83d2c20bc072eeb05fedb21e536248d105ed5f25e895c0a8bd8bca48dcb0b13"
    elsif OS.linux? && Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-aarch64-unknown-linux-gnu"
      sha256 "f7c98e35b1ac8a946e3c0653e0a34473d25b0ed27152757d5b9f42ef06eb12a4"
    else
      odie "Unsupported architecture"
    end
  end

  # a fix to build on macOS with otel
  patch :DATA

  def install
    resource("unitctl").stage buildpath/"unitctl"
    cd "unitctl" do
      bin.install Dir.glob("unitctl-*").first => "unitctl"
    end

    resource("njs").stage buildpath/"njs"
    cd "njs" do
      system "./configure", "--no-libxml2", "--no-zlib", "--no-openssl", "--no-quickjs"
      system "make", "libnjs", "njs"
      bin.install "build/njs" => "njs-unit"
    end

    ENV.prepend_path "PKG_CONFIG_PATH", buildpath/"njs/build"
    system "./configure",
              "--prefix=#{prefix}",
              "--sbindir=#{bin}",
              "--logdir=#{var}/log",
              "--log=#{var}/log/unit/unit.log",
              "--runstatedir=#{var}/run",
              "--pid=#{var}/run/unit/unit.pid",
              "--control=unix:#{var}/run/unit/control.sock",
              "--modulesdir=#{HOMEBREW_PREFIX}/lib/unit/modules",
              "--statedir=#{var}/state/unit",
              "--tmpdir=/tmp",
              "--openssl",
              "--njs",
              "--otel",
              "--cc-opt=-I#{Formula["openssl"].opt_prefix}/include",
              "--ld-opt=-L#{Formula["openssl"].opt_prefix}/lib"

    system "make"
    system "make", "install", "libunit-install"
    bin.install "tools/setup-unit"
    bin.install "tools/unitc"
  end

  def post_install
    (lib/"unit/modules").mkpath
    (var/"log/unit").mkpath
    (var/"run/unit").mkpath
    (var/"state/unit/certs").mkpath
  end

  service do
    run [opt_bin/"unitd", "--no-daemon"]
    run_type :immediate
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    expected_output = "Hello world!"
    (testpath/"index.html").write expected_output
    (testpath/"unit.conf").write <<~EOS
      {
        "routes": [ { "action": { "share": "#{testpath}/$uri" } } ],
        "listeners": { "*:#{port}": { "pass": "routes" } }
      }
    EOS

    system bin/"unitd", "--log", "#{testpath}/unit.log",
                        "--control", "unix:#{testpath}/control.sock",
                        "--pid", "#{testpath}/unit.pid",
                        "--statedir", "#{testpath}/state"
    sleep 3

    pid = File.open(testpath/"unit.pid").gets.chop.to_i

    system "curl", "-s", "--unix-socket", "#{testpath}/control.sock",
                    "-X", "PUT",
                    "-d", "@#{testpath}/unit.conf", "127.0.0.1/config"

    assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}")
  ensure
    Process.kill("TERM", pid)
  end
end

__END__
index 183e95c7..e5a2d825 100644
--- a/auto/make
+++ b/auto/make
@@ -157,11 +157,12 @@ libnxt:	$NXT_BUILD_DIR/lib/$NXT_LIB_SHARED $NXT_BUILD_DIR/lib/$NXT_LIB_STATIC
 $NXT_BUILD_DIR/lib/$NXT_LIB_SHARED: \$(NXT_LIB_OBJS) \$(NXT_OTEL_LIB_LOC)
 	\$(PP_LD) \$@
 	\$(v)\$(NXT_SHARED_LOCAL_LINK) -o \$@ \$(NXT_LIB_OBJS) \\
-		$NXT_LIBM $NXT_LIBS $NXT_LIB_AUX_LIBS \$(NXT_OTEL_LIB_LOC)
+		\$(NXT_OTEL_LIB_LOC) \\
+		$NXT_LIBM $NXT_LIBS $NXT_LIB_AUX_LIBS
 
-$NXT_BUILD_DIR/lib/$NXT_LIB_STATIC: \$(NXT_LIB_OBJS) \$(NXT_OTEL_LIB_LOC)
+$NXT_BUILD_DIR/lib/$NXT_LIB_STATIC: \$(NXT_LIB_OBJS)
 	\$(PP_AR) \$@
-	\$(v)$NXT_STATIC_LINK \$@ \$(NXT_LIB_OBJS) \$(NXT_OTEL_LIB_LOC)
+	\$(v)$NXT_STATIC_LINK \$@ \$(NXT_LIB_OBJS)
 
 $NXT_BUILD_DIR/lib/$NXT_LIB_UNIT_STATIC: \$(NXT_LIB_UNIT_OBJS) \\
 		$NXT_BUILD_DIR/share/pkgconfig/unit.pc \\
@@ -379,7 +380,8 @@ $NXT_BUILD_DIR/sbin/$NXT_DAEMON:	$NXT_BUILD_DIR/lib/$NXT_LIB_STATIC \\
 	\$(PP_LD) \$@
 	\$(v)\$(NXT_EXEC_LINK) -o \$@ \$(CFLAGS) \\
 		\$(NXT_OBJS) $NXT_BUILD_DIR/lib/$NXT_LIB_STATIC \\
-		$NXT_LIBM $NXT_LIBS $NXT_LIB_AUX_LIBS \$(NXT_OTEL_LIB_LOC)
+		\$(NXT_OTEL_LIB_LOC) \\
+		$NXT_LIBM $NXT_LIBS $NXT_LIB_AUX_LIBS
 
 END
 
diff --git a/auto/otel b/auto/otel
index f23aac3b..dad5590a 100644
--- a/auto/otel
+++ b/auto/otel
@@ -21,26 +21,33 @@ if [ $NXT_OTEL = YES ]; then
 
     $echo -n "  - "
 
-    nxt_feature="OpenSSL library"
-    nxt_feature_run=yes
-    nxt_feature_incs=
-    nxt_feature_libs="-lssl -lcrypto"
-    nxt_feature_test="#include <openssl/ssl.h>
-
-                      int main(void) {
-                          SSL_library_init();
-                          return 0;
-                      }"
-    . auto/feature
-
-    if [ ! $nxt_found = yes ]; then
-        $echo
-        $echo $0: error: OpenTelemetry support requires OpenSSL.
-        $echo
-        exit 1;
-    fi
-
-    NXT_OTEL_LIBS="-lssl -lcrypto"
+    case "$NXT_SYSTEM" in
+        Darwin)
+            NXT_OTEL_LIBS="-framework CoreFoundation -framework Security -framework SystemConfiguration"
+            ;;
+        *)
+            nxt_feature="OpenSSL library"
+            nxt_feature_run=yes
+            nxt_feature_incs=
+            nxt_feature_libs="-lssl -lcrypto"
+            nxt_feature_test="#include <openssl/ssl.h>
+
+                              int main(void) {
+                                  SSL_library_init();
+                                  return 0;
+                              }"
+            . auto/feature
+
+            if [ ! $nxt_found = yes ]; then
+                $echo
+                $echo $0: error: OpenTelemetry support requires OpenSSL.
+                $echo
+                exit 1;
+            fi
+
+            NXT_OTEL_LIBS="-lssl -lcrypto"
+            ;;
+    esac
 
     cat << END >> $NXT_AUTO_CONFIG_H
 
