class ScoutingEntryPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def replay?
    true
  end

  def update?
    owner? || analyst?
  end

  def destroy?
    analyst?
  end

  def sync?
    scout?
  end

  def approve?
    admin?
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
