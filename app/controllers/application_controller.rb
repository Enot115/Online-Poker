class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  private

  def require_login
    return if logged_in?

    redirect_to login_path, alert: "Войдите в аккаунт, чтобы продолжить."
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end
end
