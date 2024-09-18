class Unit < Formula
  desc "Dynamic web and application server"
  homepage "https://unit.nginx.org"
  url "https://github.com/nginx/unit.git",
      tag:      "1.33.0",
      revision: "24ed91f40634372d99f67f0e4e3c2ac0abde81bd"
  head "https://github.com/nginx/unit.git", branch: "master"

  depends_on "openssl@3"
  depends_on "pcre2"
  depends_on "pkg-config"

  resource "njs" do
    url "https://github.com/nginx/njs.git",
        tag:      "0.8.5",
        revision: "9d4bf6c60aa60a828609f64d1b5c50f71bb7ef62"
  end

  resource "unitctl" do
    src_repo = "https://github.com/nginx/unit"
    if OS.mac? && Hardware::CPU.intel?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-x86_64-apple-darwin"
      sha256 "e649163262ec4839eccf2178e7852abf9057c852ace84db7a3d82a7347c3e05e"
    elsif OS.mac? && Hardware::CPU.arm?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-aarch64-apple-darwin"
      sha256 "d49c3da15534b2ed20d70a0fb2ff47d5d0911140229bc1ebabf8a7ec62b01083"
    elsif OS.linux? && Hardware::CPU.intel?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-x86_64-unknown-linux-gnu"
      sha256 "484a70cfc1bb4ccae41ede0f22e6a552adf4cc609280d178b600142a424d5840"
    elsif OS.linux? && Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "#{src_repo}/releases/download/#{Unit.version}/unitctl-#{Unit.version}-aarch64-unknown-linux-gnu"
      sha256 "ca690c1c7d625e507aa110020dbb930569247d91107e1e75a21b1e3b298a4dc7"
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
      system "./configure", "--no-libxml2", "--no-zlib", "--no-openssl"
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
              "--modules=#{HOMEBREW_PREFIX}/lib/unit/modules",
              "--statedir=#{var}/state/unit",
              "--tmpdir=/tmp",
              "--openssl",
              "--njs",
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
