# frozen_string_literal: true

class CompanySummary < ApplicationRecord
  belongs_to :company, class_name: 'Company'
  has_many :infos, class_name: 'CompanyInfo', dependent: :destroy

  def to_api
    expose_fields(
      :id, :created_at, :updated_at, :company_id,
      name: company&.name_abbr, name_abbr: company&.name_abbr,
      datetime: datetime&.strftime('%F'),
      infos: infos.order(:id).map(&:to_api)
    )
  end

  # 初始化客户数据
  def self.init_data(datetime, company_id)
    s_month = Time.parse(datetime).beginning_of_month
    company = Company.find(company_id)

    project_tasks = ProjectTask.joins(:project).
      where('projects.company_id': company_id, 'project_tasks.status': 'finished').
      where('project_tasks.started_at BETWEEN ? AND ?', s_month, s_month + 1.month)

    interview_hours = (project_tasks.sum(:charge_duration) / 60.0).round(2)
    sum_interview_in = project_tasks.sum(:actual_price).to_f
    sum_interview_ex = project_tasks.sum{ |t| t.costs.sum(:price) }
    aver_interview_in = interview_hours.zero? ? 0.0 : (sum_interview_in / interview_hours).round(2)
    aver_interview_ex = interview_hours.zero? ? 0.0 : (sum_interview_ex / interview_hours).round(2)
    profit_margin = (1 - sum_interview_ex / sum_interview_in).round(2)

    {
      id: self.where(datetime: datetime, company_id: company_id).first&.id,
      datetime: datetime,
      company_id: company_id,
      name: company&.name_abbr,
      name_abbr: company&.name_abbr,
      infos: [
        { name: '总访谈小时', price: interview_hours, disabled: true },
        { name: '总访谈收入', price: sum_interview_in, disabled: true },
        { name: '总专家支出', price: sum_interview_ex, disabled: true },
        { name: '总访谈毛利', price: sum_interview_in - sum_interview_ex, disabled: true },
        { name: '访谈平均单价/h', price: aver_interview_in, disabled: true },
        { name: '专家平均单价/h', price: aver_interview_ex, disabled: true },
        { name: '毛利率', price: profit_margin, disabled: true }
      ]
    }
  end

  def to_init_data
    { 
      id: id,
      datetime: datetime,
      company_id: company_id,
      name: company&.name_abbr,
      name_abbr: company&.name_abbr,
      infos: infos.order(:id).map(&:to_init_data)
    }
  end

end