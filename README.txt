local_hermesagent — Hermes Agent integration for Moodle
=======================================================

Plugin name   : Hermes Agent
Component     : local_hermesagent
Version       : 0.3.0 (2026061304)
Moodle req.   : 5.0+ (2024100700)
License       : GNU GPL v3 or later
              : https://www.gnu.org/copyleft/gpl.html
Maturity      : Beta

What it does
------------

local_hermesagent embeds Hermes Agent (an AI assistant) inside Moodle.  It
provides a chat interface where users can ask questions, get help, and
interact with an LLM that understands their Moodle instance.  Key features:

  * Real-time streamed responses (SSE) with markdown rendering.
  * Math equation rendering via MathJax (inline and display math).
  * Persistent conversation history stored per user.
  * Tool-calling with human-in-the-loop approval (SQL queries, schema
    exploration, admin lookups, skill backup).
  * Learned skills system — persistent instructions the agent remembers
    across conversations.
  * Built-in terminal for configuring the Hermes CLI from within Moodle.
  * GDPR-compliant privacy provider (data export and deletion).

The plugin talks to a local Python HTTP service called the ACP Bridge, which
manages stateful `hermes acp` subprocesses.  This bridge is started/stopped
from Moodle admin settings and runs on a configurable local port (default 9118).

Requirements
------------

  * Moodle 5.0 or later.
  * PHP with curl extension enabled.
  * Python 3.12+ (standalone musl build provided by bootstrap script).
  * Network access to download Python build and hermes-agent package
    during bootstrap (or pre-installed manually).
  * The ACP Bridge (acp_bridge.py) — shipped with the plugin, runs as
    www-data using a portable Python venv under moodledata/.hermes/.

Installation
------------

  1. Copy this plugin directory to your Moodle installation:

       moodle/local/hermesagent/

  2. Log in as an admin and navigate to:

       Site administration > Notifications

     Moodle will detect the new plugin and offer to upgrade the database.

  3. Click "Continue" to run the database upgrade.  This creates the plugin
     tables and seeds default settings.

  4. Go to:

       Site administration > Plugins > Local plugins > Hermes Agent

     to access the settings page.

  5. Bootstrap Hermes (first-time only):

     Click "Bootstrap Hermes" in the settings page, or run from the
     terminal page.  This downloads a standalone Python 3.12 build (~50 MB),
     creates a virtual environment, and installs the hermes-agent package.

  6. Start the ACP Bridge from the admin settings page (Start button).

Configuration
-------------

All settings are managed from:

  Site administration > Plugins > Local plugins > Hermes Agent

Settings:

  Bridge port     — TCP port for the ACP Bridge HTTP service (default: 9118).
                    The bridge listens on 127.0.0.1 only.

  Model override  — Override the LLM model used by Hermes.  Leave blank to
                    use your default Hermes profile.

  Hermes home     — Custom HERMES_HOME directory path.  Leave blank to use
                    the default /var/www/moodledata/.hermes.

The settings page also shows:

  * Bridge status (Running / Stopped) with Start and Stop buttons.
  * Current Hermes CLI version.
  * Number of active ACP sessions.
  * Links to the Hermes CLI terminal and bootstrap.

Bridge management:

  The ACP Bridge is started and stopped via local_hermesagent_settings.php,
  which runs as www-data.  On start, a credential file is written with
  restricted permissions (0600) so the bridge can read Moodle DB settings.
  On stop, the credential file is securely deleted.

Capabilities
------------

  local/hermesagent:use          — Access the Hermes Agent chat interface.
  local/hermesagent:configure    — Manage bridge settings and use the CLI terminal.
  local/hermesagent:manage_skills — Manage learned skills.
  local/hermesagent:approve_tools — Approve or reject tool execution requests.

All capabilities are scoped to CONTEXT_SYSTEM and carry RISK_CONFIG.

Privacy compliance
------------------

The plugin implements Moodle's privacy provider interfaces:

  * core_privacy\local\metadata\provider
  * core_privacy\local\request\core_user_data_provider
  * core_privacy\local\request\core_userlist_provider

Personal data stored:

  * Chat conversations (user input and assistant responses) linked to
    the user who created them.
  * Conversation metadata (name, ACP session ID, timestamps).

Data is exported via:

  Site administration > Users > Privacy > Export my data

Data is deleted via:

  Site administration > Users > Privacy > Delete my data

The delete handler correctly cascades through tool_log -> messages ->
conversations to avoid foreign key constraint violations.

Database tables
---------------

  local_hermesagent_settings
      Plugin settings storage (key-value).
      Fields: id, name (unique), value, description, timemodified.

  local_hermesagent_conversations
      User chat sessions.
      Fields: id, name, usermodified (FK to user), acp_session_id,
              timemodified, timecreated.
      Index: usermodified.

  local_hermesagent_messages
      Individual chat messages (user, assistant, tool).
      Fields: id, conversationid (FK), role, content (LONGTEXT),
              tool_calls (LONGTEXT), tool_results (LONGTEXT),
              timemodified.

  local_hermesagent_skills
      Learned skills / persistent instructions.
      Fields: id, name (unique), description, content, category,
              enabled, timemodified, timecreated.

  local_hermesagent_tool_log
      Tool execution audit log.
      Fields: id, messageid (FK to messages), tool_name, input,
              output, confirmed, timemodified.

Architecture overview
---------------------

  Browser (chat.js)
    |
    |  AJAX (send_message via web service)
    |  SSE stream (api.php?action=stream)
    v
  api.php
    |
    |  cURL POST to 127.0.0.1:<port>/v1/chat/completions
    v
  acp_bridge.py (FastAPI + uvicorn)
    |
    |  stdio JSON-RPC
    v
  hermes acp subprocess
    |
    |  calls LLM provider (OpenAI, Anthropic, etc.)
    v
  LLM

Known limitations
-----------------

  * The ACP Bridge must run on the same host as the Moodle web server
    (it connects to 127.0.0.1).  It does not support remote bridges yet.
  * Each ACP session runs a dedicated `hermes acp` subprocess.  Long-lived
    conversations hold a process for their entire lifetime.
  * Math rendering requires internet access to load MathJax from CDN unless
    Moodle's MathJax filter is already configured with a local mirror.
  * The bootstrap script requires curl and tar to be available in the
    container/environment.
  * Moodle 5.x requirejs cache must be manually purged on first install
    (the upgrade script attempts this, but a full cache purge may be needed).
  * Tool execution (especially SQL) runs as www-data with Moodle DB
    credentials — use with caution on shared or production instances.
  * The terminal interface does not support interactive programs that
    require stdin (e.g., vim, python REPL).

Links
-----

  Hermes Agent documentation : https://hermes-agent.nousresearch.com/docs
  Moodle Plugin Directory    : https://moodle.org/plugins/local_hermesagent
  GitHub (if available)      : (add repository URL here)
  MathJax                    : https://www.mathjax.org/
  marked.js                  : https://github.com/markedjs/marked

Credits
-------

  * Hermes Agent by Nous Research
  * marked.js — markdown parser (MIT License)
  * MathJax — mathematical typesetting (Apache 2.0 License)
  * Moodle — learning management system (GPL v3+)
