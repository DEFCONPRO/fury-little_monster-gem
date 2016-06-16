require 'spec_helper'

describe LittleMonster::RSpec::TaskHelper do
  let(:task_class) { MockJob::Task }
  let(:options) do
    {
      params: { a: :b },
      previous_output: { c: :d }
    }
  end

  describe described_class::Result do
    let(:task_instance) { double(run: double) }
    let!(:result) { described_class.new task_instance }

    describe '#initialize' do
      it 'sets task variable' do
        expect(result.instance_variable_get '@task').to eq(task_instance)
      end

      it 'calls run on task' do
        expect(task_instance).to have_received(:run)
      end

      it 'sets output variable to task run output' do
        expect(result.instance_variable_get '@output').to eq(task_instance.run)
      end
    end

    specify { expect(result.instance).to eq(task_instance) }
    specify { expect(result.output).to eq(task_instance.run) }
  end

  describe '::run_task' do
    context 'given a task and an options hash' do
      it 'builds an instance from task_class' do
        allow(task_class).to receive(:new).and_call_original
        run_task task_class
        expect(task_class).to have_received(:new)
      end

      it 'returns a task result instance' do
        expect(run_task(task_class).class).to eq(described_class::Result)
      end

      context 'returned task instance' do
        let(:task) { run_task(task_class, options).instance }

        it 'has params key from options' do
          expect(task.params).to eq(options[:params])
        end

        it 'has preveious output key from options' do
          expect(task.previous_output).to eq(options[:previous_output])
        end

        it 'has cancelled_callback to true if cancelled is true' do
          options[:cancelled] = true
          expect { task.is_cancelled! }.to raise_error(LittleMonster::CancelError)
        end
      end
    end
  end
end
