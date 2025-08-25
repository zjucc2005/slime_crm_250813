# encoding: utf-8
class Project < ApplicationRecord
  # ENUM
  STATUS = {
      initialized: '新项目',
      ongoing: '进展中',
      finished: '已结束',
      billing: '已开票',
      billed: '已收款',
      cancelled: '已取消'
  }.stringify_keys

  # Associations
  belongs_to :creator, :class_name => 'User', :foreign_key => :created_by
  belongs_to :company, :class_name => 'Company'
  has_many :project_candidates, :class_name => 'ProjectCandidate', :dependent => :destroy
  has_many :candidates, :class_name => 'Candidate', :through => :project_candidates
  has_many :project_users, :class_name => 'ProjectUser', :dependent => :destroy
  has_many :users, :class_name => 'User', :through => :project_users
  has_many :project_requirements, :class_name => 'ProjectRequirement'
  has_many :project_tasks, :class_name => 'ProjectTask'
  has_many :project_task_costs, through: :project_tasks, source: :costs
  has_many :call_records, class_name: 'CallRecord'
  has_many :project_remarks, dependent: :destroy
  has_many :project_marks, class_name: 'ProjectMark'

  # Validations
  validates_presence_of :name
  validates_inclusion_of :status, :in => STATUS.keys
  validates_uniqueness_of :code, :allow_blank => true

  before_validation :setup, on: [:create, :update]

  mount_uploader :invoice_file, FileUploader

  accepts_nested_attributes_for :project_remarks, allow_destroy: true

  # has_many :clients / :experts 作为 has_many :candidates 的补充, 依据 project_candidates.category
  # 和 candidates.client / candidates.expert 有区别, 只读
  def clients
    Candidate.joins(:project_candidates).where(
        :'project_candidates.project_id' => self.id,
        :'project_candidates.category'   => 'client').order(:'project_candidates.created_at' => :asc)
  end

  def experts
    Candidate.joins(:project_candidates).where(
        :'project_candidates.project_id' => self.id,
        :'project_candidates.category'   => 'expert').order(:'project_candidates.created_at' => :desc)
  end

  def main_client
    pc = project_candidates.client.where(mark: 'main').first || project_candidates.client.order(created_at: :asc).first
    pc ? pc.candidate : nil
  end

  # has_many :pm_users / :pa_users 作为 has_many :users 的补充, 依据 project_users.category
  # 和 users.pm / users.pa 有区别， 只读
  def pm_users
    User.joins(:project_users).where(
        'project_users.project_id': self.id,
        'project_users.category': %w[admin pm pd])
  end

  def pa_users
    User.joins(:project_users).where(
        'project_users.project_id': self.id,
        'project_users.category': 'pa')
  end

  def can_edit?
    %w[initialized ongoing billing billed].include?(status)
  end

  def can_destroy?
    project_tasks.where.not(status: 'cancelled').count == 0  # 只能删除没有任务的项目
  end

  def can_start?
    %w[initialized].include?(status)
  end

  def can_finish?
    %w[ongoing].include?(status)
  end

  def can_billing?
    %w[finished].include?(status)
  end

  def can_billed?
    %w[billing].include?(status)
  end

  def can_add_requirement?
    %w[ongoing].include?(status)
  end
  alias :can_add_task? :can_add_requirement?

  def can_add_pm_user?
    pm_users.count == 0
  end

  def can_add_pa_user?
    true
  end

  def can_delete_user?(user, operator)
    if self.created_by == user.id
      operator.admin?                   # 创建者PM只能被ADMIN移除
    else
      operator.is_role?('su', 'admin', 'pm', 'pd')  # PM/PA可以被ADMIN/PM移除
    end
  end

  def can_be_operated_by(user)
    return true if user.su?
    if self.user_channel_id == user.user_channel_id
      if user.admin? || user.pd?
        true
      elsif user.role == 'finance'
        true
      else
        self.project_users.where(user_id: user.id).count > 0
      end
    else
      false
    end
  end

  def start!
    self.status = 'ongoing'
    self.started_at ||= Time.now
    self.save!
  end

  def finish!
    self.status = 'finished'
    self.ended_at ||= Time.now
    self.save!
  end
  alias close! finish!

  def reopen!
    self.status = 'ongoing'
    self.ended_at = nil
    self.save!
  end

  def active_contract
    company.contracts.available.order(:started_at => :desc).first
  end

  def total_project_tasks
    project_tasks.where(status: 'finished').count
  end

  def total_duration
    (project_tasks.where(status: 'finished').sum(:duration) / 60.0).round(1)
  end

  def total_charge_duration
    (project_tasks.where(status: 'finished').sum(:charge_duration) / 60.0).round(1)
  end

  def total_price
    project_tasks.where(status: 'finished').sum(:total_price)
  end

  def project_option_friendly
    "#{company.name_abbr} - #{code} - #{name}"
  end

  def last_update
    self.updated_at = Time.now
    self.save(validate: false)
    company.update(last_active_time: Time.now)
  end

  def premium_charge_duration_rate
    project_task_query = project_tasks.where(status: 'finished', currency: 'RMB')
    total_charge_duration = project_task_query.sum(:charge_duration)
    if total_charge_duration.zero?
      0
    else
      project_task_query.where(expert_level: 'premium').sum(:charge_duration).to_f / total_charge_duration
    end
  end

  def to_api(user)
    expose_fields(:id, :name, :code, :status, :creator, :total_project_tasks,
      created_at: created_at.strftime('%F %T'),
      updated_at: updated_at.strftime('%F %T'),
      company_name_abbr: company&.name_abbr,
      client_contact: main_client&.name,
      pm_name: pm_users.first&.name_cn,
      total_charge_duration: total_charge_duration,
      total_price: total_price,
      premium_rate: premium_charge_duration_rate.round(3),
      project_requirements: project_requirements.order(priority: :desc, created_at: :desc).map(&:to_api),
      mark_type: project_marks.where(project_id: self.id, user_id: user.id).first&.mark_type
    )
  end

  private
  def setup
    self.status ||= 'initialized'
    self.code = code&.strip
  end

end
