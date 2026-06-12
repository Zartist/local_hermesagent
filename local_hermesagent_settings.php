<?php
require_once(__DIR__ . '/../../config.php');
require_once(__DIR__ . '/lib.php');

require_login();
require_capability('local/hermesagent:configure', context_system::instance());

$action = required_param('action', PARAM_ALPHA);
confirm_sesskey();

$bridge_port = get_config('local_hermesagent', 'bridge_port');
if (empty($bridge_port)) $bridge_port = '9118';

$hermes_home = '/var/www/moodledata/.hermes';
$bridge_script = $CFG->dirroot . '/local/hermesagent/classes/bridge/acp_bridge.py';

if ($action === 'start') {
    if (!file_exists("$hermes_home/venv/bin/hermes")) {
        throw new moodle_exception('Hermes not installed. Please bootstrap first.', '',
            new moodle_url('/admin/settings.php?section=local_hermesagent_settings'));
    }

    $cmd = sprintf(
        'HERMES_HOME=%s BRIDGE_PORT=%d MOODLE_DB_HOST=%s MOODLE_DB_NAME=%s MOODLE_DB_USER=%s MOODLE_DB_PASS=%s nohup %s/venv/bin/python %s > /var/www/moodledata/.hermes/logs/bridge.log 2>&1 & echo $!',
        escapeshellarg($hermes_home),
        $bridge_port,
        escapeshellarg($CFG->dbhost),
        escapeshellarg($CFG->dbname),
        escapeshellarg($CFG->dbuser),
        escapeshellarg($CFG->dbpass),
        $hermes_home,
        escapeshellarg($bridge_script)
    );

    $output = [];
    exec($cmd, $output, $return);
    $pid = trim(implode("
", $output));
    set_config('bridge_pid', $pid, 'local_hermesagent');
    set_config('bridge_status', 'running', 'local_hermesagent');
    sleep(1);

} elseif ($action === 'stop') {
    $pid = get_config('local_hermesagent', 'bridge_pid');
    if ($pid) {
        exec("kill $pid 2>/dev/null");
        // Fallback: kill by port
        exec("fuser -k ${bridge_port}/tcp 2>/dev/null || true");
    }
    set_config('bridge_status', 'stopped', 'local_hermesagent');
    set_config('bridge_pid', '', 'local_hermesagent');
}

redirect(new moodle_url('/admin/settings.php?section=local_hermesagent_settings'));
