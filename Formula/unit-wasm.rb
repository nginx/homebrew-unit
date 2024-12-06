class UnitWasm < Formula
  desc "Ruby module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://github.com/nginx/unit.git",
      tag:      "1.33.0",
      revision: "24ed91f40634372d99f67f0e4e3c2ac0abde81bd"
  head "https://github.com/nginx/unit.git", branch: "master"

  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "unit@1.33.0"
  depends_on "wasmtime"

  # a fix to build with current wasmtime
  patch :DATA

  def install
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
              "--cc-opt=-I#{Formula["openssl"].opt_prefix}/include -DNXT_HAVE_ISOLATION_ROOTFS=1",
              "--ld-opt=-L#{Formula["openssl"].opt_prefix}/lib"

    inreplace "build/autoconf.data",
        "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
        "NXT_MODULESDIR='#{lib}/unit/modules'"

    system "./configure", "wasm", "--module=wasm",
      "--include-path=#{HOMEBREW_PREFIX}/usr/include/",
      "--lib-path=#{HOMEBREW_PREFIX}/lib/"
    system "make", "wasm-install"

    system "./configure", "wasm-wasi-component"
    system "make", "wasm-wasi-component-install"
  end
end

__END__
commit 6cc4d706fba2577babc076ad0d2ef145c0c648d7
Author: Sergey A. Osokin <sergey.osokin@nginx.com>
Date:   Fri Nov 22 22:13:18 2024 -0500

    wasm: Fix build with wasmtime 27.0.0
    
    Wasmtime 27.0.0 adjusted the C API to start flowing through the
    directory and file permission bits of the underlying rust
    wasi_config_preopen_dir() implementation.
    
    The directory permissions control whether a directory is read-only or
    whether you can create/modify files within.
    
    You always need at least WASMTIME_WASI_DIR_PERMS_READ.
    
    The file permissions control whether you can read or read/write files.
    
    WASMTIME_WASI_FILE_PERMS_WRITE seems to imply
    WASMTIME_WASI_FILE_PERMS_READ (but we add both just to make it clear
    what we want)
    
    [ Permissions tweak and commit message - Andrew ]
    Signed-off-by: Andrew Clayton <a.clayton@nginx.com>

diff --git a/src/wasm/nxt_rt_wasmtime.c b/src/wasm/nxt_rt_wasmtime.c
index bf0b0a0f..64ef775d 100644
--- a/src/wasm/nxt_rt_wasmtime.c
+++ b/src/wasm/nxt_rt_wasmtime.c
@@ -281,7 +281,13 @@ nxt_wasmtime_wasi_init(const nxt_wasm_ctx_t *ctx)
     wasi_config_inherit_stderr(wasi_config);
 
     for (dir = ctx->dirs; dir != NULL && *dir != NULL; dir++) {
+#if defined(WASMTIME_VERSION_MAJOR) && (WASMTIME_VERSION_MAJOR >= 27)
+        wasi_config_preopen_dir(wasi_config, *dir, *dir,
+                WASMTIME_WASI_DIR_PERMS_READ|WASMTIME_WASI_DIR_PERMS_WRITE,
+                WASMTIME_WASI_FILE_PERMS_READ|WASMTIME_WASI_FILE_PERMS_WRITE);
+#else
         wasi_config_preopen_dir(wasi_config, *dir, *dir);
+#endif
     }
 
     error = wasmtime_context_set_wasi(rt_ctx->ctx, wasi_config);
