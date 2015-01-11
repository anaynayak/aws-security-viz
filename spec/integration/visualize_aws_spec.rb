require 'spec_helper'

describe VisualizeAws do
  context 'json' do
    let(:opts) {
      {
        :source_file => source_file,
        :filename => temp_file
      }
    }
    let(:source_file) {File.join(File.dirname(__FILE__), 'dummy.json')}
    let(:expected_file) {File.join(File.dirname(__FILE__), 'dummy.dot')}
    let(:temp_file) { Tempfile.new(%w(aws .dot)) }

    it 'should parse json input', :integration => true do
      VisualizeAws.new(opts).unleash(temp_file.path)

      expect(File.read(expected_file)).to eq(temp_file.read)
    end
  end
end
