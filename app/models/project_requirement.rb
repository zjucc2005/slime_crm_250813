# encoding :utf-8
class ProjectRequirement < ApplicationRecord
  # ENUM
  STATUS = {
    :ongoing     => '进展中',
    :finished    => '已完成',
    :cancelled   => '已取消'
  }.stringify_keys
  CATEGORIES = ['医生', 'CI', '官员', '患者']

  # Associations
  belongs_to :creator, :class_name => 'User', :foreign_key => :created_by
  belongs_to :operator, :class_name => 'User' # :optional => true
  belongs_to :project, :class_name => 'Project'
  has_many :call_records, class_name: 'CallRecord'

  # Validations
  validates_inclusion_of :status, :in => STATUS.keys

  mount_uploader :file, FileUploader
  mount_uploader :file1, FileUploader
  mount_uploader :file2, FileUploader

  before_validation :setup, :on => :create

  after_save do
    project.last_update
  end

  # @return [Array, FileUploader]
  def files
    _files_ = []
    [:file, :file1, :file2].each do |attr|
      _file_ = self.send(attr)
      _files_ << _file_ if _file_.present?
    end
    _files_
  end

  def can_edit?
    status == 'ongoing'
  end

  def content_abstract
    max_length = 120
    first_line = content.split[0]
    first_line.length <= max_length ? first_line : "#{first_line[0,120]}..."
  end

  def to_api
    expose_fields(:id, :status, :category, :title, :content, :demand_number, :status, :priority, :project_id, :operator_id,
      files: files.map(&:url),
      created_at: created_at.strftime('%F %T'),
      operator: operator&.name_cn,
      call_records: CallRecord.where(project_requirement_id: id).order(id: :desc).map(&:to_api)
    )
  end

  def to_api_dashboard
    expose_fields(:id, :status, :category, :title, :content, :demand_number, :status, :priority, :project_id, :operator_id,
      files: files.map(&:url),
      created_at: created_at.strftime('%F %T'),
      operator: operator&.name_cn,
      call_records: call_records.order(id: :desc).map(&:to_api),
      company_name_abbr: project&.company&.name_abbr,
      project_name: project&.name,
      project_code: project&.code,
      client_contact: project&.main_client&.name,
      pm_name: project&.pm_users&.first&.name_cn
    )
  end

  def to_api_dashboard_index
    expose_fields(
      :id,  :title, :priority,
      company_name_abbr: project&.company&.name_abbr,
      project_name: project&.name,
      created_at: created_at.strftime('%F %T'),
    )
  end

  private
  def setup
    self.status ||= 'ongoing'
  end

end
