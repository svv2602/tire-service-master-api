require 'rails_helper'

RSpec.describe ServicePost, type: :model do
  let(:service_point) { create(:service_point) }
  let(:service_post) { build(:service_post, service_point: service_point) }

  describe 'индивидуальное расписание' do
    describe 'валидации' do
      context 'когда has_custom_schedule отключено' do
        it 'валиден без working_days и custom_hours' do
          service_post.has_custom_schedule = false
          service_post.working_days = nil
          service_post.custom_hours = nil
          expect(service_post).to be_valid
        end
      end

      context 'когда has_custom_schedule включено' do
        before { service_post.has_custom_schedule = true }

        describe 'working_days валидация' do
          it 'валиден с корректными рабочими днями' do
            service_post.working_days = {
              'monday' => true,
              'tuesday' => false,
              'wednesday' => true
            }
            service_post.custom_hours = { 'start' => '09:00', 'end' => '18:00' }
            expect(service_post).to be_valid
          end

          it 'не валиден с некорректным форматом working_days' do
            service_post.working_days = "invalid"
            expect(service_post).not_to be_valid
            expect(service_post.errors[:working_days]).to include('должно быть объектом')
          end

          it 'не валиден с некорректными днями недели' do
            service_post.working_days = { 'invalid_day' => true }
            service_post.custom_hours = { 'start' => '09:00', 'end' => '18:00' }
            expect(service_post).not_to be_valid
            expect(service_post.errors[:working_days]).to include('содержит недопустимый день недели: invalid_day')
          end

          it 'не валиден с некорректными значениями дней' do
            service_post.working_days = { 'monday' => 'yes' }
            service_post.custom_hours = { 'start' => '09:00', 'end' => '18:00' }
            expect(service_post).not_to be_valid
            expect(service_post.errors[:working_days]).to include('значение для monday должно быть true или false')
          end

          it 'требует хотя бы один рабочий день' do
            service_post.working_days = {
              'monday' => false,
              'tuesday' => false,
              'wednesday' => false,
              'thursday' => false,
              'friday' => false,
              'saturday' => false,
              'sunday' => false
            }
            service_post.custom_hours = { 'start' => '09:00', 'end' => '18:00' }
            expect(service_post).not_to be_valid
            expect(service_post.errors[:working_days]).to include('должен быть выбран хотя бы один рабочий день')
          end
        end

        describe 'custom_hours валидация' do
          before do
            service_post.working_days = { 'monday' => true }
          end

          it 'валиден с корректными часами' do
            service_post.custom_hours = { 'start' => '09:00', 'end' => '18:00' }
            expect(service_post).to be_valid
          end

          it 'не валиден с некорректным форматом custom_hours' do
            service_post.custom_hours = "invalid"
            expect(service_post).not_to be_valid
            expect(service_post.errors[:custom_hours]).to include('должно быть объектом')
          end

          it 'требует поле start' do
            service_post.custom_hours = { 'end' => '18:00' }
            expect(service_post).not_to be_valid
            expect(service_post.errors[:custom_hours]).to include('должно содержать поле start')
          end

          it 'требует поле end' do
            service_post.custom_hours = { 'start' => '09:00' }
            expect(service_post).not_to be_valid
            expect(service_post.errors[:custom_hours]).to include('должно содержать поле end')
          end

          it 'не валиден с некорректным форматом времени' do
            service_post.custom_hours = { 'start' => '9:00', 'end' => '18:00' }
            expect(service_post).not_to be_valid
            expect(service_post.errors[:custom_hours]).to include('start должно быть в формате HH:MM')
          end

          it 'не валиден когда время начала больше времени окончания' do
            service_post.custom_hours = { 'start' => '19:00', 'end' => '18:00' }
            expect(service_post).not_to be_valid
            expect(service_post.errors[:custom_hours]).to include('время начала должно быть меньше времени окончания')
          end
        end
      end
    end

    describe 'скоупы' do
      describe '.with_custom_schedule' do
        let!(:custom_post) { create(:service_post, service_point: service_point, has_custom_schedule: true) }
        let!(:regular_post) { create(:service_post, service_point: service_point, has_custom_schedule: false) }

        it 'возвращает только посты с индивидуальным расписанием' do
          expect(ServicePost.with_custom_schedule).to include(custom_post)
          expect(ServicePost.with_custom_schedule).not_to include(regular_post)
        end
      end
    end

    describe 'методы индивидуального расписания' do
      let(:service_point_with_schedule) do
        create(:service_point, working_hours: {
          'monday' => { 'start' => '08:00', 'end' => '17:00', 'is_working_day' => true },
          'tuesday' => { 'start' => '08:00', 'end' => '17:00', 'is_working_day' => true },
          'wednesday' => { 'start' => '08:00', 'end' => '17:00', 'is_working_day' => false }
        })
      end

      let(:post_with_custom_schedule) do
        create(:service_post, 
          service_point: service_point_with_schedule,
          has_custom_schedule: true,
          working_days: {
            'monday' => true,
            'tuesday' => false,
            'wednesday' => true
          },
          custom_hours: {
            'start' => '10:00',
            'end' => '19:00'
          }
        )
      end

      let(:post_without_custom_schedule) do
        create(:service_post, 
          service_point: service_point_with_schedule,
          has_custom_schedule: false
        )
      end

      describe '#working_on_day?' do
        context 'с индивидуальным расписанием' do
          it 'возвращает true для рабочих дней' do
            expect(post_with_custom_schedule.working_on_day?('monday')).to be true
            expect(post_with_custom_schedule.working_on_day?('wednesday')).to be true
          end

          it 'возвращает false для нерабочих дней' do
            expect(post_with_custom_schedule.working_on_day?('tuesday')).to be false
          end
        end

        context 'без индивидуального расписания' do
          it 'всегда возвращает true' do
            expect(post_without_custom_schedule.working_on_day?('monday')).to be true
            expect(post_without_custom_schedule.working_on_day?('wednesday')).to be true
          end
        end
      end

      describe '#start_time_for_day и #end_time_for_day' do
        context 'с индивидуальным расписанием' do
          it 'возвращает индивидуальное время' do
            expect(post_with_custom_schedule.start_time_for_day('monday')).to eq('10:00')
            expect(post_with_custom_schedule.end_time_for_day('monday')).to eq('19:00')
          end
        end

        context 'без индивидуального расписания' do
          it 'возвращает время точки обслуживания' do
            expect(post_without_custom_schedule.start_time_for_day('monday')).to eq('08:00')
            expect(post_without_custom_schedule.end_time_for_day('monday')).to eq('17:00')
          end

          it 'возвращает время по умолчанию если нет данных о точке' do
            post_without_data = create(:service_post, service_point: service_point)
            expect(post_without_data.start_time_for_day('monday')).to eq('09:00')
            expect(post_without_data.end_time_for_day('monday')).to eq('18:00')
          end
        end
      end

      describe '#available_at_time?' do
        it 'возвращает false для неактивного поста' do
          post_with_custom_schedule.is_active = false
          datetime = Time.parse('2024-12-09 15:00') # понедельник
          expect(post_with_custom_schedule.available_at_time?(datetime)).to be false
        end

        context 'для активного поста с индивидуальным расписанием' do
          it 'возвращает true в рабочее время рабочего дня' do
            datetime = Time.parse('2024-12-09 15:00') # понедельник 15:00
            expect(post_with_custom_schedule.available_at_time?(datetime)).to be true
          end

          it 'возвращает false в нерабочий день' do
            datetime = Time.parse('2024-12-10 15:00') # вторник 15:00 (нерабочий)
            expect(post_with_custom_schedule.available_at_time?(datetime)).to be false
          end

          it 'возвращает false вне рабочего времени' do
            datetime = Time.parse('2024-12-09 08:00') # понедельник 08:00 (до начала работы)
            expect(post_with_custom_schedule.available_at_time?(datetime)).to be false
          end
        end
      end

      describe '#working_days_list' do
        context 'с индивидуальным расписанием' do
          it 'возвращает список рабочих дней' do
            expect(post_with_custom_schedule.working_days_list).to contain_exactly('monday', 'wednesday')
          end
        end

        context 'без индивидуального расписания' do
          it 'возвращает пустой массив' do
            expect(post_without_custom_schedule.working_days_list).to eq([])
          end
        end
      end
    end
  end
end 