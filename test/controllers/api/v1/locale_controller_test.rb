require 'test_helper'

module Api
  module V1
    class LocaleControllerTest < ActionDispatch::IntegrationTest
      def setup
        @user = users(:client)
        @token = Auth::JsonWebToken.encode(user_id: @user.id, token_type: 'access')
      end

      test "should get current locale without authentication" do
        get api_v1_locale_url
        assert_response :success
        assert_equal 'uk', JSON.parse(response.body)['locale']
      end

      test "should update locale for guest user" do
        put api_v1_locale_url, params: { locale: 'ru' }
        assert_response :success
        assert_equal 'ru', JSON.parse(response.body)['locale']
        assert_equal I18n.t('locale.updated_for_session'), JSON.parse(response.body)['message']
      end

      test "should update locale for authenticated user" do
        put api_v1_locale_url,
            params: { locale: 'ru' },
            headers: { 'Authorization' => "Bearer #{@token}" }
        assert_response :success
        assert_equal 'ru', JSON.parse(response.body)['locale']
        assert_equal I18n.t('locale.updated_for_session'), JSON.parse(response.body)['message']
      end

      test "should not update locale with invalid value" do
        put api_v1_locale_url,
            params: { locale: 'invalid' },
            headers: { 'Authorization' => "Bearer #{@token}" }
        assert_response :unprocessable_entity
        assert_equal I18n.t('locale.invalid'), JSON.parse(response.body)['error']
      end
    end
  end
end 