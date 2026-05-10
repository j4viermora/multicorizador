class AccountController < ApplicationController
  def pending
    if current_user.nil?
      redirect_to new_user_session_path
    elsif current_user.super_admin? || (current_user.producer? && current_user.active?)
      redirect_to root_path
    end
  end
end
