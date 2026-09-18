class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private

  def admin?
    user.present? && user.admin?
  end

  def analyst?
    user.present? && (user.admin? || user.analyst?)
  end

  def scout?
    user.present? && (user.admin? || user.analyst? || user.scout?)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    def admin?
      user.present? && user.admin?
    end

    def analyst?
      user.present? && (user.admin? || user.analyst?)
    end

    def scout?
      user.present? && (user.admin? || user.analyst? || user.scout?)
    end
  end
end
