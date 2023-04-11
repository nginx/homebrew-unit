class Unit < Formula
  desc "Dynamic web and application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.29.1.tar.gz"
  sha256 "7d756cff8c1a40b38c313fdbe8748333ffce034a3916fa1b502d63cc10623437"
  head "https://hg.nginx.org/unit", using: :hg

  depends_on "pkg-config"
  depends_on "openssl@1.1"
  depends_on "pcre2"

  resource "njs" do
    url "https://hg.nginx.org/njs/archive/0.7.10.tar.gz"
    sha256 "56f4aa35101a98ed4d76edee824f8e20b4e784abf4dc5433441ea08f12e7388f"
  end

  def install
    resource("njs").stage buildpath/"njs"
    cd "njs" do
      system "./configure", "--no-libxml2"
      system "make", "libnjs", "njs"
      bin.install "build/njs" => "njs-unit"
    end

    ENV.prepend_path "PKG_CONFIG_PATH", buildpath/"njs/build"
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
              "--njs",
              "--cc-opt=-I#{Formula["openssl@1.1"].opt_prefix}/include",
              "--ld-opt=-L#{Formula["openssl@1.1"].opt_prefix}/lib"

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
