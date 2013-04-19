 maintainer       "AJ Christensen"
maintainer_email "aj@junglist.gen.nz"
license          "Apache 2.0"
description      "Installs and configures Jenkins CI server & slaves"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.6.3"

depends 'runit','~> 1.0.0'
depends 'zzz_sudo','~> 0.0.1'
%w(java apt apache2 git iptables jenkins).each { |cb| depends cb }
%w(yum).each { |cb| recommends cb }
