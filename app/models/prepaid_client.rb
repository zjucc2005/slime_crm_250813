class PrepaidClient < ApplicationRecord
  belongs_to :company
  mount_uploader :invoice_file, FileUploader

  validates :total_hours, presence: true, numericality: { greater_than: 0 }
  validates :invoice_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :advance_payment_hours, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  def used_hours
    total_hours = 0.0
    company.projects.each do |project|
      project.project_tasks.where(status: 'finished').each do |task|
        contract = project.active_contract
        next unless contract

        charge_duration = task.charge_duration.to_i
        base_duration = contract.base_duration.split(',').map(&:to_i).sort.first
        progressive_duration = contract.progressive_duration.to_i

        if charge_duration <= base_duration
          total_hours += base_duration.to_f / 60.0
        else
          extra_duration = ((charge_duration - base_duration).to_f / progressive_duration).ceil * progressive_duration
          total_hours += (base_duration + extra_duration).to_f / 60.0
        end
      end
    end
    total_hours.round(3)
  end

  def remaining_hours
    total_hours - used_hours - advance_payment_hours
  end
end