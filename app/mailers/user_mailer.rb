class UserMailer < ApplicationMailer
  default from: 'project@hci-consulting.com'

  def test_email
    mail(
        # from: 'zjucc2005@163.com',
        to: 'zjucc2005@163.com',
        subject: 'Test mail, do not reply'
    )
  end

  # project_task_id - ProjectTask#id
  def project_task_notice_email(project_task_id, category='A')
    @project_task = ProjectTask.find(project_task_id)
    @category = category
    @project = @project_task.project
    @expert = @project_task.expert
    @client = @project_task.client
    to_email = [@project_task.client.email]
    main_pc = @project.project_candidates.client.where(mark: 'main').where.not(candidate_id: @project_task.client_id).first
    to_email << main_pc.candidate.email if main_pc
    cc_email = [@project_task.creator.email, @project_task.pm.email]
    company_cc = @project.company.project_task_notice_email_cc
    if company_cc.present? && company_cc.is_a?(String)
      company_cc_list = company_cc.split(',').map(&:strip)
      cc_email += company_cc_list if company_cc_list.any?
    end
    subject  = "【hci 专家访谈明细】 #{@project.code}-#{@project.name}-#{@project_task.expert_level.capitalize} Expert ##{@expert.uid} #{@project_task.expert_name_for_external}"
    mail(to: to_email, cc: cc_email, subject: subject)
  end

end
