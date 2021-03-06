require 'spec_helper'

describe Namespace, models: true do
  let!(:namespace) { create(:namespace) }

  it { is_expected.to have_many :projects }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }

  it { is_expected.to validate_length_of(:description).is_at_most(255) }

  it { is_expected.to validate_presence_of(:path) }
  it { is_expected.to validate_uniqueness_of(:path) }
  it { is_expected.to validate_length_of(:path).is_at_most(255) }

  it { is_expected.to validate_presence_of(:owner) }

  describe "Mass assignment" do
  end

  describe "Respond to" do
    it { is_expected.to respond_to(:human_name) }
    it { is_expected.to respond_to(:to_param) }
  end

  describe '#to_param' do
    it { expect(namespace.to_param).to eq(namespace.path) }
  end

  describe '#human_name' do
    it { expect(namespace.human_name).to eq(namespace.owner_name) }
  end

  describe '.search' do
    let(:namespace) { create(:namespace) }

    it 'returns namespaces with a matching name' do
      expect(described_class.search(namespace.name)).to eq([namespace])
    end

    it 'returns namespaces with a partially matching name' do
      expect(described_class.search(namespace.name[0..2])).to eq([namespace])
    end

    it 'returns namespaces with a matching name regardless of the casing' do
      expect(described_class.search(namespace.name.upcase)).to eq([namespace])
    end

    it 'returns namespaces with a matching path' do
      expect(described_class.search(namespace.path)).to eq([namespace])
    end

    it 'returns namespaces with a partially matching path' do
      expect(described_class.search(namespace.path[0..2])).to eq([namespace])
    end

    it 'returns namespaces with a matching path regardless of the casing' do
      expect(described_class.search(namespace.path.upcase)).to eq([namespace])
    end
  end

  describe '#move_dir' do
    before do
      @namespace = create :namespace
      @project = create :project, namespace: @namespace
      allow(@namespace).to receive(:path_changed?).and_return(true)
    end

    it "raises error when directory exists" do
      expect { @namespace.move_dir }.to raise_error("namespace directory cannot be moved")
    end

    it "moves dir if path changed" do
      new_path = @namespace.path + "_new"
      allow(@namespace).to receive(:path_was).and_return(@namespace.path)
      allow(@namespace).to receive(:path).and_return(new_path)
      expect(@namespace.move_dir).to be_truthy
    end

    context "when any project has container tags" do
      before do
        stub_container_registry_config(enabled: true)
        stub_container_registry_tags('tag')

        create(:empty_project, namespace: @namespace)

        allow(@namespace).to receive(:path_was).and_return(@namespace.path)
        allow(@namespace).to receive(:path).and_return('new_path')
      end

      it { expect { @namespace.move_dir }.to raise_error('Namespace cannot be moved, because at least one project has tags in container registry') }
    end
  end

  describe :rm_dir do
    let!(:project) { create(:project, namespace: namespace) }
    let!(:path) { File.join(Gitlab.config.repositories.storages.default, namespace.path) }

    before { namespace.destroy }

    it "removes its dirs when deleted" do
      expect(File.exist?(path)).to be(false)
    end
  end

  describe '.find_by_path_or_name' do
    before do
      @namespace = create(:namespace, name: 'WoW', path: 'woW')
    end

    it { expect(Namespace.find_by_path_or_name('wow')).to eq(@namespace) }
    it { expect(Namespace.find_by_path_or_name('WOW')).to eq(@namespace) }
    it { expect(Namespace.find_by_path_or_name('unknown')).to eq(nil) }
  end

  describe ".clean_path" do
    let!(:user)       { create(:user, username: "johngitlab-etc") }
    let!(:namespace)  { create(:namespace, path: "JohnGitLab-etc1") }

    it "cleans the path and makes sure it's available" do
      expect(Namespace.clean_path("-john+gitlab-ETC%.git@gmail.com")).to eq("johngitlab-ETC2")
      expect(Namespace.clean_path("--%+--valid_*&%name=.git.%.atom.atom.@email.com")).to eq("valid_name")
    end
  end

  describe '#full_path' do
    let(:group) { create(:group) }
    let(:nested_group) { create(:group, parent: group) }

    it { expect(group.full_path).to eq(group.path) }
    it { expect(nested_group.full_path).to eq("#{group.path}/#{nested_group.path}") }
  end
end
