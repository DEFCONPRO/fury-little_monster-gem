module LittleMonster::Core
  class Job::Factory
    def initialize(message = {})
      @id = message[:id]
      @name = message[:name]
      @tags = message[:tags]

      @api_attributes = fetch_attributes
      @job_class = @name.to_s.camelcase.constantize

      #this gets saved for development run and debugging purposes
      @input_data = message[:data]
    end

    def build
      return unless should_build?

      notify_job_task_list

      @job_class.new job_attributes
    end

    def notify_job_task_list
      return true if !(@api_attributes[:tasks].blank? && should_request?)

      params = {
        body: {
          tasks: @job_class.tasks.each_with_index.map { |task, index| { name: task, order: index } }
        },
      }

      res = LittleMonster::API.post "/jobs/#{@id}/tasks", params, retries: LittleMonster.job_requests_retries,
                                                                   retry_wait: LittleMonster.job_requests_retry_wait,
                                                                   critical: true
      res.success?
    end

    def fetch_attributes
      return {} unless should_request?
      resp = API.get "/jobs/#{@id}", {}, retries: LittleMonster.job_requests_retries,
                                         retry_wait: LittleMonster.job_requests_retry_wait,
                                         critical: true

      resp.success? ? resp.body : nil
    end

    def find_current_task
      return { name: @job_class.tasks.first, retries: 0 } if @api_attributes[:tasks].blank?

      task_index = @api_attributes.fetch(:tasks, []).sort_by! { |task| task[:order] }.find_index do |task|
        task[:status] == 'pending'
      end
      return {} if task_index.nil?

      {
        name: @api_attributes[:tasks][task_index][:name].to_sym,
        retries: @api_attributes[:tasks][task_index][:retries]
      }
    end

    def job_attributes
      data = if !@api_attributes[:data].nil?
               MultiJson.load @api_attributes[:data], symbolize_keys: true
             else
               @input_data
             end

      attributes = {
        id: @id,
        data: data,
        tags: @tags,
      }

      if %w(development test).include? LittleMonster.env
        attributes
      else
        current_task = find_current_task
        attributes.merge(current_task: current_task[:name],
                         retries: current_task[:retries])

      end
    end

    def should_build?
      !@api_attributes.nil? && @api_attributes.fetch(:status, 'pending') == 'pending'
    end

    def should_request?
      !%w(development test).include?(LittleMonster.env)
    end
  end
end
