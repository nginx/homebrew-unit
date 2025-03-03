class UnitWasm < Formula
  desc "Ruby module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://github.com/nginx/unit.git",
      tag:      "1.34.2",
      revision: "8ab74a8cc929272eb8683d3f6ab4cb406465fd34"
  head "https://github.com/nginx/unit.git", branch: "master"

  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "unit@1.34.2"
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
