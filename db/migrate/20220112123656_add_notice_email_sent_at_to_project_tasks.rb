class AddNoticeEmailSentAtToProjectTasks < ActiveRecord::Migration[6.0]
  def change
    add_column :project_tasks, :notice_email_sent_at, :datetime
  end
end
