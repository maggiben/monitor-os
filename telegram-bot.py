import asyncio
from telegram import Bot
import argparse

async def send_telegram_message(token, chat_id, message):
    bot = Bot(token=token)
    await bot.send_message(chat_id=chat_id, text=message)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Send a message via Telegram bot")
    parser.add_argument("message", type=str, help="The message to send")
    args = parser.parse_args()

    # Replace 'YOUR_BOT_API_TOKEN' with your actual bot token
    bot_token = "YOUR_BOT_API_TOKEN"
    
    # Replace 'YOUR_CHAT_ID' with your actual chat ID
    chat_id = "YOUR_CHAT_ID"
    
    # Run the async function
    asyncio.run(send_telegram_message(bot_token, chat_id, args.message))

