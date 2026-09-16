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

    if role_change_blocked?
      redirect_to users_path, alert: role_block_message
      return
    end

    if @user.update(params_to_use)
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

    if last_admin?(@user)
      redirect_to users_path, alert: "You cannot delete the last admin."
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
    permitted = params.expect(user: [ :first_name, :last_name, :password, :role ]).except(:role)
    requested_role = params.dig(:user, :role).to_s

    if current_user&.admin? && requested_role.present? && User.roles.key?(requested_role)
      permitted[:role] = requested_role
    end

    permitted
  end

  def role_change_blocked?
    requested_role = params.dig(:user, :role).to_s
    return false if requested_role.blank? || !User.roles.key?(requested_role)
    return false if @user.role == requested_role

    return true unless current_user&.admin?
    return true if @user == current_user
    return true if last_admin?(@user)

    false
  end

  def role_block_message
    return "You are not authorized to change roles." unless current_user&.admin?
    return "You cannot remove your own admin access." if @user == current_user
    return "You cannot demote the last admin." if last_admin?(@user)

    "Role change is not allowed."
  end

  def last_admin?(user)
    user.admin? && User.where(role: :admin).where.not(id: user.id).none?
  end
end
