require "test_helper"

class AccountSessionsTest < ActionDispatch::IntegrationTest
  test "registration creates an account and keeps it logged in after navigation" do
    assert_difference("User.count", 1) do
      post registration_path, params: {
        user: {
          name: "Алексей",
          email: "player@example.com",
          password: "secure-pass-123",
          password_confirmation: "secure-pass-123"
        }
      }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select ".status-line", "Вы авторизованы"
  end

  test "registration displays a validation error for an invalid email" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        user: {
          name: "Алексей",
          email: "not-an-email",
          password: "secure-pass-123",
          password_confirmation: "secure-pass-123"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", "Email имеет неверный формат"
  end

  test "login persists through refresh and logout ends the session" do
    user = User.create!(name: "Мария", email: "maria@example.com", password: "secure-pass-123")

    post login_path, params: { email: user.email, password: "secure-pass-123" }
    assert_redirected_to root_path
    get root_path
    assert_select ".status-line", "Вы авторизованы"

    delete logout_path
    assert_redirected_to root_path
    get root_path
    assert_select ".status-line", "Вы не вошли в аккаунт"
  end

  test "invalid credentials do not create an authenticated session" do
    post login_path, params: { email: "nobody@example.com", password: "wrong-password" }

    assert_response :unprocessable_entity
    assert_select ".flash-alert", "Неверный email или пароль."
  end

  test "guests can view a table without seeing player cards or actions" do
    get table_path(1)

    assert_response :success
    assert_select ".poker-table"
    assert_select ".observer-prompt"
    assert_select ".observer-prompt a[href='#{login_path}']", "Войти"
    assert_select ".observer-prompt a[href='#{registration_path}']", "Регистрация"
    assert_select ".seat-you", false
    assert_select ".hole-cards", false
    assert_select ".game-actions", false
    assert_select ".turn-banner", false
    assert_select ".players-panel .player-line-you", false
  end

  test "signed-in users see their demo seat and game controls" do
    user = User.create!(name: "Мария", email: "maria@example.com", password: "secure-pass-123")
    post login_path, params: { email: user.email, password: "secure-pass-123" }

    get table_path(1)

    assert_response :success
    assert_select ".seat-you", /Мария/
    assert_select ".hole-cards"
    assert_select ".game-actions"
    assert_select ".turn-banner"
    assert_select ".observer-prompt", false
  end

  test "lobby and core prototype screens render" do
    get root_path
    assert_response :success
    assert_select ".lobby-grid"
    assert_select "title", "Лобби · PokerMath"
    assert_select ".brand span:last-child", "PokerMath"

    get table_path(1)
    assert_response :success
    assert_select ".poker-table"

    get earn_chips_path
    assert_response :success
    assert_select ".problem-stage"

    get profile_path
    assert_response :success
    assert_select ".profile-overview"
  end
end
