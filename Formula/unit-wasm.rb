class UnitWasm < Formula
  desc "Ruby module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.32.1.tar.gz"
  sha256 "0e440ef63a3adf9400db978a64fc84e1eb8887f61a04ccff284c3f682fb83ea2"
  head "https://github.com/nginx/unit.git", branch: "master"

  depends_on "rust" => :build
  depends_on "openssl"
  depends_on "unit@1.32.1"
  depends_on "wasmtime"

  # uname -o does not seem to exist on macOS 12.7 currently used in github actions
  # which leads to FTBFS on that target
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
              "--modules=#{HOMEBREW_PREFIX}/lib/unit/modules",
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
diff --git a/auto/modules/wasm-wasi-component b/auto/modules/wasm-wasi-component
index bfb6ffcb..6c8258d7 100644
--- a/auto/modules/wasm-wasi-component
+++ b/auto/modules/wasm-wasi-component
@@ -82,7 +82,7 @@ fi
 $echo " + $NXT_WCM_MODULE module: $NXT_WCM_MOD_NAME"
 
 
-NXT_OS=$(uname -o)
+NXT_OS=$(uname -s)
 
 if [ $NXT_OS = "Darwin" ]; then
 	NXT_CARGO_CMD="cargo rustc --release --manifest-path src/wasm-wasi-component/Cargo.toml -- --emit link=target/release/libwasm_wasi_component.so -C link-args='-undefined dynamic_lookup'"
