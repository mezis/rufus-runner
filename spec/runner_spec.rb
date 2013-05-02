require 'spec_helper'
require 'rufus-runner'

describe 'rufus-runner' do
  STAMP_FILE = Pathname.new 'tmp/stamp'

  shared_examples_for 'killable' do
    it 'finishes cleanly on SIGINT' do
      run_schedule
      wait_for_file STAMP_FILE or raise
      signal_schedule 'INT'
      wait_schedule.should == 0
    end

    it 'finishes cleanly on SIGTERM' do
      run_schedule
      wait_for_file STAMP_FILE or raise
      signal_schedule 'TERM'
      wait_schedule.should == 0
    end
  end


  context 'without a schedule' do
    it 'exits with error' do
      raise 'this should not happen' if ScheduleHelper::TEST_SCHEDULE.exist?
      run_schedule
      wait_schedule.should_not == 0
    end
  end

  context 'with a bad schedule' do
    before do
      create_schedule %Q{
        this is English, not ruby
      }
    end

    it 'exits with error' do
      run_schedule
      wait_schedule.should_not == 0
    end
  end

  context 'with an empty schedule' do
    before do
      create_schedule %Q{
        Pathname.timestamp('#{STAMP_FILE}')

        Rufus::TrackingScheduler.start do |scheduler|
        end
      }
    end

    it 'starts' do
      expect_new_file STAMP_FILE do
        run_schedule
      end
    end

    it_should_behave_like 'killable'
  end

  context 'with simple jobs' do
    let(:stamp_job_1) { Pathname.new('tmp/stamp1') }
    let(:stamp_job_2) { Pathname.new('tmp/stamp2') }
    let(:stamp_job_3) { Pathname.new('tmp/stamp3') }

    before do
      create_schedule %Q{
        Pathname.timestamp('#{STAMP_FILE}')

        Rufus::TrackingScheduler.start(:timeout => 10) do |scheduler|
          scheduler.run :name => 'job_1', :every => '1s' do
            Pathname.timestamp('#{stamp_job_1}')
          end

          scheduler.run :name => 'job_2', :every => '1s' do
            Pathname.timestamp('#{stamp_job_2}')
            Kernel.sleep 2
            Pathname.timestamp('#{stamp_job_2}')
          end

          scheduler.run :name => 'job_3', :every => '1s' do
            Pathname.timestamp('#{stamp_job_3}')
            Kernel.sleep 60
            Pathname.timestamp('#{stamp_job_3}')
          end
        end
      }
    end

    after do
      stamp_job_1.delete_if_exist
      stamp_job_2.delete_if_exist
      stamp_job_3.delete_if_exist
    end

    it_should_behave_like 'killable'

    context do
      before do
        run_schedule
        wait_for_file STAMP_FILE or raise
      end
  
      it 'runs jobs' do
        wait_for_file(STAMP_FILE).should be_true
      end

      it 'waits for long-running jobs to complete' do
        # wait for job 2 to start
        wait_for_file(stamp_job_2).should be_true
        stamp_job_2.delete
        # ask scheduler to die
        signal_schedule 'TERM'
        # stamp file should reappear as job 2 completes
        wait_for_file(stamp_job_2).should be_true
      end

      it 'does not run jobs in parallel' do
        wait_for_file(stamp_job_2).should be_true # XXX remove expectation here
        stamp_job_1.delete
        Kernel.sleep 1
        stamp_job_1.should_not exist
      end

      it 'kills long-running jobs' do
        wait_for_file(stamp_job_3).should be_true # XXX remove expectation here
        stamp_job_3.delete
        signal_schedule 'TERM'
        wait_for_file(stamp_job_3).should be_false
      end

      xit 'logs jobs starting and ending'
      xit 'logs jobs failing'
    end
  end
end

