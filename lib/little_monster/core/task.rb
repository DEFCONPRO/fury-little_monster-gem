module LittleMonster::Core
  class Task
    include Loggable

    attr_reader :data
    attr_reader :job_id

    def initialize(data, job_id = nil)
      @data = data
      @job_id = job_id
    end

    def run
      raise NotImplementedError, 'You must implement the run method'
    end

    def on_error(error)
    end

    def error(e)
      logger.error e
      on_error e
    end

    def is_cancelled?
      @cancelled_callback.nil? ? false : @cancelled_callback.call
    end

    def is_cancelled!
      raise CancelError if is_cancelled?
    end

    private

    def set_default_values(data, job_id = nil, job_logger = nil, cancelled_callback = nil)
      @cancelled_callback = cancelled_callback
      @job_id = job_id
      @data = data
      logger.parent_logger = job_logger if job_logger
      logger.default_tags.merge!(type: 'task_log')
    end
  end
end
