require 'rails_helper'

RSpec.describe DashboardPolicy do
  subject { described_class }

  let(:admin_role) { create(:user_role, name: 'admin') }
  let(:manager_role) { create(:user_role, name: 'manager') }
  let(:partner_role) { create(:user_role, name: 'partner') }
  let(:client_role) { create(:user_role, name: 'client') }
  
  let(:admin_user) { create(:user, role: admin_role) }
  let(:manager_user) { create(:user, role: manager_role) }
  let(:partner_user) { create(:user, role: partner_role) }
  let(:client_user) { create(:user, role: client_role) }
  
  let!(:partner) { create(:partner, user: partner_user) }
  let!(:other_partner) { create(:partner) }

  permissions :show? do
    it "разрешает доступ администраторам" do
      expect(subject).to permit(admin_user, :dashboard)
    end
    
    it "разрешает доступ менеджерам" do
      expect(subject).to permit(manager_user, :dashboard)
    end
    
    it "разрешает доступ партнерам" do
      expect(subject).to permit(partner_user, :dashboard)
    end
    
    it "запрещает доступ клиентам" do
      expect(subject).not_to permit(client_user, :dashboard)
    end
    
    it "запрещает доступ неавторизованным пользователям" do
      expect(subject).not_to permit(nil, :dashboard)
    end
  end
  
  permissions :show_partner_stats? do
    context "администратор" do
      it "имеет доступ к статистике любого партнера" do
        expect(subject).to permit(admin_user, :dashboard, partner: partner)
        expect(subject).to permit(admin_user, :dashboard, partner: other_partner)
      end
    end
    
    context "менеджер" do
      it "имеет доступ к статистике любого партнера" do
        expect(subject).to permit(manager_user, :dashboard, partner: partner)
        expect(subject).to permit(manager_user, :dashboard, partner: other_partner)
      end
    end
    
    context "партнер" do
      it "имеет доступ только к своей статистике" do
        expect(subject).to permit(partner_user, :dashboard, partner: partner)
        expect(subject).not_to permit(partner_user, :dashboard, partner: other_partner)
      end
    end
    
    context "клиент" do
      it "не имеет доступа к статистике партнеров" do
        expect(subject).not_to permit(client_user, :dashboard, partner: partner)
        expect(subject).not_to permit(client_user, :dashboard, partner: other_partner)
      end
    end
  end
end 