$LOAD_PATH << File.join(File.dirname(__FILE__),'..','services')
require "test/unit/testcase"
require 'test/unit/ui/console/testrunner'
require "system_agents/krb5_conf"

class TestKrb5Conf < Test::Unit::TestCase
  def setup
    @data_dir = File.join(File.dirname(__FILE__),"data")
    @data1_dir = File.join(File.dirname(__FILE__),"data1")
  end

  def test_reading
    file = SystemAgents::Krb5Conf.new nil
    ret = file.read "_aug_internal" => Augeas::open(@data_dir,nil, Augeas::NO_MODL_AUTOLOAD)
    assert_equal "example.cz", ret["default_domain"]
    assert_equal "kdc.example.cz", ret["kdc"]
    assert_equal "1d", ret["ticket_lifetime"]
    assert_equal "ad.example.cz", ret["trusted_servers"]
  end

  def test_write
    file = SystemAgents::Krb5Conf.new nil
    params	= {
	"_aug_internal" => Augeas::open(@data1_dir,nil, Augeas::NO_MODL_AUTOLOAD),
	"default_domain"	=> "example.de",
	"default_realm"		=> "EXAMPLE.DE"
    }
    ret = file.write params
    assert_equal true, ret["success"]
  end
end

Test::Unit::UI::Console::TestRunner.run(TestKrb5Conf)
