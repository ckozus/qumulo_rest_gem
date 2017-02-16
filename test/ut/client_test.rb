#
#  Copyright 2015 Qumulo, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

require "test_env"

require "fake_http"
require "qumulo/rest/exception"
require "qumulo/rest/client"
require "qumulo/rest/v1/user"

module Qumulo::Rest
  class ClientTest < Minitest::Test

    OPTS_1 = {
      :addr => "dummy",
      :port => 1000,
      :http_timeout => 27,
      :http_class => FakeHttp
    }

    OPTS_2 = {
      :addr => "notdumb"
    }

    OPTS_FAKE_HTTP = OPTS_1

    def setup
      @client1 = Client.new(OPTS_1)
      @client2 = Client.new(OPTS_2)
    end

    def teardown
      Client.unconfigure
    end

    def test_client_accessors_and_defaults
      # OPTS_1
      assert_equal("dummy", @client1.addr)
      assert_equal(1000, @client1.port)
      assert_equal(27, @client1.http_timeout)
      assert_equal(FakeHttp, @client1.http_class)
      # OPTS_2
      assert_equal("notdumb", @client2.addr)
      assert_equal(8000, @client2.port)       # default value
      assert_equal(30, @client2.http_timeout) # default value
      assert_equal(Http, @client2.http_class) # default value
    end

    def test_client_configure
      Client.configure(OPTS_1)
      assert_equal("dummy", Client.default.addr)
      assert_equal(1000, Client.default.port)
      assert_equal(27, Client.default.http_timeout)
      assert_equal(FakeHttp, Client.default.http_class)
    end

    def test_client_unconfigure
      # Configuring client twice raises exception
      Client.configure(OPTS_1)
      assert_raises ConfigError do
        Client.configure(OPTS_2)
      end
      # You can reconfigure client after clearing the configuration
      Client.unconfigure
      Client.configure(OPTS_2)
      assert_equal("notdumb", Client.default.addr)
      assert_equal(8000, Client.default.port)       # default value
      assert_equal(30, Client.default.http_timeout) # default value
      assert_equal(Http, Client.default.http_class) # default value
    end

    def test_client_invalid_params
      assert_raises ValidationError do
        Client.configure(OPTS_2.clone.update(:addr => ""))
      end
      assert_raises ValidationError do
        Client.configure(OPTS_2.clone.update(:port => "bad"))
      end
      assert_raises ValidationError do
        Client.configure(OPTS_2.clone.update(:port => -102))
      end
      assert_raises ValidationError do
        Client.configure(OPTS_2.clone.update(:http_timeout => "bad"))
      end
      assert_raises ValidationError do
        Client.configure(OPTS_2.clone.update(:http_timeout => -20))
      end
    end

    def test_client_login_success
      FakeHttp.set_fake_response(:post, "/v1/session/login", {
        :code => 203,
        :attrs => {
          "key" => "fake-key",
          "key_id" => "fake-key-id",
          "algorithm" => "fake-algorithm",
          "bearer_token" => "1:fake-token"
        }})

      # client is set up with FakeHttp
      Client.configure(OPTS_FAKE_HTTP)
      Client.login(:username => "fakeuser", :password => "fakepass")
      assert_equal("Bearer 1:fake-token", Client.default.get_bearer_token)
    end

    def test_client_login_failure
      FakeHttp.set_fake_response(:post, "/v1/session/login", {
        :code => 401,
        :error => {
          "msg" => "password mismatch",
        }})

      # client is set up with FakeHttp
      Client.configure(OPTS_FAKE_HTTP)
      assert_raises AuthenticationError do
        Client.login(:username => "fakeuser", :password => "fakepass")
      end
      assert_raises LoginRequired do
        Qumulo::Rest::V1::WhoAmI.get
      end
    end

  end
end


