require 'toiler'

module LittleMonster
  class Worker
    include LittleMonster::Loggable
    include ::Toiler::Worker

    toiler_options queue: LittleMonster.worker_queue

    toiler_options concurrency: LittleMonster.worker_concurrency

    toiler_options auto_visibility_timeout: true,
                   auto_delete: true

    toiler_options parser: MultiJson

    def initialize
    end

    def on_message
    end

    def perform(_sqs_msg, body)
      message = MultiJson.load body['Message'], symbolize_keys: true
      message[:params] = MultiJson.load message[:params], symbolize_keys: true

      begin
        send_heartbeat! message[:id]
      rescue LittleMonster::JobAlreadyLockedError => e
        logger.error e.message
        return
      end

      on_message

      job = LittleMonster::Job::Factory.new(message).build
      job.run unless job.nil?
    end

    def send_heartbeat!(id)
      resp = LittleMonster::API.put "/jobs/#{id}", critical: true, body: {
          worker: {
            ip: Addrinfo.ip(Socket.gethostname).ip_address,
            worker: Process.pid
          }
      }

      raise LittleMonster::JobAlreadyLockedError, "job [id:#{id}] is already locked, discarding" if resp.code == 401
    end
  end
end
