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

  test "lobby and core prototype screens render" do
    get root_path
    assert_response :success
    assert_select ".lobby-grid"

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
