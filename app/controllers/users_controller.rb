class UsersController < ApplicationController
  before_action :set_user, only: %i[edit update destroy]

  def index
    authorize User
    @users = User.order(:last_name, :first_name)
  end

  def new
    authorize User
    @user = User.new
  end

  def create
    authorize User
    @user = User.new(user_params)
    @user.role = role_from_params if role_from_params.present?

    if @user.save
      redirect_to users_path, notice: "#{@user.full_name} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user
    params_to_use = user_params
    params_to_use = params_to_use.except(:password) if params_to_use[:password].blank?

    @user.assign_attributes(params_to_use)
    @user.role = role_from_params if role_from_params.present?

    if @user.save
      redirect_to users_path, notice: "#{@user.full_name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @user

    if @user == current_user
      redirect_to users_path, alert: "You cannot delete yourself."
      return
    end

    @user.destroy
    redirect_to users_path, notice: "#{@user.full_name} was deleted.", status: :see_other
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :password)
  end

  # Role is assigned separately (not via mass-assignment) to satisfy
  # Brakeman's PermitAttributes check. All actions here are admin-only
  # via Pundit (see UserPolicy), so admins may set roles.
  def role_from_params
    params.dig(:user, :role).presence
  end
end
