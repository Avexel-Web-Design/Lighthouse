class PickListPolicy < ApplicationPolicy
  def index?
    analyst?
  end

  def show?
    analyst?
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

  class Scope < ApplicationPolicy::Scope
    def resolve
      if analyst?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end
