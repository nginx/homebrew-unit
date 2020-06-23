class UnitPhp < Formula
  desc "PHP module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.18.0.tar.gz"
  sha256 "43ffa7b935b081a5e99c0cc875b823daf4f20fc1938cd3483dc7bffaf15ec089"
  head "https://hg.nginx.org/unit", :using => :hg

  depends_on "openssl@1.1"
  depends_on "php-embed"
  depends_on "unit@1.18.0"

  patch :DATA

  def install
    system "./configure",
              "--prefix=#{prefix}",
              "--sbindir=#{bin}",
              "--log=#{var}/log/unit/unit.log",
              "--pid=#{var}/run/unit/unit.pid",
              "--control=unix:#{var}/run/unit/control.sock",
              "--modules=#{HOMEBREW_PREFIX}/lib/unit/modules",
              "--state=#{var}/state/unit",
              "--tmp=/tmp",
              "--openssl",
              "--cc-opt=-I#{Formula["openssl@1.1"].opt_prefix}/include",
              "--ld-opt=-L#{Formula["openssl@1.1"].opt_prefix}/lib"

    inreplace "build/autoconf.data",
        "NXT_MODULES='#{HOMEBREW_PREFIX}/lib/unit/modules'",
        "NXT_MODULES='#{lib}/unit/modules'"

    system "./configure", "php"
    system "make", "php-install"
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    expected_output = "Hello world!"
    (testpath/"unit.conf").write <<~EOS
      {
        "listeners": { "*:#{port}": { "pass": "applications/test" } },
        "applications": {
          "test": { "type": "php", "root": "#{testpath}" }
        }
      }
    EOS
    (testpath/"index.php").write <<~EOS
      <?php print("#{expected_output}"); ?>
    EOS
    (testpath/"state/certs").mkpath

    system "#{HOMEBREW_PREFIX}/bin/unitd", "--log", "#{testpath}/unit.log",
                        "--control", "unix:#{testpath}/control.sock",
                        "--pid", "#{testpath}/unit.pid",
                        "--state", "#{testpath}/state"
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
diff --git a/src/nxt_php_sapi.c b/src/nxt_php_sapi.c
--- a/src/nxt_php_sapi.c
+++ b/src/nxt_php_sapi.c
@@ -707,7 +707,9 @@ nxt_php_dirname(const nxt_str_t *file, n
 {
     size_t  length;
 
-    nxt_assert(file->length > 0 && file->start[0] == '/');
+    if (file->length == 0 || file->start[0] != '/') {
+        return NXT_ERROR;
+    }
 
     length = file->length;
 
