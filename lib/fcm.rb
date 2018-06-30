require 'httparty'
require 'cgi'
require 'json'
require 'googleauth'

class FCM
  include HTTParty
  default_timeout 30
  format :json

  # constants
  SERVER_REFERENCE_BASE_URI   = 'https://iid.googleapis.com/iid'
  TOPIC_REGEX = /[a-zA-Z0-9\-_.~%]+/
  SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
  MAX_COUTN_FAILED_REQUEST = 1

  attr_accessor :timeout

  def initialize(client_options = {})
    @client_options = client_options

    self.class.send(:base_uri, "https://fcm.googleapis.com/v1/projects/#{ENV['FIREBASE_PROJECT_ID']}/messages:send")
  end

  def send_notification(token, options = {})
    post_body = { message:{ token: token }.merge!(options) }

    params = {
      body: post_body.to_json,
      headers: headers(auth_2LO)
    }

    response(:post, '', params.merge(@client_options))
  end

  def send_to_topic(topic, condition, options = {})
    if topic.gsub(TOPIC_REGEX, "").length == 0 && (condition.nil? || validate_condition?(condition))
      body = {message: { topic: topic }.merge!(options)}

      body[:message][:condition] = condition if condition.present?

      params = {
          body: body.to_json,
          headers: headers(auth_2LO)
      }

      response(:post, '', params.merge(@client_options))
    end
  end

  def add_to_topic(topic, registration_ids)
    if topic.gsub(TOPIC_REGEX, "").length == 0
      post_body = build_server_post_body(registration_ids, {to: '/topics/' + topic})

      params = {
          body: post_body.to_json,
          headers: headers(auth)
      }

      response = nil

      for_uri(SERVER_REFERENCE_BASE_URI) do
        response = self.class.post('/v1:batchAdd', params.merge(@client_options))
      end
      build_response(response, registration_ids)
    end
  end

  def remove_to_topic(topic, registration_ids)
    if topic.gsub(TOPIC_REGEX, "").length == 0
      post_body = build_server_post_body(registration_ids, {to: '/topics/' + topic})

      params = {
          body: post_body.to_json,
          headers: headers(auth)
      }

      response = nil

      for_uri(SERVER_REFERENCE_BASE_URI) do
        response = self.class.post('/v1:batchRemove', params.merge(@client_options))
      end
      build_response(response, registration_ids)
    end
  end

  private

  def response type, path, params, registration_ids=[]
    retry_count = 0

    loop do
      response = self.class.send(type, path, params)

      retry_count += 1

      if response_successful?(response) || retry_count > MAX_COUTN_FAILED_REQUEST
        return build_response(response, registration_ids)
      elsif response.code == 401
        refresh_auth_2LO
      else
        raise Exception.new(response)
      end
    end
  end

  def response_successful?(response)
    (200..299).include?(response.code)
  end

  def auth
    {"access_token"=> ENV['FIREBASE_WEB_API_KEY'], "token_type"=> "key=", "expires_in"=> nil}
  end

  def auth_2LO
    @access_token_info ||= refresh_auth_2LO
  end

  def refresh_auth_2LO
    authorizer = Google::Auth::ServiceAccountCredentials.make_creds(scope: SCOPE)

    @access_token_info = authorizer.fetch_access_token!
  end

  def headers auth
    {
        'Authorization' => "#{auth["token_type"]} #{auth["access_token"]}",
        'Content-Type' => 'application/json'
    }
  end

  def for_uri(uri)
    current_uri = self.class.base_uri
    self.class.base_uri uri
    yield
    self.class.base_uri current_uri
  end

  def build_server_post_body(registration_ids, options = {})
    { registration_tokens: ids(registration_ids) }.merge(options)
  end

  def ids registration_ids
    registration_ids.is_a?(String) ? [registration_ids] : registration_ids
  end

  def build_response(response, registration_ids = [])
    body = response.body || {}
    response_hash = { body: body, headers: response.headers, status_code: response.code }
    case response.code
    when 200
      response_hash[:response] = 'success'
      body = JSON.parse(body) unless body.empty?
      response_hash[:canonical_ids] = build_canonical_ids(body, registration_ids) unless registration_ids.empty?
      response_hash[:not_registered_ids] = build_not_registered_ids(body, registration_ids) unless registration_ids.empty?
    when 400
      response_hash[:response] = 'Only applies for JSON requests. Indicates that the request could not be parsed as JSON, or it contained invalid fields.'
    when 401
      response_hash[:response] = 'There was an error authenticating the sender account.'
    when 503
      response_hash[:response] = 'Server is temporarily unavailable.'
    when 500..599
      response_hash[:response] = 'There was an internal error in the FCM server while trying to process the request.'
    end
    response_hash
  end

  def build_canonical_ids(body, registration_ids)
    canonical_ids = []
    unless body.empty?
      if body['canonical_ids'].present? && body['canonical_ids'] > 0
        body['results'].each_with_index do |result, index|
          canonical_ids << { old: registration_ids[index], new: result['registration_id'] } if has_canonical_id?(result)
        end
      end
    end
    canonical_ids
  end

  def build_not_registered_ids(body, registration_id)
    not_registered_ids = []
    unless body.empty?
      if body['failure'].present? && body['failure'] > 0
        body['results'].each_with_index do |result, index|
          not_registered_ids << registration_id[index] if is_not_registered?(result)
        end
      end
    end
    not_registered_ids
  end

  def has_canonical_id?(result)
    !result['registration_id'].nil?
  end

  def is_not_registered?(result)
    result['error'] == 'NotRegistered'
  end

  def validate_condition?(condition)
    validate_condition_format?(condition) && validate_condition_topics?(condition)
  end

  def validate_condition_format?(condition)
    bad_characters = condition.gsub(
        /(topics|in|\s|\(|\)|(&&)|[!]|(\|\|)|'([a-zA-Z0-9\-_.~%]+)')/,
        ""
    )
    bad_characters.length == 0
  end

  def validate_condition_topics?(condition)
    topics = condition.scan(/(?:^|\S|\s)'([^']*?)'(?:$|\S|\s)/).flatten
    topics.all? { |topic| topic.gsub(TOPIC_REGEX, "").length == 0 }
  end
end
