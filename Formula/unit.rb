class Unit < Formula
  desc "Dynamic web and application server"
  homepage "https://unit.nginx.org"
  url "https://github.com/nginx/unit.git",
      tag:      "1.34.2",
      revision: "8ab74a8cc929272eb8683d3f6ab4cb406465fd34"
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
      sha256 "370b709f4b2cb76e633afde66de6b6bec75943697061fdc8b0036f8209118d1d"
    elsif OS.mac? && Hardware::CPU.arm?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-aarch64-apple-darwin"
      sha256 "7fc20ce207b5a3e3f6906d658c441347499013d6eaaff782564432783a60fa14"
    elsif OS.linux? && Hardware::CPU.intel?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-x86_64-unknown-linux-gnu"
      sha256 "2dd37ee2c663c1f5394ab7c4de79884327aad98ff4e3164b9f0a1b27859789c4"
    elsif OS.linux? && Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-aarch64-unknown-linux-gnu"
      sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
    else
      odie "Unsupported architecture"
    end
  end

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
