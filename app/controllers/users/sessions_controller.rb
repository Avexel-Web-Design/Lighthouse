class Users::SessionsController < Devise::SessionsController
  def destroy
    session.delete(:current_event_id)
    super
  end
end
