describe Fastlane::Actions::TranslateAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The translate plugin is working!")

      Fastlane::Actions::TranslateAction.run(nil)
    end
  end
end
