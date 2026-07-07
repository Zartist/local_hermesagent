<?php
require_once(__DIR__ . '/../../config.php');
require_once(__DIR__ . '/lib.php');

require_login();
require_capability('local/hermesagent:configure', context_system::instance());

$PAGE->set_url('/local/hermesagent/terminal.php');
$PAGE->set_context(context_system::instance());
$PAGE->set_title(get_string('terminal', 'local_hermesagent'));
$PAGE->set_heading(get_string('pluginname', 'local_hermesagent'));

$hermes_home = '/var/www/moodledata/.hermes';
$hermes_installed = file_exists("$hermes_home/venv/bin/hermes");

// Get hermes version for display
$hermes_version = '';
if ($hermes_installed) {
    $output = [];
    exec("HERMES_HOME=$hermes_home $hermes_home/venv/bin/hermes --version 2>&1", $output, $rc);
    $hermes_version = implode("\n", array_slice($output, 0, 2));
}

$css_file = __DIR__ . '/styles/terminal.css';
$js_file = __DIR__ . '/styles/terminal.js';

echo $OUTPUT->header();

if (file_exists($css_file)) {
    echo '<style>' . file_get_contents($css_file) . '</style>';
}

echo $OUTPUT->heading(get_string('terminal', 'local_hermesagent'), 2);

if (!$hermes_installed) {
    echo '<div class="alert alert-warning">';
    echo 'Hermes is not installed yet. Click "Update & Bootstrap" on the settings page first.';
    echo '</div>';
}

// Quick action buttons — common non-interactive Hermes commands
echo '<div class="hermes-quick-actions">';
echo '<span class="hermes-quick-label">Quick actions:</span>';
$quick_commands = [
    ['label' => 'hermes --version', 'cmd' => 'hermes --version'],
    ['label' => 'hermes config', 'cmd' => 'hermes config'],
    ['label' => 'hermes mcp list', 'cmd' => 'hermes mcp list'],
    ['label' => 'hermes tools list', 'cmd' => 'hermes tools list'],
    ['label' => 'hermes acp --check', 'cmd' => 'hermes acp --check'],
    ['label' => 'hermes status', 'cmd' => 'hermes status'],
];
foreach ($quick_commands as $qc) {
    echo '<button type="button" class="btn btn-sm btn-outline-secondary hermes-quick-btn" '
        . 'data-cmd="' . htmlspecialchars($qc['cmd'], ENT_QUOTES) . '">'
        . htmlspecialchars($qc['label']) . '</button> ';
}
echo '</div>';

// Terminal container
echo '<div id="hermes-terminal-container" ';
echo 'data-sesskey="' . sesskey() . '" ';
echo 'data-wwwroot="' . $CFG->wwwroot . '" ';
echo 'data-hermesinstalled="' . ($hermes_installed ? 'true' : 'false') . '">';
echo '<pre id="hermes-terminal-output" class="hermes-terminal-output"></pre>';
echo '<div class="hermes-terminal-input-row">';
echo '<span id="hermes-terminal-prompt">$ </span>';
echo '<input type="text" id="hermes-terminal-input" class="hermes-terminal-input" autocomplete="off" spellcheck="false" />';
echo '</div>';
echo '</div>';

echo '<div class="mt-2"><small class="text-muted">';
echo 'Environment: <code>HERMES_HOME=' . htmlspecialchars($hermes_home) . '</code> is set automatically. ';
echo 'The venv bin dir is in <code>PATH</code>, so just type <code>hermes</code>.';
echo '</small></div>';

echo '<div class="mt-1"><small class="text-muted">';
echo 'Note: Interactive <code>hermes chat</code> (TUI) is not supported here. ';
echo 'Use <code>hermes chat -q "your question"</code> for single queries, or use the chat page.';
echo '</small></div>';

echo '<div class="mt-3">';
echo $OUTPUT->single_button(new moodle_url('/admin/settings.php?section=local_hermesagent_settings'), get_string('backto', 'local_hermesagent'));
echo '</div>';

echo $OUTPUT->footer();

if (file_exists($js_file)) {
    echo '<script>' . file_get_contents($js_file) . '</script>';
}
