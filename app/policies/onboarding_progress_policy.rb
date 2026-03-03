# frozen_string_literal: true

class OnboardingProgressPolicy < ApplicationPolicy
  def progress?
    true # All authenticated users can see their own progress
  end

  def update_progress?
    true # All authenticated users can update their own progress
  end

  class Scope < Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
