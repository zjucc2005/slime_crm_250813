# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def project_task_notice_email
    UserMailer.project_task_notice_email(params[:id], params[:category])
  end
end
