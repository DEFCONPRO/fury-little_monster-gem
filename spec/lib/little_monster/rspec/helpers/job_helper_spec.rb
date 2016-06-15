require 'spec_helper'

describe LittleMonster::RSpec::JobHelper do
  let(:job_class) { MockJob }
  let(:options) do
    {
      params: { a: :b }
    }
  end

  describe LittleMonster::RSpec::JobHelper::Result do
    let(:job) { job_class.new(nil) }
    let(:result) { described_class.new job }

    describe '#initalize' do
      it 'sets job' do
        expect(result.instance_variable_get('@job')).to eq(job)
      end

      it 'runs job' do
        allow(job).to receive(:run).and_call_original
        result
        expect(job).to have_received(:run)
      end

      context 'if job run raises a retry error' do
        it 'sets retried to true' do
          allow(job).to receive(:run).and_raise(LittleMonster::JobRetryError)
          expect(result.instance_variable_get('@retried')).to be true
        end
      end
    end

    specify { expect(result.instance).to eq(job) }
    specify { expect(result.retried?).to eq(result.instance_variable_get('@retried')) }
    specify { expect(result.status).to eq(job.status) }
    specify { expect(result.retries).to eq(job.instance_variable_get('@retries')) }
    specify { expect(result.output).to eq(job.output) }
  end


  describe '::run_job' do
    context 'given a job name and hash' do
      context 'when job is a symbol' do
        it 'builds job class out of symbol' do
          allow(job_class).to receive(:new).and_call_original
          run_job job_class.to_s.underscore, options
          expect(job_class).to have_received(:new)
        end
      end

      it 'calls mock! on job' do
        allow(job_class).to receive(:mock!).and_call_original
        run_job job_class, options
        expect(job_class).to have_received(:mock!)
      end

      it 'builds an instance of the job' do
        allow(job_class).to receive(:new).and_call_original
        run_job job_class.to_s.underscore, options
        expect(job_class).to have_received(:new).with(options[:params])
      end

      context 'instance' do
        let(:job) { run_job(job_class, options).instance }

        it 'returns cancelled true if options cancelled is true' do
          options[:cancelled] = true
          expect(job.is_cancelled?).to be true
        end

        it 'returns cancelled false if options cancelled is false' do
          options[:cancelled] = false
          expect(job.is_cancelled?).to be false
        end

        it 'returns cancelled false if options cancelled is nil' do
          expect(job.is_cancelled?).to be false
        end

        it 'has retries variable set if options has retries' do
          options[:retry] = 10
          expect(job.instance_variable_get('@retries')).to eq(options[:retry])
        end

        context 'given fail key in options' do
          it 'makes each task fail' do
            options[:fails] = [{ task: :task_a }]
            expect(job.instance_variable_get('@runned_tasks').keys).to eq([])
          end

          it 'makes tasks fails with specified expection' do
            options[:fails] = [{ task: :task_a, error: LittleMonster::TaskError }]
            run_job(job_class, options)
            expect { MockJob::TaskA.new(nil, nil).perform }.to raise_error(LittleMonster::TaskError)
          end

          it 'makes each job fails with standard error when no exception is provided' do
            options[:fails] = [{ task: :task_a }]
            run_job(job_class, options)
            expect { MockJob::TaskA.new(nil, nil).perform }.to raise_error(StandardError)
          end
        end
      end

      context 'output' do
        let(:job) { job_class.new(nil) }

        before :each do
          allow(job_class).to receive(:new).and_return(job)
        end

        it 'returns a result wrapper' do
          expect(run_job(job_class, options).class).to eq(LittleMonster::RSpec::JobHelper::Result)
        end

        it 'has a job instance in the result wrapper' do
          expect(run_job(job_class, options).instance).to eq(job)
        end
      end
    end
  end
end
