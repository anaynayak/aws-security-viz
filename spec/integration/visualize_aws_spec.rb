require 'spec_helper'
require 'tempfile'

describe VisualizeAws do
  let(:opts) {
    {
        :source_file => source_file,
        :filename => temp_file
    }
  }
  let(:source_file) { File.join(File.dirname(__FILE__), 'dummy.json') }
  let(:config) { AwsConfig.new({groups: {'0.0.0.0/0' => '*'}}) }
  let(:expected_content) { File.read(expected_file) }
  let(:actual_content) { temp_file.read }

  context 'json to dot file' do
    let(:expected_file) { File.join(File.dirname(__FILE__), 'dummy.dot') }
    let(:temp_file) { Tempfile.new(%w(aws .dot)) }

    it 'should parse json input', :integration => true do
      VisualizeAws.new(config, opts).unleash(temp_file.path)
      expect(expected_content).to eq(actual_content)
    end
  end

  context 'json to json file' do
    let(:expected_file) { File.join(File.dirname(__FILE__), 'expected.json') }
    let(:temp_file) { Tempfile.new(%w(aws .json)) }

    it 'should parse json input', :integration => true do
      expect(FileUtils).to receive(:copy)
      VisualizeAws.new(config, opts).unleash(temp_file.path)
      expect(JSON.parse(expected_content)).to eq(JSON.parse(actual_content))
    end
  end

  if ENV['TEST_ACCESS_KEY']
    context 'ec2 to json file' do
      let(:expected_file) { File.join(File.dirname(__FILE__), 'aws_expected.json') }
      let(:temp_file) { Tempfile.new(%w(aws .json)) }
      let(:opts) {
        {
            :filename => temp_file,
            :secret_key => ENV['TEST_SECRET_KEY'],
            :access_key => ENV['TEST_ACCESS_KEY']
        }
      }

      it 'should read from ec2 account', :integration => true do
        expect(FileUtils).to receive(:copy)
        VisualizeAws.new(config, opts).unleash(temp_file.path)
        expect(JSON.parse(expected_content)['edges']).to match_array(JSON.parse(actual_content)['edges'])
        expect(JSON.parse(expected_content)['nodes']).to match_array(JSON.parse(actual_content)['nodes'])
      end
    end
  end
end
