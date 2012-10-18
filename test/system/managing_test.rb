require 'assert'
require 'ostruct'

class ManagingTest < Assert::Context
  desc "Using Sanford's manager"

  # preserve the global service hosts configuration, no matter how we
  # manipulate it
  class PreserveServiceHosts < ManagingTest
    setup do
      @previous_hosts = Sanford::Hosts.set.dup
    end
    teardown do
      Sanford::Hosts.instance_variable_set("@set", @previous_hosts)
    end
  end

  class CallTest < ManagingTest
    desc "to run a service host"
    setup do
      @host = OpenStruct.new({ :name => 'fake_host', :pid_dir => 'pid_dir' })
      Sanford::Hosts.add(@host)
      options = {
        :ARGV     => [ 'run' ],
        :dir      => @host.pid_dir,
        :dir_mode => :normal
      }
      ::Daemons.expects(:run_proc).with(@host.name, options)
    end
    teardown do
      ::Daemons.unstub(:run_proc)
    end

    should "find a service host, build a manager and call the action on it" do
      assert_nothing_raised do
        Sanford::Manager.call('fake_host', :run)
        Mocha::Mockery.instance.verify
      end
    end
  end

  class BadHostTest < ManagingTest
    desc "with a bad host name"

    should "raise an exception when a service host can't be found" do
      assert_raises(Sanford::NoServiceHost) do
        Sanford::Manager.call('not_a_real_host', :run)
      end
    end
  end

  class NoHostsTest < ManagingTest
    desc "with no hosts"
    setup do
      Sanford::Hosts.clear
    end

    should "raise an exception when there aren't any service hosts" do
      assert_raises(Sanford::NoServiceHost) do
        Sanford::Manager.call('doesnt_matter', :run)
      end
    end
  end

end
