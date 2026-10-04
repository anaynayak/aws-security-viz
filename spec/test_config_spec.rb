# frozen_string_literal: true

require "spec_helper"

describe "test suite configuration" do
  it "runs with Ruby warnings enabled" do
    expect($VERBOSE).to be true
  end
end
