# frozen_string_literal: true

require 'openssl'
require 'httpclient'
require 'nokogiri'
require 'json'
require 'securerandom'

module Handochogwa
  # 현대카드
  class Hyundai
    def initialize(username = nil, password = nil)
      create_session
      @logged_in = false
      authorize(username, password) if username && password
    end

    def authorize(username, password)
      encrypt = OpenSSL::Cipher.new('AES-256-ECB')
      encrypt.padding = 0
      aes_key = encrypt.random_key
      encrypt.key = aes_key

      uuid = Time.now.to_i.to_s + format('%02d', rand(100))
      rsa_key = request_nprotect_rsa(uuid)
      keypad = request_nprotect_keypad

      params = {
        '__E2E_UNIQUE__' => uuid,
        '__E2E_KEYPAD__' => encrypt_aes_key(aes_key, rsa_key),
        'webMbrId' => username,
        'webPwd' => ''
      }.merge(encrypt_password(keypad, aes_key, password))

      # TODO: 왜 동작하지 않는지 확인하고 고치기...
      # @client.post('https://www.hyundaicard.com/cpm/mb/CPMMB0101_02.hc', body: params)
    end

    private

    def create_session
      @client = HTTPClient.new(agent_name: Handochogwa::USER_AGENT)

      response = @client.get('https://www.hyundaicard.com/cpm/mb/CPMMB0101_01.hc')
    end

    def request_nprotect_rsa(uuid)
      response = @client.post_content(
        'https://www.hyundaicard.com/pluginfree/jsp/nppfs.keypad.jsp',
        body: { m: 'p', u: uuid }
      ).strip

      decrypt = OpenSSL::Cipher.new('AES-256-ECB')
      decrypt.padding = 0
      decrypt.key = hex_to_bin(response[0...64])
 
      (
        decrypt.update(hex_to_bin(response[64..-1])) + decrypt.final
      ).strip.gsub(
        /-*(KEY|END)-*/,
        'KEY-----' => "KEY-----\n",
        '-----END' => "\n-----END"
      )
    end

    def request_nprotect_keypad
      response = @client.post_content(
        'https://www.hyundaicard.com/pluginfree/jsp/nppfs.keypad.jsp',
        body: keypad_params
      )

      JSON.parse(response.strip)
    end

    def encrypt_aes_key(aes_key, rsa_key)
      bin = OpenSSL::PKey::RSA.new(rsa_key).public_encrypt(aes_key)
      bin_to_hex(bin)
    end

    def encrypt_password(keypad, aes_key, password)
      keys = encrypt_keypad(keypad, aes_key)
      encrypted_password = password.each_char.map { |c| keys[c] }.join

      info_key = keypad["info"]["inputs"]["info"]
      info_value = keypad["info"]["dynamic"].detect { |h| h["k"] == info_key }["v"]

      {
        keypad["info"]["inputs"]["useyn"] => "Y",
        keypad["info"]["inputs"]["hash"] => encrypted_password,
        info_key => info_value
      }
    end

    def encrypt_keypad(keypad, aes_key)
      match = {}

      lowercase_keypad = keypad["items"].detect { |item| item["id"] == "lower" }["buttons"]
      uppercase_keypad = keypad["items"].detect { |item| item["id"] == "upper" }["buttons"]
      special_keypad = keypad["items"].detect { |item| item["id"] == "special" }["buttons"]

      match.merge! process_keypad(lowercase_keypad, ('a'..'z').to_a)
      match.merge! process_keypad(lowercase_keypad, '1234567890'.chars, number: true)
      match.merge! process_keypad(uppercase_keypad, ('A'..'Z').to_a)
      match.merge! process_keypad(special_keypad, "-_=+\\|{}[];:'\",.<>$~`!@#/?".chars)
      match.merge! process_keypad(special_keypad, '!@#$%^&*()'.chars, number: true)

      cipher = OpenSSL::Cipher.new('AES-256-ECB')
      cipher.encrypt
      cipher.key = aes_key
      cipher.padding = 0

      match.map do |key, value|
        [
          key,
          bin_to_hex(cipher.update(value + "\x00" * 8) + cipher.final)
        ]
      end.to_h
    end

    def process_keypad(keypad, char_index, number: false)
      values = keypad
        .select { |button| button['type'] == 'data' }
        .select { |button| button["kind"] == (number ? 'num' : nil) }
        .map do |button|
          [
            button['image']['x'],
            button['action'].split(':')[1]
          ]
      end.sort_by { |x, _| x }.map { |_, data| data }

      char_index
        .each_with_index
        .map do |char, i|
          [char, values[i]]
        end.to_h
    end

    def keypad_params
      {
        m: 'e',
        ev: 'v2',
        d: 'nppfs-keypad-div',
        jv: '1.11.0',
        t: 'b',
        at: 'r',
        st: 'l',
        dp: 'hide',
        ut: 'f',
        f: "d#{SecureRandom.hex(8)}",
        i: 'webPwd',
        th: 'mobile',
        w: 375,
        h: 812,
        ip: 'https://www.hyundaicard.com/pluginfree/jsp/nppfs.keypad.jsp'
      }
    end

    def hex_to_bin(hex)
      [hex].pack('H*')
    end

    def bin_to_hex(bin)
      bin.unpack('H*')[0]
    end
  end
end
