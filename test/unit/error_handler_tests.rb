require 'assert'

class Sanford::ErrorHandler

  class BaseTests < Assert::Context
    desc "Sanford::ErrorHandler"
    setup do
      @exception = RuntimeError.new('test')
      @host_data = Sanford::HostData.new(EmptyHost, { :ip => "localhost", :port => 8000 })
      @error_handler = Sanford::ErrorHandler.new(@exception, @host_data)
    end
    subject{ @error_handler }

    should have_instance_methods :exception, :host_data, :request, :run

    should "return a Sanford::Protocol::Response with `run`" do
      assert_instance_of Sanford::Protocol::Response, subject.run
    end

    def generate_exception(exception_class, message = nil)
      exception = nil
      begin
        raise exception_class, message
      rescue Exception => exception
      end
      exception
    end

  end

  class ResponseFromProcTests < BaseTests
    desc "generating a respone from an error proc"
    setup do
      @host_defaults = { :ip => "localhost", :port => 8000 }
    end

    should "use the return-value of the error proc if it is a protocol response" do
      error_proc = proc do |exception, host_data, request|
        Sanford::Protocol::Response.new([ 567, 'custom message'], 'custom data')
      end
      host_data = Sanford::HostData.new(EmptyHost, @host_defaults.merge({
        :error_procs => [ error_proc ]
      }))
      response = Sanford::ErrorHandler.new(@exception, host_data).run

      assert_equal 567,               response.code
      assert_equal 'custom message',  response.status.message
      assert_equal 'custom data',     response.data
    end

    should "use an integer returned by the error proc to generate a protocol response" do
      host_data = Sanford::HostData.new(EmptyHost, @host_defaults.merge({
        :error_procs => [ proc{ 345 } ]
      }))
      response = Sanford::ErrorHandler.new(@exception, host_data).run

      assert_equal 345, response.code
      assert_nil response.status.message
      assert_nil response.data
    end

    should "use a symbol returned by the error proc to generate a protocol response" do
      host_data = Sanford::HostData.new(EmptyHost, @host_defaults.merge({
        :error_procs => [ proc{ :not_found } ]
      }))
      response = Sanford::ErrorHandler.new(@exception, host_data).run

      assert_equal 404, response.code
      assert_nil response.status.message
      assert_nil response.data
    end

    should "use the default behavior if the error proc doesn't return a valid response result" do
      host_data = Sanford::HostData.new(EmptyHost, @host_defaults.merge({
        :error_procs => [ proc{ true } ]
      }))
      response = Sanford::ErrorHandler.new(@exception, host_data).run

      assert_equal 500,                             response.code
      assert_equal 'An unexpected error occurred.', response.status.message
    end

    should "use the default behavior for an exception raised by the error proc " \
      "and ignore the original exception" do
      host_data = Sanford::HostData.new(EmptyHost, @host_defaults.merge({
        :error_procs => [ proc{ raise Sanford::NotFoundError } ]
      }))
      response = Sanford::ErrorHandler.new(@exception, host_data).run

      assert_equal 404, response.code
      assert_nil response.status.message
      assert_nil response.data
    end

  end

  class ResponseFromExceptionTests < BaseTests
    desc "generating a respone from an exception"

    should "build a 400 response with a protocol BadMessageError" do
      exception = generate_exception(Sanford::Protocol::BadMessageError, 'bad message')
      response = Sanford::ErrorHandler.new(exception, @host_data).run

      assert_equal 400,           response.code
      assert_equal 'bad message', response.status.message
    end

    should "build a 400 response with a protocol BadRequestError" do
      exception = generate_exception(Sanford::Protocol::BadRequestError, 'bad request')
      response = Sanford::ErrorHandler.new(exception, @host_data).run

      assert_equal 400,           response.code
      assert_equal 'bad request', response.status.message
    end

    should "build a 404 response with a NotFoundError" do
      exception = generate_exception(Sanford::NotFoundError, 'not found')
      response = Sanford::ErrorHandler.new(exception, @host_data).run

      assert_equal 404, response.code
      assert_nil response.status.message
    end

    should "build a 500 response with all other exceptions" do
      response = Sanford::ErrorHandler.new(RuntimeError.new('test'), @host_data).run

      assert_equal 500,                             response.code
      assert_equal 'An unexpected error occurred.', response.status.message
    end

  end

  class MultipleErrorProcsTests < ResponseFromProcTests
    desc "with multiple error procs"
    setup do
      @first_called, @second_called, @third_called = nil, nil, nil
      @host_data = Sanford::HostData.new(EmptyHost, @host_defaults.merge({
        :error_procs => [ first_proc, second_proc, third_proc ]
      }))
    end

    should "call every error proc" do
      @error_handler = Sanford::ErrorHandler.new(RuntimeError.new('test'), @host_data)
      @error_handler.run

      assert_equal true, @first_called
      assert_equal true, @second_called
      assert_equal true, @third_called
    end

    should "should return the response of the last configured error proc " \
           "that returned a valid response" do
      @error_handler = Sanford::ErrorHandler.new(RuntimeError.new('test'), @host_data)
      response = @error_handler.run

      # use the second proc's generated response
      assert_equal 987, response.code

      exception = generate_exception(Sanford::NotFoundError, 'not found')
      @error_handler = Sanford::ErrorHandler.new(exception, @host_data)
      response = @error_handler.run

      # use the third proc's generated response
      assert_equal 876, response.code
    end

    def first_proc
      proc{ @first_called = true }
    end

    def second_proc
      proc do |exception, host_data, request|
        @second_called = true
        987
      end
    end

    def third_proc
      proc do |exception, host_data, request|
        @third_called = true
        876 if exception.kind_of?(Sanford::NotFoundError)
      end
    end

  end

end
