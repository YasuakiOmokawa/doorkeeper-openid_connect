# frozen_string_literal: true

require 'rails_helper'

describe Doorkeeper::OpenidConnect::DiscoveryController, type: :controller do
  describe '#provider' do
    it 'returns the provider configuration' do
      get :provider
      data = JSON.parse(response.body)

      expect(data.sort).to match({
        'issuer' => 'dummy',
        'authorization_endpoint' => 'http://test.host/oauth/authorize',
        'token_endpoint' => 'http://test.host/oauth/token',
        'revocation_endpoint' => 'http://test.host/oauth/revoke',
        'introspection_endpoint' => 'http://test.host/oauth/introspect',
        'userinfo_endpoint' => 'http://test.host/oauth/userinfo',
        'jwks_uri' => 'http://test.host/oauth/discovery/keys',

        'scopes_supported' => ['openid'],

        'response_types_supported' => ['code', 'token', 'id_token', 'id_token token'],
        'response_modes_supported' => %w[query fragment],
        'grant_types_supported' => %w[authorization_code client_credentials],

        'token_endpoint_auth_methods_supported' => %w[client_secret_basic client_secret_post],

        'subject_types_supported' => [
          'public',
        ],

        'id_token_signing_alg_values_supported' => [
          'RS256',
        ],

        'claim_types_supported' => [
          'normal',
        ],

        'claims_supported' => %w[
          iss
          sub
          aud
          exp
          iat
          name
          variable_name
          created_at
          updated_at
          token_id
          both_responses
          id_token_response
          user_info_response
        ],
      }.sort)
    end

    context 'when refresh_token grant type is enabled' do
      before { Doorkeeper.configure { use_refresh_token } }

      it 'add refresh_token to grant_types_supported' do
        get :provider
        data = JSON.parse(response.body)

        expect(data['grant_types_supported']).to eq %w[authorization_code client_credentials refresh_token]
      end
    end

    it 'uses the protocol option for generating URLs' do
      Doorkeeper::OpenidConnect.configure do
        protocol { :testing }
      end

      get :provider
      data = JSON.parse(response.body)

      expect(data['authorization_endpoint']).to eq 'testing://test.host/oauth/authorize'
    end

    it 'does not return an end session endpoint if none is configured' do
      get :provider
      data = JSON.parse(response.body)

      expect(data.key?('end_session_endpoint')).to be(false)
    end

    it 'uses the configured end session endpoint' do
      Doorkeeper::OpenidConnect.configure do
        end_session_endpoint { 'http://test.host/logout' }
      end

      get :provider
      data = JSON.parse(response.body)

      expect(data['end_session_endpoint']).to eq 'http://test.host/logout'
    end
  end

  describe '#webfinger' do
    it 'requires the resource parameter' do
      expect do
        get :webfinger
      end.to raise_error ActionController::ParameterMissing
    end

    it 'returns the OpenID Connect relation' do
      get :webfinger, params: { resource: 'user@example.com' }
      data = JSON.parse(response.body)

      expect(data.sort).to eq({
        'subject' => 'user@example.com',
        'links' => [
          'rel' => 'http://openid.net/specs/connect/1.0/issuer',
          'href' => 'http://test.host/',
        ],
      }.sort)
    end
  end

  describe '#keys' do
    subject { get :keys }

    shared_examples 'a key response' do |options|
      expected_parameters = options[:expected_parameters]

      it "includes only #{expected_parameters.join(', ')} parameters" do
        subject
        data = JSON.parse(response.body)
        key = data['keys'].first

        expect(key.keys.map(&:to_sym)).to match_array(expected_parameters)
      end
    end

    context 'when using an RSA key' do
      it_behaves_like 'a key response', expected_parameters: %i[kty kid e n use alg]
    end

    context 'when using an EC key' do
      before { configure_ec }

      it_behaves_like 'a key response', expected_parameters: %i[kty kid crv x y use alg]
    end

    context 'when using an HMAC key' do
      before { configure_hmac }

      it_behaves_like 'a key response', expected_parameters: %i[kty kid use alg]
    end
  end
end
