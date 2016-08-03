require_relative '../../../../lib/little_monster/helpers/counters'
describe LittleMonster::Counters do 
  let(:dummy_class) do 
    Class.new do 
      include LittleMonster::Counters
      def initialize
        @job_id=1
      end
    end.new
  end

  context '.increase_count' do
    context 'success' do 
      def success_mock(status='success', output='')
        expect(LittleMonster::Core::API).to receive(:put)
        .with('/jobs/1/counters/my_counter',{ type: status, output: output})
        .and_return(Typhoeus::Response.new(code:200)).once
      end

      it 'Put to LM api' do
        success_mock
        dummy_class.increase_counter('my_counter','success')
      end

      it 'add 1 when succeded' do
        success_mock
        dummy_class.increase_counter('my_counter','success')
        #resp = 
      end

      it 'add 1 when status fail' do 
        success_mock('fail')
        dummy_class.increase_counter('my_counter','fail')
      end

      it 'allows send output' do 
        output="my fake output"
        success_mock('fail',output)
        dummy_class.increase_counter('my_counter','fail', output)
      end
    end

    it 'raise CounterError on duplicate unique_id' do
      ret = Typhoeus::Response.new(code:412)

      expect(LittleMonster::Core::API).to(receive(:put))
      .with('/jobs/1/counters/my_counter',{ type: 'fail',output: ''})
      .and_return(ret)

      expect { dummy_class.increase_counter('my_counter','fail')}
      .to raise_error LittleMonster::Counters::DuplicatedCounterError
    end


    it 'fails if couldn\'t send counter to the api' do 
      expect(LittleMonster::Core::API).to(receive(:put))
      .and_raise(LittleMonster::Core::API::FuryHttpApiError)
      expect { dummy_class.increase_counter('my_counter','fail')}.to raise_error LittleMonster::Counters::ApiError
    end
  end

  context 'counter' do 
    let(:response) do
      { "name":"pepe",
        "total":1,
        "failed": { 
          "total":0,
          "outputs":[]
        },
        "succeeded":{
          "total":1,
          "outputs":[{
            "unique_id":"fake_unique",
            "output":"fake_output"}]}}
    end

    context :success do 
      before :each do 
        expect(LittleMonster::Core::API).to receive(:get)
        .with('/jobs/1/counters/my_counter')
        .and_return(Typhoeus::Response.new(body:response,code:200))
      end

      it 'has to return counter with total, failed and succeed' do 
        expect(dummy_class.counter('my_counter')).to include(:total,:failed,:succeeded)
      end

      it 'succeeded has total and output' do 
        expect(dummy_class.counter('my_counter')[:succeeded]).to include(:total,:outputs)
      end

      it 'failed has total and output' do 
        expect(dummy_class.counter('my_counter')[:succeeded]).to include(:total,:outputs)
      end
    end

    it 'fails if counter doesnt exist' do 
        expect(LittleMonster::Core::API).to receive(:get)
        .with('/jobs/1/counters/my_fake_counter').and_return Typhoeus::Response.new(code:404)
        expect { dummy_class.counter('my_fake_counter') }.to raise_error LittleMonster::Counters::MissedCounterError
    end
  end
end
