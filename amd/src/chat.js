/**
 * Hermes Agent chat client
 *
 * @module     local_hermesagent/chat
 * @copyright  2026
 * @license    https://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define(['jquery', 'core/ajax', 'core/str'], function($, Ajax, Str) {
    var config = {};
    var currentMessage = null;
    var isStreaming = false;

    /**
     * Initialize the chat
     */
    var init = function() {
        $(document).ready(function() {
            setupEventListeners();
            loadHistory();
        });
    };

    /**
     * Set configuration from PHP
     */
    var setConfig = function(cfg) {
        config = JSON.parse(typeof cfg === 'string' ? cfg : JSON.stringify(cfg));
    };

    /**
     * Setup event listeners
     */
    var setupEventListeners = function() {
        // Send button
        $('#hermes-send-btn').on('click', function() {
            sendMessage();
        });

        // Enter key to send (Shift+Enter for newline)
        $('#hermes-message-input').on('keydown', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });

        // Conversation list clicks
        $(document).on('click', '.hermes-conv-item', function() {
            var convId = $(this).data('conv-id');
            window.location.href = M.cfg.wwwroot + '/local/hermesagent/chat.php?conversationid=' + convId;
        });

        // New conversation link
        $('#hermes-new-conv').on('click', function(e) {
            e.preventDefault();
            window.location.href = M.cfg.wwwroot + '/local/hermesagent/chat.php?action=new';
        });

        // Tool modal actions
        $('#hermes-tool-approve').on('click', function() {
            handleToolResponse(true);
        });
        $('#hermes-tool-reject').on('click', function() {
            handleToolResponse(false);
        });
    };

    /**
     * Load conversation history
     */
    var loadHistory = function() {
        var promises = Ajax([{
            methodname: 'local_hermesagent_get_history',
            args: { conversationid: config.conversationid }
        }]);

        $.when.apply($, promises).done(function(response) {
            var messages = response[0] ? response[0].messages : [];
            renderMessages(messages);
            scrollToEnd();
        });
    };

    /**
     * Send a message
     */
    var sendMessage = function() {
        var input = $('#hermes-message-input');
        var message = input.val().trim();
        if (!message || isStreaming) return;

        input.val('');
        addUserMessage(message);

        // Start streaming response
        streamResponse(config.conversationid);
    };

    /**
     * Add user message to UI
     */
    var addUserMessage = function(content) {
        var html = '<div class="hermes-message hermes-user-message">';
        html += '<div class="hermes-avatar hermes-user-avatar">U</div>';
        html += '<div class="hermes-bubble hermes-user-bubble">';
        html += '<div class="hermes-content">' + escapeHtml(content) + '</div>';
        html += '</div></div>';

        $('#hermes-chat-area').append(html);
        scrollToEnd();
    };

    /**
     * Add assistant message to UI
     */
    var addAssistantMessage = function() {
        var html = '<div class="hermes-message hermes-assistant-message" id="hermes-assistant-msg">';
        html += '<div class="hermes-avatar hermes-assistant-avatar">H</div>';
        html += '<div class="hermes-bubble hermes-assistant-bubble">';
        html += '<div class="hermes-content hermes-streaming" id="hermes-assistant-content"></div>';
        html += '<div class="hermes-spinner" id="hermes-spinner"></div>';
        html += '</div></div>';

        $('#hermes-chat-area').append(html);
        scrollToEnd();
        return $('#hermes-assistant-content');
    };

    /**
     * Stream response from ACP bridge
     */
    var streamResponse = function(conversationid) {
        isStreaming = true;
        $('#hermes-send-btn').prop('disabled', true);

        var content = addAssistantMessage();

        // First save the user message
        var sendPromises = Ajax([{
            methodname: 'local_hermesagent_send_message',
            args: {
                conversationid: conversationid,
                message: $('#hermes-message-input').data('lastmessage') || ''
            }
        }]);

        // Then connect to SSE stream
        var eventSource = new EventSource(
            M.cfg.wwwroot + '/local/hermesagent/api.php?action=stream&conversationid=' + conversationid + '&sesskey=' + config.sesskey
        );

        eventSource.onmessage = function(e) {
            var data = JSON.parse(e.data);
            if (data.full) {
                content.html(renderMarkdown(data.full));
                scrollToEnd();
            }
        };

        eventSource.addEventListener('message', function(e) {
            var data = JSON.parse(e.data);
            if (data.full) {
                content.html(renderMarkdown(data.full));
                scrollToEnd();
            }
        });

        eventSource.addEventListener('tool_call', function(e) {
            var data = JSON.parse(e.data);
            showToolModal(data);
        });

        eventSource.addEventListener('error', function(e) {
            content.after('<div class="hermes-error">Error: ' + (e.data || 'Connection failed') + '</div>');
        });

        eventSource.addEventListener('done', function(e) {
            eventSource.close();
            isStreaming = false;
            $('#hermes-send-btn').prop('disabled', false);
            $('#hermes-spinner').remove();
            content.removeClass('hermes-streaming');
        });
    };

    /**
     * Show tool confirmation modal
     */
    var showToolModal = function(toolCall) {
        var html = '<h4>' + escapeHtml(toolCall.name) + '</h4>';
        html += '<pre>' + escapeHtml(JSON.stringify(toolCall.input, null, 2)) + '</pre>';
        html += '<p>Do you want to approve this action?</p>';

        $('#hermes-tool-modal-body').html(html);
        $('#hermes-tool-modal').show();
        currentMessage = toolCall;
    };

    /**
     * Handle tool response (approve/reject)
     */
    var handleToolResponse = function(approved) {
        if (!currentMessage) return;

        var promises = Ajax([{
            methodname: 'local_hermesagent_tool_response',
            args: {
                messageid: currentMessage.id,
                approved: approved
            }
        }]);

        $.when.apply($, promises).done(function() {
            $('#hermes-tool-modal').hide();
            currentMessage = null;
            scrollToEnd();
        });
    };

    /**
     * Render messages to UI
     */
    var renderMessages = function(messages) {
        $('#hermes-chat-area').empty();

        messages.forEach(function(msg) {
            if (msg.role === 'user') {
                var html = '<div class="hermes-message hermes-user-message">';
                html += '<div class="hermes-avatar hermes-user-avatar">U</div>';
                html += '<div class="hermes-bubble hermes-user-bubble">';
                html += '<div class="hermes-content">' + escapeHtml(msg.content) + '</div>';
                html += '</div></div>';
                $('#hermes-chat-area').append(html);
            } else if (msg.role === 'assistant') {
                var html = '<div class="hermes-message hermes-assistant-message">';
                html += '<div class="hermes-avatar hermes-assistant-avatar">H</div>';
                html += '<div class="hermes-bubble hermes-assistant-bubble">';
                html += '<div class="hermes-content">' + renderMarkdown(msg.content) + '</div>';
                html += '</div></div>';
                $('#hermes-chat-area').append(html);
            }
        });
    };

    /**
     * Simple markdown renderer
     */
    var renderMarkdown = function(text) {
        if (!text) return '';
        // Basic markdown: code blocks, bold, italic, links
        text = text.replace(/```([^`]*)```/g, '<pre><code>$1</code></pre>');
        text = text.replace(/`([^`]*)`/g, '<code>$1</code>');
        text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
        text = text.replace(/\*([^*]+)\*/g, '<em>$1</em>');
        text = text.replace(/\n/g, '<br>');
        return text;
    };

    /**
     * Escape HTML
     */
    var escapeHtml = function(text) {
        var div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    };

    /**
     * Scroll chat to bottom
     */
    var scrollToEnd = function() {
        var chatArea = document.getElementById('hermes-chat-area');
        chatArea.scrollTop = chatArea.scrollHeight;
    };

    return {
        init: init,
        setConfig: setConfig
    };
});
