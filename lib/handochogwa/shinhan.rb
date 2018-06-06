# frozen_string_literal: true

require 'openssl'
require 'httpclient'
require 'nokogiri'
require 'json'

module Handochogwa
  # 신한카드!
  class Shinhan
    def initialize(username = nil, password = nil)
      create_session
      @logged_in = false
      authorize(username, password) if username && password
    end

    def authorize(username, password)
      post(
        'cmm/MOBFMLOGIN/CMMServiceMemLoginC.ajax',
        authorize_params(username, password)
      )
    end

    def brief_data
      response = post('MOBFM006N/MOBFM006R0102.ajax')

      recent_usage = process_array(
        response['HPG01499'],
        'alnc_amt' => 'amount',
        'stl_du_dd' => 'date',
        'mcht_nm' => 'metchant'
      )

      {
        total_limit: response['r_tot_amt'],
        remaining_limit: response['x_tot_amt'],
        recent_usage: recent_usage
      }
    end

    private

    def post(url, body = {})
      response_json = @client.post_content(
        "https://m.shinhancard.com/mob/#{url}",
        body: body
      )
      response = JSON.parse(response_json)

      response['mbw_json']
    end

    def process_array(data, replaces)
      Array.new(data.first[1].length) do |i|
        data.keys.map do |key|
          [
            (replaces[key] || key),
            data[key][i]
          ]
        end.to_h
      end
    end

    def create_session
      @client = HTTPClient.new(agent_name: Handochogwa::USER_AGENT)

      response = @client.post_content(
        'https://m.shinhancard.com/solution/nfilter/jsp/open_nFilter_keypad_manager.jsp',
        body: create_session_post_params
      )
      html = Nokogiri::HTML(response)

      @modulus = parse_hex(html.css('#nfilter_modulus')[0]['value'])
      @exponent = parse_hex(html.css('#nfilter_exponent')[0]['value'])
    end

    def parse_hex(hexstring)
      OpenSSL::BN.new(hexstring.to_i(16))
    end

    def create_session_post_params
      image_manager_url = 'solution/nfilter/jsp/open_nFilter_image_manager.jsp'

      {
        nfilter_enable_nosecret: true,
        nfilter_is_init: true,
        nfilter_is_mobile: true,
        nfilter_lang: 'ko',
        nFilter_screenKeyPadSize: 390,
        nFilter_screenSize: 400,
        nfilter_type: 15,
        ResponseImageManager: image_manager_url
      }
    end

    def authorize_params(username, password)
      rsa = OpenSSL::PKey::RSA.new
      rsa.n = @modulus
      rsa.e = @exponent
      encrypted_password = rsa.public_encrypt("no_secret_#{password}")
      hex_password = encrypted_password.unpack1('H*')

      {
        memid: username,
        mode: 'loginPersonWeb',
        channel: 'person',
        device: 'WI',
        nfilter: {
          type: 'mob',
          once: 'true',
          dash: '',
          encrypt: "pwd=#{hex_password}"
        }.to_json
      }
    end
  end
end
