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

require "json"
require "net/http"
require "net/https"
require "qumulo/rest/request_options"
require "qumulo/rest/validator"

module Qumulo::Rest
  class Http
    include Validator

    # --------------------------------------------------------------------------
    # HTTP Handling
    #

    # === Description
    # Create an http request to call HTTP verbs on.  This object stores some HTTP
    # options, such as timeout or authorization
    #
    # === Parameters
    # host:: Qumulo cluster address
    # port:: Qumulo cluster REST API port address (e.g. 8000)
    # timeout:: timeout value in seconds
    # bearer_token:: token to use to authorize against Qumulo cluster
    # request_opts:: an instance of RequestOptions
    #
    def initialize(host, port, timeout, bearer_token, request_opts = nil)
      @host = host # validated already in client
      @port = port # validated already in client
      @open_timeout = validated_positive_int(:timeout, timeout)
      @read_timeout = validated_positive_int(:timeout, timeout)
      @bearer_token = bearer_token
      @request_opts = request_opts
    end

    # === Description
    # Send HTTP request, and return the response from the server.
    #
    # === Parameters
    # request:: instance of Net::HTTP::{Post,Put,Get,Delete}
    #
    # === Returns
    # If successfulm a Hash object containing:
    #  {
    #    :response => <Net::HTTPResponse object>,
    #    :attrs => <Hash object representing resource attributes>
    #  }
    #
    # If failed, a Hash object containing:
    #  {
    #    :response => <Net::HTTPResponse object>,
    #    :code => <Integer representation of status code>,
    #    :error => <Hash object representing error structure>
    #  }
    #
    # === Raises
    # JSON::ParserError if successful response does not contain valid JSON
    #
    def http_execute(request)
      request.content_type ||= "application/json"
      request["Authorization"] = @bearer_token if @bearer_token
      http = Net::HTTP.new(@host, @port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      # Print debug information
      if @request_opts.debug
        http.set_debug_output($stderr)
      end

      response = http.start {|cx| cx.request(request)}
      result = {:response => response, :code => response.code.to_i}
      result[:body] = response.body # for debugging
      if response.is_a?(Net::HTTPSuccess)
        # XXX - we should not always parse the body.  For file data,
        # we should store it to an open stream, or just store it as binary.
        # This is not yet implemented.
        begin
          result[:attrs] = JSON.parse(response.body)
        rescue JSON::ParserError
          # Sometimes QFSD returns non-json body. (e.g. /v1/setpassword)
          # Ignore body of unparsable success response.
          result[:attrs] = {}
        end
      else
        begin
          result[:error] = JSON.parse(response.body)
        rescue JSON::ParserError
          result[:error] = { :message => response.msg }
        end
      end
      result
    end

    # === Description
    # Perform POST request.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    # attrs:: Hash object containing key-value pairs representing resource
    #
    # === Returns
    # result Hash object
    #
    def post(path, attrs)
      post = Net::HTTP::Post.new(path)
      post.body = JSON.generate(attrs)
      http_execute(post)
    end

    # === Description
    # Perform PUT request.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    # attrs:: Hash object containing key-value pairs representing resource
    # etag:: (optional) etag to add to the request
    #
    # === Returns
    # result Hash object
    #
    def put(path, attrs, etag=nil)
      put = Net::HTTP::Put.new(path)
      put.body = JSON.generate(attrs)
      if etag
        put["if-match"] = etag
      end
      http_execute(put)
    end

    # === Description
    # Perform PUT request and allow the body and headers to be specified.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    # attrs:: Hash object containing key-value pairs representing resource
    # options:: (optional) Allows options such as :headers to be passed in
    #
    # === Returns
    # result Hash object
    #
    def put_raw(path, body = nil, options = { })
      headers = options[:headers]
      post = Net::HTTP::Put.new(path, headers)
      post.body = body
      http_execute(post)
    end

    # === Description
    # Perform GET request.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    #
    # === Returns
    # result Hash object
    #
    def get(path)
      http_execute(Net::HTTP::Get.new(path))
    end

    # === Description
    # Perform DELETE request against a resource.
    #
    # === Parameters
    # path:: URI path, including query string parameters
    #
    # === Returns
    # result Hash object
    #
    def delete(path)
      http_execute(Net::HTTP::Delete.new(path))
    end

  end
end

