class EventPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def select?
    user.present?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def sync?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
