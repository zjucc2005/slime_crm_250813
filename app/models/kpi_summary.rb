# frozen_string_literal: true

class KpiSummary < ApplicationRecord
  belongs_to :user, class_name: 'User'
  has_many :infos, class_name: 'KpiInfo', dependent: :destroy

  def to_api
    expose_fields(
      :id, :created_at, :updated_at, :user_id,
      name: user&.name_cn,
      datetime: datetime&.strftime('%F'),
      infos: infos.order(:id).map(&:to_api)
    )
  end

  # 初始化员工数据
  def self.init_data(datetime, user_id)
    s_month = Time.parse(datetime).beginning_of_month
    user = User.find(user_id)
    project_tasks = ProjectTask.where(status: 'finished').where('started_at BETWEEN ? AND ?', s_month, s_month + 1.month)
    my_project_tasks = project_tasks.where(created_by: user.id)
    interview_hours = (my_project_tasks.sum(:charge_duration) / 60.0).round(2)
    if user.is_role?('admin', 'pm', 'pd')
      manage_hours = (project_tasks.where(pm_id: user.id).where.not(created_by: user.id).sum(:charge_duration) / 60.0).round(2)
    else
      manage_hours = 0.0
    end
    sum_interview_in = my_project_tasks.sum(:actual_price).to_f
    sum_interview_ex = my_project_tasks.sum{ |t| t.costs.sum(:price) }
    aver_interview_in = interview_hours.zero? ? 0.0 : (sum_interview_in / interview_hours).round(2)
    aver_interview_ex = interview_hours.zero? ? 0.0 : (sum_interview_ex / interview_hours).round(2)
    new_expert_count = my_project_tasks.where(is_new_expert: true).count
    new_expert_rate = new_expert_count.zero? ? 0 : new_expert_count.to_f / my_project_tasks.count

    {
      datetime: datetime,
      user_id: user.id,
      name: user.name_cn,
      infos: [
        { name: '访谈小时', price: interview_hours, disabled: true },
        { name: '额外小时', price: 0, disabled: false },
        { name: '管理小时', price: manage_hours, disabled: true },
        { name: '总访谈收入', price: sum_interview_in, disabled: true },
        { name: '总专家支出', price: sum_interview_ex, disabled: true },
        { name: '总访谈毛利', price: sum_interview_in - sum_interview_ex, disabled: true },
        { name: '访谈平均单价/h', price: aver_interview_in, disabled: true },
        { name: '专家平均单价/h', price: aver_interview_ex, remark: "#{((1 - aver_interview_ex / aver_interview_in) * 100).round(2)} %", disabled: true },
        { name: '新专家率', price: new_expert_rate.round(3), disabled: true },
        { name: '个人总收入', price: 0, disabled: true },
        { name: '基础工资', price: 0, disabled: false },
        { name: '当月奖金', price: 0, disabled: true },
        { name: '当月社保', price: 0, disabled: false },
        { name: '报销', price: 0, disabled: false },
        { name: '绩效倍数', price: 0, disabled: true }
      ]
    }
  end

  def to_init_data
    { 
      id: id,
      datetime: datetime,
      user_id: user_id,
      name: user.name_cn,
      infos: infos.order(:id).map(&:to_init_data)
    }
  end

end