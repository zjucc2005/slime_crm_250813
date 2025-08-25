# encoding: utf-8
class CallRecord < ApplicationRecord

  # ENUM
  STATUS = {
    pending:  '未联系',
    missed:   '未接',
    rejected: '拒接',
    shutdown: '关机',
    talking:  '沟通中',
    declined: '拒绝',
    accepted: '接受'
  }.stringify_keys
  REC_STATUS = { init: '未推荐', recommended: '已推荐', hold: '客户确认中', unsuited: '不合适', ok: '可约访', succ: '约访成功', fail: '约访失败' }.stringify_keys

  # Associations
  belongs_to :creator, :class_name => 'User', :foreign_key => :created_by, :optional => true
  belongs_to :operator, :class_name => 'User', :foreign_key => :operator_id
  belongs_to :project, :class_name => 'Project', :optional => true
  belongs_to :project_requirement, class_name: 'ProjectRequirement', optional: true
  belongs_to :candidate, :class_name => 'Candidate', :optional => true

  # Validations
  validates_presence_of :name
  validates_inclusion_of :status, :in => STATUS.keys
  validates_inclusion_of :rec_status, in: REC_STATUS.keys
  validates_numericality_of :number_of_calls, :greater_than_or_equal_to => 0

  before_validation :setup, :on => [:create, :update]
  after_save do
    sync_phone_to_candidate
  end

  def project_candidate
    if project_id && candidate_id
      ProjectCandidate.where(project_id: project_id, candidate_id: candidate_id).first
    else
      nil
    end
  end

  def can_add_to_candidate?
    candidate_id.blank?
  end

  def can_be_edited_by(user)
    (user.admin? || current_user.pd?) || self.operator_id == user.id
  end

  # 同步更新电话到专家/医生数据
  def sync_phone_to_candidate
    if candidate_id && candidate.phone != phone
      candidate.update(phone: phone)
    end
  end

  def last_logged_at
    memo_logs[-1] ? Time.parse(memo_logs[-1][0]) : created_at
  end

  def to_api
    expose_fields(
      :id, :uid, :category, :name, :nickname, :gender, :phone, :company, :department, :title, :title1, :academic_field, :remark,
      :number_of_calls, :status, :rec_status, :rec_description, :memo, :memo_logs, :email, :city,
      :created_by, :project_id, :project_requirement_id, :project_task_id, :candidate_id,
      creator: creator&.name_cn,
      operator: operator&.name_cn,
      created_at: created_at.strftime('%F %T'),
      updated_at: updated_at.strftime('%F %T'),
      last_logged_at: last_logged_at.strftime('%F %T')
    )
  end

  # 查找库内匹配的专家信息
  # cond 1 - name & phone
  # cond 2 - phone
  # cond 3 - name & company
  def match_candidates
    # cond 1
    query = Candidate.where(category: category, name: name).where('phone = :phone OR phone1 = :phone', { phone: phone })
    # cond 2
    query = Candidate.where(category: category).where('phone = :phone OR phone1 = :phone', { phone: phone }) if query.count.zero?
    # cond 3
    query = Candidate.joins(:experiences).where('candidates.category': category, 'candidates.name': name, 'candidate_experiences.org_cn': company) if query.count.zero?
    query # return
  end

  def add_memo(text)
    self.memo_logs << [Time.now.to_s, text.strip]
    self.memo = self.memo_logs.map{|log| log[1]}.join('; ')
  end

  private
  def setup
    self.status ||= 'pending'
    self.rec_status ||= 'init'
    self.name&.strip!
    self.phone&.strip!
    self.company&.strip!
    self.department&.strip!
    self.title&.strip!
    self.number_of_calls ||= 1
    self.operator_id     ||= self.created_by
    self.user_channel_id ||= self.creator.user_channel_id
  end

end
