class ProjectsPageQuery
  # 允许外部读取这些属性
  attr_reader :params, :current_user, :query

  # 初始化时接收 Controller 传来的参数
  def initialize(params, current_user, query = nil)
    @params = params
    @current_user = current_user
    # 允许传入一个初始的 relation，如果没传，就根据用户角色决定
    @query = query || base_query
  end

  # 这是主要的公共方法，返回最终的查询结果（一个 ActiveRecord::Relation 对象）
  def results
    page = Integer(@params[:page]) rescue 1
    per_page = Integer(@params[:per_page]) rescue 10

    if [true, 'true', 1, '1'].include?(@params[:mine])
      @query = @current_user.projects
    end

    if [true, 'true', 1, '1'].include?(params[:is_rec])
      @query = @query.joins(:call_records).where('call_records.rec_status': 'recommended').distinct
    end

    if @params[:status_list].present?
      @query = @query.where(status: @params[:status_list])
    end

    %w[name code].each do |field|
      @query = @query.where("projects.#{field} ILIKE ?", "%#{@params[field].strip}%") if @params[field].present?
    end
    %w[id status user_channel_id].each do |field|
      @query = @query.where("projects.#{field}" => @params[field]) if @params[field].present?
    end
    if @params[:created_at_ge].present?
      @query = @query.where('projects.created_at >= ?', @params[:created_at_ge]) if @params[:created_at_ge].present?
      @query = @query.where('projects.created_at <= ?', @params[:created_at_le]) if @params[:created_at_le].present?
    end
    if @params[:company_name_abbr].present?
      @query = @query.joins(:company).where('companies.name ILIKE :company OR companies.name_abbr ILIKE :company', { company: "%#{@params[:company_name_abbr].strip}%" })
    end
    if @params[:company].present?
      @query = @query.joins(:company).where('companies.name ILIKE :company OR companies.name_abbr ILIKE :company', { company: "%#{@params[:company].strip}%" })
    end
    if @params[:client_contact].present?
      @query = @query.joins(:candidates).where('candidates.category': 'client')
                       .where('candidates.name ILIKE ?', "%#{@params[:client_contact].strip}%").distinct
    end
    if @params[:client_id].present?
      @query = @query.joins(:project_candidates).where('project_candidates.category': 'client', 'project_candidates.candidate_id': @params[:client_id]).distinct
    end
    if [true, 'true', 1, '1'].include?(@params[:is_rec])
      @query = @query.joins(:call_records).where('call_records.rec_status': 'recommended').distinct
    end

    join_sql = "LEFT OUTER JOIN project_marks ON project_marks.project_id = projects.id AND project_marks.user_id = #{@current_user.id}"
    @query = @query.joins(join_sql)

    order_sql = <<~SQL.squish
          CASE
          WHEN project_marks.mark_type = 'top' THEN 1
          WHEN project_marks.mark_type = 'hold' THEN 3
          ELSE 2
        END,
        project_marks.updated_at desc,
        projects.id DESC
      SQL

    projects = @query.order(Arel.sql(order_sql)).paginate(page: page, per_page: per_page)

    {
      projects: projects.map { |project| project.to_api(@current_user) },
      total: @query.count,
      page: page,
      per_page: per_page
    }
  end

  private

  # 建立基础查询范围
  def base_query
    (@current_user.admin? || @current_user.is_role?('pd')) ? Project.all : @current_user.projects
  end

end