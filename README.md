run this on my lumeo gateways to install:

============================================================================================

git clone https://github.com/wifieye-Chad/lumeo-healthcheck-to-slack.git
cd lumeo-healthcheck-to-slack
bash install.sh

============================================================================================

Lumeo Gateway Health Monitor via Slack
This system monitors GPU health on Lumeo AI inference gateways and integrates with Slack for actionable alerts and remote control.

What It Does
Monitors GPU utilization, temperature, VRAM usage, and FPS

Sends Slack alerts only when thresholds are exceeded

Alerts contain system details and a button to open the Lumeo Console

Users can reply in the Slack thread with restart or reboot

Gateway will automatically restart the Lumeo container or reboot the system

Tracks handled alerts to prevent duplicate actions

Alert Triggers
An alert is sent when any of the following conditions are met:

GPU Utilization is greater than or equal to 80%

GPU Temperature is greater than or equal to 85°C

VRAM usage is greater than or equal to 90%

FPS is less than or equal to 3 AND GPU Utilization is greater than or equal to 65%

Files in This Project
send_gpu_alert_to_slack.sh: Gathers GPU stats and sends alerts (runs every 15 minutes via cron)

test_poll_slack_responses.sh: Polls Slack every minute for user replies and triggers appropriate actions

install.sh: Copies scripts, installs cron jobs, and sets up config

.env: Contains Slack secrets (not committed to repo)

.env.template: Reference file showing expected .env format

.env Format
Do not commit the real .env file to GitHub. Use a file named .env with this format and place it in the same folder before running install.sh:

ini
Copy
Edit
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook/url
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_CHANNEL_NAME=gateway-alerts
This file will be copied to /usr/local/etc/lumeo-slack.env during installation.

How to Set Up Slack
Create a Slack channel (e.g., #gateway-alerts) and add your team.

Go to https://api.slack.com/apps and create a new app.

Enable Incoming Webhooks and generate a webhook URL for your channel.

Under "OAuth & Permissions", add the following Bot Token Scopes:

channels:read

groups:read

channels:history

users:read

chat:write

Install the app to your workspace and copy the bot token.

Invite the bot to the Slack channel with /invite @YourBotName.

Cron Jobs Installed
The install script will add these cron jobs:

swift
Copy
Edit
*/15 * * * * /usr/local/bin/send_gpu_alert_to_slack.sh
*/1 * * * * /usr/local/bin/test_poll_slack_responses.sh
@reboot /usr/bin/nvidia-smi -pm 1
Deployment on a Gateway
Ensure .env is present in the repo folder.

Run the following:

bash
Copy
Edit
git clone https://github.com/wifieye-Chad/lumeo-healthcheck-to-slack.git
cd lumeo-healthcheck-to-slack
bash install.sh
The install script will:

Copy the scripts to /usr/local/bin/

Create /usr/local/etc/lumeo-slack.env from .env

Add necessary cron jobs

Create a poller state file at /var/log/lumeo_action_state.json

Optional: Deploy to Multiple Gateways
Use any of the following to push this project to your full fleet:

pssh for parallel SSH commands

Ansible for structured automation

Bash loop to run ssh or scp across gateway IPs

Ansible is recommended for long-term management and reusability.
