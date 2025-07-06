require 'test_helper'

class LocaleMiddlewareTest < ActiveSupport::TestCase
  def setup
    @app = ->(env) { [200, env, 'app'] }
    @middleware = LocaleMiddleware.new(@app)
    @user = users(:client)
  end

  def env_for(path, headers = {})
    {
      'PATH_INFO' => path,
      'QUERY_STRING' => path.split('?')[1],
      'rack.input' => StringIO.new
    }.merge(headers)
  end

  def test_sets_locale_from_params
    env = env_for('/?locale=ru')
    @middleware.call(env)
    assert_equal 'ru', I18n.locale.to_s
  end

  def test_sets_locale_from_header
    env = env_for('/', 'HTTP_X_LOCALE' => 'ru')
    @middleware.call(env)
    assert_equal 'ru', I18n.locale.to_s
  end

  def test_sets_locale_from_accept_language
    env = env_for('/', 'HTTP_ACCEPT_LANGUAGE' => 'ru,en;q=0.9,uk;q=0.8')
    @middleware.call(env)
    assert_equal 'ru', I18n.locale.to_s
  end

  def test_sets_locale_from_user_preferences
    @user.update!(preferred_locale: 'ru')
    token = JsonWebToken.encode(user_id: @user.id)
    env = env_for('/', 'HTTP_AUTHORIZATION' => "Bearer #{token}")
    @middleware.call(env)
    assert_equal 'ru', I18n.locale.to_s
  end

  def test_sets_default_locale_when_no_locale_specified
    env = env_for('/')
    @middleware.call(env)
    assert_equal 'uk', I18n.locale.to_s
  end

  def test_sets_default_locale_for_unsupported_locale
    env = env_for('/?locale=fr')
    @middleware.call(env)
    assert_equal 'uk', I18n.locale.to_s
  end

  def test_locale_priority
    @user.update!(preferred_locale: 'ru')
    token = JsonWebToken.encode(user_id: @user.id)
    env = env_for('/?locale=uk', {
      'HTTP_AUTHORIZATION' => "Bearer #{token}",
      'HTTP_X_LOCALE' => 'ru',
      'HTTP_ACCEPT_LANGUAGE' => 'ru,en;q=0.9,uk;q=0.8'
    })
    @middleware.call(env)
    assert_equal 'uk', I18n.locale.to_s
  end
end 