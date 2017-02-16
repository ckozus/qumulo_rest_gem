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

require "qumulo/rest/exception"
require "qumulo/rest/base"
module Qumulo::Rest::V1

  # == Class Description
  # This resource is used to log in a client using :username and :password
  # attributes. After post, it will contain the :key to sign requests afterwards.
  #
  # == Notes
  # This is a non-standard REST resource, in that, the attributes used in POST,
  # namely, :username and :password, are different from the attributes returned
  # in a server response, namely, :key and :key_id. But, that's OK. We don't want
  # to keep around :username and :password in our login session object.
  #
  class LoginSession < Qumulo::Rest::Base

    uri_spec "/v1/session/login"

    # only used in post
    field :username, String
    field :password, String

    # used in server response
    field :key, String
    field :key_id, String
    field :algorithm, String
    field :bearer_token, String

    # === Description
    # Send the request to the server
    #
    def start
      begin
        post(:not_authorized => true)
      rescue Qumulo::Rest::RequestFailed => e
        raise Qumulo::Rest::AuthenticationError.new(
          "Login failed", self)
      end
    end

  end
end
