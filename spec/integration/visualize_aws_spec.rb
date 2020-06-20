require 'spec_helper'
require 'tempfile'

RSpec::Matchers.define :be_graph_with do |nodes|
  match do |graphv|
    graphv.nodes.keys == nodes
  end
end

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

    def without_pos(data)
      return data
        .gsub(/pos=\"[a-z,0-9\.\s]*\"/, '')
        .gsub(/\s{2,}/, ' ') # trim spaces
        .gsub(/\t/, ' ') # remove tabs
    end

    it 'should parse json input', :integration => true do
      VisualizeAws.new(config, opts).unleash(temp_file.path)
      expect(without_pos(expected_content)).to eq(without_pos(actual_content))
    end
    
    it 'should parse json input with stubbed out graphviz' do
      nodes = ["app", "8.8.8.8/32", "amazon-elb-sg", "*", "db"]
      allow(Graphviz).to receive(:output).with(be_graph_with(nodes), path: temp_file.path, format: nil)
      VisualizeAws.new(config, opts).unleash(temp_file.path)
    end
  end

  context 'json to json file' do
    let(:expected_file) { File.join(File.dirname(__FILE__), 'expected.json') }
    let(:temp_file) { Tempfile.new(%w(aws .json)) }

    it 'should parse json input' do
      expect(FileUtils).to receive(:copy)
      VisualizeAws.new(config, opts.merge(:renderer => 'json')).unleash(temp_file.path)
      expect(JSON.parse(expected_content)).to eq(JSON.parse(actual_content))
    end

    it 'should parse json input with obfuscation' do
      config = AwsConfig.new({groups: {'0.0.0.0/0' => '*'}, obfuscate: true})
      expect(FileUtils).to receive(:copy)
      VisualizeAws.new(config, opts.merge(:renderer => 'json')).unleash(temp_file.path)
      expect(actual_content).not_to include('"amazon-elb-sg"', '"app"', '"db"')
    end

  end

  context 'json to navigator file' do
    let(:expected_file) { File.join(File.dirname(__FILE__), 'navigator.json') }
    let(:temp_file) { Tempfile.new(%w(aws .json)) }

    it 'should parse json input' do
      expect(FileUtils).to receive(:copy)
      VisualizeAws.new(config, opts.merge(:renderer => 'navigator')).unleash(temp_file.path)
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
            :access_key => ENV['TEST_ACCESS_KEY'],
            :region => 'us-east-1'
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
