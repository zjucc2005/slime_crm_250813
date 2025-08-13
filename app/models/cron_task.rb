# frozen_string_literal: true

class CronTask
  ##
  # 各批处理执行主方法
  # 外部调用方式
  # rails runner -e production  "CronTask.my_method"

  # 每日定时任务
  # 0 0 * * * /bin/bash -l -c 'source ~/.bashrc && cd /opt/rails-app/slime_crm_hf && rvm use 2.6.0 && rails runner -e production '\''CronTask.daily_cron'\'' >> /opt/rails-app/slime_crm_hf/log/cron.log 2>&1'
  def self.daily_cron
    update_expired_candidate_coef
  end

  # 更新失去新专家资格的权重
  # 条件 1 - coef >= 2
  # 条件 2 - 新建超过 30 天
  def self.update_expired_candidate_coef
    puts "#{Time.now.strftime('%F %T')} - update_expired_candidate_coef:start..."
    candidates = Candidate.where(category: %w[expert doctor]).where('coef >= 2').where('created_at < ?', Time.now - 30.days)
    succ_count = 0
    fail_count = 0
    candidates.each do |candidate|
      # candidate.save ? succ_count += 1 : fail_count += 1
      prev_coef = candidate.coef
      if candidate.save
        puts "  ##{candidate.id}:#{candidate.name},[#{prev_coef}] => [#{candidate.coef}]"
        succ_count += 1
      else
        fail_count += 1
      end
    end
    puts "#{Time.now.strftime('%F %T')} - update_expired_candidate_coef succ: #{succ_count}, fail: #{fail_count}"
  end

end