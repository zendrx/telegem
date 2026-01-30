
require_relative 'spec_helper'

RSpec.describe Telegem::Core::Context do
  
  let(:mock_bot) { instance_double(Telegem::Core::Bot) }
  let(:mock_api) { instance_double(Telegem::API::Client) }
  
  before do
    allow(mock_bot).to receive(:api).and_return(mock_api)
    allow(mock_api).to receive(:call)
  end
  
  describe '#reply' do
    context 'when there is a chat' do
      let(:update_with_chat) do
        {
          'message' => {
            'chat' => { 'id' => 12345 },
            'from' => { 'id' => 67890, 'first_name' => 'Test' }
          }
        }
      end
      
      it 'sends a message with correct parameters' do
        ctx = described_class.new(update_with_chat, mock_bot)
        
        # Expect the API call with exact parameters
        expect(mock_api).to receive(:call).with(
          'sendMessage',
          { chat_id: 12345, text: 'Hello from test!' }
        )
        
        ctx.reply('Hello from test!')
      end
      
      it 'accepts additional options' do
        ctx = described_class.new(update_with_chat, mock_bot)
        
        expect(mock_api).to receive(:call).with(
          'sendMessage',
          { 
            chat_id: 12345, 
            text: 'With options',
            parse_mode: 'Markdown',
            disable_notification: true
          }
        )
        
        ctx.reply('With options', parse_mode: 'Markdown', disable_notification: true)
      end
    end
    
    context 'when there is NO chat' do
      let(:update_without_chat) do
        { 'callback_query' => { 'from' => { 'id' => 67890 } } }
      end
      
      it 'returns nil and does not call API' do
        ctx = described_class.new(update_without_chat, mock_bot)
        
        expect(mock_api).not_to receive(:call)
        expect(ctx.reply('Should not send')).to be_nil
      end
    end
  end
  
  describe '#from' do
    let(:message_update) do
      {
        'message' => {
          'from' => { 'id' => 111, 'first_name' => 'Alice' },
          'chat' => { 'id' => 999 }
        }
      }
    end
    
    let(:callback_update) do
      {
        'callback_query' => {
          'from' => { 'id' => 222, 'first_name' => 'Bob' },
          'message' => { 'chat' => { 'id' => 888 } }
        }
      }
    end
    
    it 'gets user from message' do
      ctx = described_class.new(message_update, mock_bot)
      expect(ctx.from.id).to eq(111)
      expect(ctx.from.name).to eq('Alice')
    end
    
    it 'gets user from callback query' do
      ctx = described_class.new(callback_update, mock_bot)
      expect(ctx.from.id).to eq(222)
      expect(ctx.from.name).to eq('Bob')
    end
  end
end