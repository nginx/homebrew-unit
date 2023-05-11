class UnitRuby < Formula
  desc "Ruby module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.30.0.tar.gz"
  sha256 "129ba1b3c4e33dfadbd38683f0634152d8ecf770cacf3af50ee50b5683dc498b"
  head "https://hg.nginx.org/unit", using: :hg

  depends_on "openssl@1.1"
  depends_on "ruby"
  depends_on "unit@1.30.0"

  def install
    system "./configure",
              "--prefix=#{prefix}",
              "--sbindir=#{bin}",
              "--log=#{var}/log/unit/unit.log",
              "--pid=#{var}/run/unit/unit.pid",
              "--control=unix:#{var}/run/unit/control.sock",
              "--modules=#{HOMEBREW_PREFIX}/lib/unit/modules",
              "--statedir=#{var}/state/unit",
              "--tmpdir=/tmp",
              "--openssl",
              "--cc-opt=-I#{Formula["openssl@1.1"].opt_prefix}/include -DNXT_HAVE_ISOLATION_ROOTFS=1",
              "--ld-opt=-L#{Formula["openssl@1.1"].opt_prefix}/lib"

    inreplace "build/autoconf.data",
        "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
        "NXT_MODULESDIR='#{lib}/unit/modules'"

    system "./configure", "ruby", "--module=ruby",
        "--ruby=#{Formula["ruby"].opt_prefix}/bin/ruby"
    system "make", "ruby-install"
  end

  def caveats
    <<~EOS
      Make sure rack gem installed:
        #{Formula["ruby"].opt_prefix}/bin/gem install rack
    EOS
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
          "test": { "type": "ruby", "script": "#{testpath}/oper.ru" }
        }
      }
    EOS
    (testpath/"oper.ru").write <<~EOS
      app = Proc.new do |env|
          ['200', { 'Content-Type' => 'text/plain', }, ["#{expected_output}"]]
      end

      run app
    EOS
    (testpath/"state/certs").mkpath

    system "#{HOMEBREW_PREFIX}/bin/unitd", "--log", "#{testpath}/unit.log",
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
