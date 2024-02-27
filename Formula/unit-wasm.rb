class UnitWasm < Formula
  desc "Ruby module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.32.0.tar.gz"
  sha256 "4b5e9be3f3990fceabf06292c2b7853667aceb71fd8de5dc67cb7fb05d247a20"
  head "https://github.com/nginx/unit.git", branch: "master"

  depends_on "openssl"
  depends_on "unit@1.32.0"
  depends_on "wasmtime"

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
  end
end
