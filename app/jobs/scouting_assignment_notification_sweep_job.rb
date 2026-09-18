class ScoutingAssignmentNotificationSweepJob < ApplicationJob
  queue_as :default

  def perform
    Event.active.find_each(batch_size: 100) do |event|
      ScoutingAssignmentNotificationJob.perform_later(event.id)
    end
  end
end
