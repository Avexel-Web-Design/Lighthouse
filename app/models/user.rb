class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable

  enum :role, { scout: 0, analyst: 1, admin: 2 }
  # NOTE: roles are scout < analyst < admin. There is no lead/owner role: the
  # Membership-based roles were removed, "owner" in entry policies means the
  # record's author, and the "lead_user" fixture is an analyst.

  # Associations
  has_many :scouting_entries, dependent: :destroy
  has_many :pit_scouting_entries, dependent: :destroy
  has_many :pick_lists, dependent: :destroy
  has_many :simulation_results, dependent: :destroy
  has_many :scouting_assignments, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?

  # Scopes
  scope :scouts, -> { where(role: :scout) }

  # Devise: case-insensitive username lookup for sign-in
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    username = conditions.delete(:username)
    if username
      where(conditions).where("LOWER(username) = ?", username.downcase).first
    else
      where(conditions).first
    end
  end

  # Callbacks
  before_create :generate_api_token
  before_validation :set_username_and_email

  # Returns "First Last"
  def full_name
    "#{first_name} #{last_name}"
  end

  def regenerate_api_token!
    update!(api_token: SecureRandom.hex(32))
  end

  private

  # Only fills in blanks: a manually set username/email is never overwritten,
  # so renaming a user later does not silently change their login.
  def set_username_and_email
    self.username = full_name if username.blank? && first_name.present? && last_name.present?
    self.email = "#{username.parameterize}@lighthouse.local" if email.blank? && username.present?
  end

  def generate_api_token
    self.api_token ||= SecureRandom.hex(32)
  end

  def password_required?
    !persisted? || password.present?
  end
end
