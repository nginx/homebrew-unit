class UnitPython3 < Formula
  desc "Python3 module for Unit application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.31.1.tar.gz"
  sha256 "9df604d49cb57ac0103202efb0f9373e3e48a7dd888c94af10d4f96ccded7d71"
  head "https://hg.nginx.org/unit", using: :hg

  depends_on "openssl"
  depends_on "python3"
  depends_on "unit@1.31.1"

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
              "--cc-opt=-I#{Formula["openssl"].opt_prefix}/include",
              "--ld-opt=-L#{Formula["openssl"].opt_prefix}/lib"

    inreplace "build/autoconf.data",
        "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
        "NXT_MODULESDIR='#{lib}/unit/modules'"

    system "./configure", "python",
        "--module=python3",
        "--config=python3-config"
    system "make", "python3-install"
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
          "test": { "type": "python 3", "path": "#{testpath}", "module": "wsgi" }
        }
      }
    EOS
    (testpath/"wsgi.py").write <<~EOS
      def application(environ, start_response):
          start_response('200 OK', [('Content-type', 'text/plain')])
          return b"#{expected_output}"
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
