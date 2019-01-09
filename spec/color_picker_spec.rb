require 'spec_helper'

describe ColorPicker do
    context 'default picker' do
        let(:picker) { ColorPicker.new(false) }

        it 'should add default colors for edges' do
            expect(picker.color(0, true)).to eq(:blue)
            expect(picker.color(0, false)).to eq(:red)
        end
    end
    context 'color picker' do
        let(:picker) { ColorPicker.new(true) }

        it 'should add default colors for edges' do
            expect(picker.color(0, 'ignore')).to eq('#00004c')
            expect(picker.color(10000, 'ignore')).to eq('#C76F5B')
        end
    end
end