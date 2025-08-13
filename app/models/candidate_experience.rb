# encoding: utf-8
class CandidateExperience < ApplicationRecord
  # ENUM
  CATEGORY = %w[work project education hospital]

  # Associations
  belongs_to :candidate, :class_name => 'Candidate'

  # Validations
  validates_inclusion_of :category, :in => CATEGORY
  # validates_presence_of  :org_cn

  # Scope
  scope :work, -> { where(category: 'work') }
  scope :project, -> { where(category: 'project') }
  scope :education, -> { where(category: 'education') }
  scope :hospital, -> { where(category: 'hospital') }


  def friendly_timestamp(strftime='%F')
    "#{started_at ? started_at.strftime(strftime) : nil} - #{ended_at ? ended_at.strftime(strftime) : I18n.t(:up_to_now)}"
  end

  def org_instance
    return nil unless org_id
    case category
    when 'hospital' then Hospital.find_by(id: org_id)
    else nil
    end
  end

  def dep_instance
    return nil unless dep_id
    case category
    when 'hospital' then HospitalDepartment.find_by(id: dep_id)
    end
  end

  def to_api
    expose_fields(:id, :category, :org_cn, :org_en, :department, :title, :title1, :description, :org_id, :dep_id,
      started_at: started_at&.strftime('%F %T'),
      ended_at: ended_at&.strftime('%F %T')
    )
  end

end
