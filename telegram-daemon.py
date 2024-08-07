#!/usr/bin/env python
# pylint: disable=unused-argument
# This program is dedicated to the public domain under the CC0 license.

"""
Simple Bot to reply to Telegram messages.

First, a few handler functions are defined. Then, those functions are passed to
the Application and registered at their respective places.
Then, the bot is started and runs until we press Ctrl-C on the command line.

Usage:
Basic Echobot example, repeats messages.
Press Ctrl-C on the command line or send a signal to the process to stop the
bot.
"""

import logging
import os
import sys
import atexit
import signal
import subprocess

from telegram import ForceReply, Update
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters
from telegram.error import TimedOut

# # Replace 'YOUR_BOT_TOKEN' with the token you got from the BotFather
BOT_TOKEN = 'YOUR_BOT_TOKEN'
PIDFILE = '/tmp/telegram-daemon.pid'

# Enable logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", level=logging.INFO
)
# set higher logging level for httpx to avoid all GET and POST requests being logged
logging.getLogger("httpx").setLevel(logging.WARNING)

logger = logging.getLogger(__name__)

def check_pid(pidfile):
    """Check if there is a process running with the PID in the pidfile."""
    if os.path.exists(pidfile):
        with open(pidfile, 'r') as f:
            pid = int(f.read().strip())
        if os.path.exists(f'/proc/{pid}'):
            return True
    return False

def create_pidfile(pidfile):
    """Create a PID file."""
    with open(pidfile, 'w') as f:
        f.write(str(os.getpid()))
    logger.info(f'Created PID file: {pidfile} with PID {os.getpid()}')

def remove_pidfile(pidfile):
    """Remove the PID file."""
    if os.path.exists(pidfile):
        os.remove(pidfile)
        logger.info(f'Removed PID file: {pidfile}')

def signal_handler(sig, frame):
    """Handle termination signals."""
    logger.info(f'Received signal {sig}, cleaning up...')
    print(f'Received signal {sig}, cleaning up...')
    remove_pidfile(PIDFILE)
    sys.exit(0)

def format_time(seconds):
    days = seconds // 86400
    hours = (seconds % 86400) // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    parts = []
    if days > 0:
        parts.append(f"{days} day{'s' if days > 1 else ''}")
    if hours > 0:
        parts.append(f"{hours} hour{'s' if hours > 1 else ''}")
    if minutes > 0:
        parts.append(f"{minutes} minute{'s' if minutes > 1 else ''}")
    if secs > 0 or (days == 0 and hours == 0 and minutes == 0):
        parts.append(f"{secs} second{'s' if secs > 1 else ''}")
    return ', '.join(parts)

# Define a few command handlers. These usually take the two arguments update and
# context.
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /start is issued."""
    user = update.effective_user
    await update.message.reply_html(
        rf"Hi {user.mention_html()}!",
        reply_markup=ForceReply(selective=True),
    )

async def watering_time_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle the /watering_time command."""
    try:
        # Execute the command
        result = subprocess.run(
            ["python3", "serial-ping.py", "-m", "get-watering-time"],
            capture_output=True,
            text=True,
            check=True
        )
        # Parse the output
        output = result.stdout.strip()
        logger.info(f"Command output: {output}")

        # Extract the total_watering_time value
        if "total_watering_time:" in output:
            total_watering_time_str = output.split('total_watering_time:')[1].strip()
            total_watering_time_seconds = int(total_watering_time_str)
            readable_time = format_time(total_watering_time_seconds)
            
            await update.message.reply_text(f"The total watering time needed is {readable_time}.")
        else:
            await update.message.reply_text("Could not find the watering time information.")
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {e}")
        await update.message.reply_text("Failed to execute the command.")
    except Exception as e:
        logger.error(f"Error: {e}")
        await update.message.reply_text("An error occurred while processing the command.")

async def next_alarm_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle the /next-alarm command."""
    try:
        # Execute the command
        result = subprocess.run(
            ["python3", "serial-ping.py", "-m", "next-alarm"],
            capture_output=True,
            text=True,
            check=True
        )
        # Parse the output
        output = result.stdout.strip()
        logger.info(f"Command output: {output}")
        
        # Extract the nextAlarmSecs value
        lines = output.split('\n')
        for line in lines:
            if "nextAlarmSecs:" in line:
                next_alarm_secs_str = line.split('nextAlarmSecs:')[1].split()[0]
                next_alarm_secs = int(next_alarm_secs_str)
                readable_time = format_time(next_alarm_secs)
                await update.message.reply_text(f"The next alarm is in {readable_time}.")
                return
        
        await update.message.reply_text("Could not find the next alarm information.")
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {e}")
        await update.message.reply_text("Failed to execute the command.")
    except Exception as e:
        logger.error(f"Error: {e}")
        await update.message.reply_text("An error occurred while processing the command.")

async def trigger_alarm(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Triggers an alarm in 2 minutes"""
    try:
        # Execute the command
        result = subprocess.run(
            ["python3", "serial-ping.py", "-m", "trigger-alarm"],
            capture_output=True,
            text=True,
            check=True
        )
        # Parse the output
        output = result.stdout.strip()
        logger.info(f"Command output: {output}")
        # Execute the command
        result = subprocess.run(
            ["systemctl", "restart", "monitor-watering"],
            capture_output=True,
            text=True,
            check=True
        )
        # Parse the output
        output = result.stdout.strip()
        logger.info(f"Command output: {output}")
        
        await update.message.reply_text("Watering alarm triggered.")

    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {e}")
        await update.message.reply_text("Failed to execute the command.")
    except Exception as e:
        logger.error(f"Error: {e}")
        await update.message.reply_text("An error occurred while processing the command.")
async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /help is issued."""
    await update.message.reply_text("Hello master how can I assist you?")


async def echo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Echo the user message."""
    await update.message.reply_text(update.message.text)


def main() -> None:
    """Start the bot."""
    try:
        # Create the Application and pass it your bot's token.
        application = Application.builder().token(BOT_TOKEN).read_timeout(10).connect_timeout(10).build()

        # on different commands - answer in Telegram
        application.add_handler(CommandHandler("start", start))
        application.add_handler(CommandHandler("help", help_command))
        application.add_handler(CommandHandler("next_alarm", next_alarm_command))
        application.add_handler(CommandHandler("trigger_alarm", trigger_alarm))
        application.add_handler(CommandHandler("watering_time", watering_time_command))

        # on non command i.e message - echo the message on Telegram
        application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, echo))

        # Run the bot until the user presses Ctrl-C
        application.run_polling(allowed_updates=Update.ALL_TYPES)
    except TimedOut as e:
        logger.error(f"Bot initialization timed out: {e}")
    except Exception as e:
        logger.error(f"An error occurred: {e}")

if __name__ == "__main__":
    if check_pid(PIDFILE):
        print('Another instance is already running. Exiting.')
        logger.error('Another instance is already running. Exiting.')
        sys.exit(1)

    create_pidfile(PIDFILE)

    # Register cleanup functions
    atexit.register(remove_pidfile, PIDFILE)
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Your main program logic here
    try:
        print(f'Running with PID {os.getpid()}...')
        main()
    except KeyboardInterrupt:
        pass
